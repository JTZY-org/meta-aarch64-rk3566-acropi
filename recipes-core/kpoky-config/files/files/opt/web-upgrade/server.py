#!/usr/bin/env python3
"""
WebSocket Upgrade Daemon for RK3566 Embedded Linux.
Handles binary firmware/package streaming on port 8088, checksum verification,
opkg force installation, sysupgrade, and firstboot.
Zero external dependencies (Python 3.8+ standard library: asyncio, RFC 6455).
"""
import asyncio
import base64
import hashlib
import json
import os
import struct
import subprocess
import sys

PORT = 8088
UPLOAD_DIR = "/overlay/upgrade_tmp"
WS_GUID = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"

os.makedirs(UPLOAD_DIR, exist_ok=True)


def make_ws_frame(payload: bytes, opcode: int = 0x1) -> bytes:
    """Encode payload into an unmasked RFC 6455 WebSocket frame (server -> client)."""
    length = len(payload)
    header = bytearray([0x80 | opcode])
    if length <= 125:
        header.append(length)
    elif length <= 65535:
        header.append(126)
        header.extend(struct.pack(">H", length))
    else:
        header.append(127)
        header.extend(struct.pack(">Q", length))
    return bytes(header) + payload


def unmask_data(data: bytearray, mask: bytes):
    """In-place XOR unmasking of client data."""
    for i in range(len(data)):
        data[i] ^= mask[i & 3]
    return data


async def run_cmd_stream(cmd_str: str, writer):
    """Execute shell command asynchronously and stream stdout/stderr line-by-line."""
    proc = await asyncio.create_subprocess_shell(
        cmd_str,
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.STDOUT
    )
    while True:
        line = await proc.stdout.readline()
        if not line:
            break
        text = line.decode("utf-8", errors="replace").rstrip("\r\n")
        msg = json.dumps({"event": "log", "data": text})
        writer.write(make_ws_frame(msg.encode("utf-8"), 0x1))
        await writer.drain()

    await proc.wait()
    return proc.returncode


async def handle_ws_session(reader, writer):
    """Process WebSocket connection, handling binary chunks, checksums, and execution."""
    meta = {}
    target_path = None
    target_fp = None
    md5_hasher = None
    sha256_hasher = None

    try:
        while True:
            hdr = await reader.readexactly(2)
            fin = bool(hdr[0] & 0x80)
            opcode = hdr[0] & 0x0F
            masked = bool(hdr[1] & 0x80)
            payload_len = hdr[1] & 0x7F

            if payload_len == 126:
                ext_len = await reader.readexactly(2)
                payload_len = struct.unpack(">H", ext_len)[0]
            elif payload_len == 127:
                ext_len = await reader.readexactly(8)
                payload_len = struct.unpack(">Q", ext_len)[0]

            mask_key = b""
            if masked:
                mask_key = await reader.readexactly(4)

            payload = bytearray()
            if payload_len > 0:
                payload = bytearray(await reader.readexactly(payload_len))
                if masked:
                    unmask_data(payload, mask_key)

            # Opcode handling
            if opcode == 0x8:  # Close frame
                writer.write(make_ws_frame(b"", 0x8))
                await writer.drain()
                break
            elif opcode == 0x9:  # Ping
                writer.write(make_ws_frame(payload, 0xA))  # Reply Pong
                await writer.drain()
                continue
            elif opcode == 0xA:  # Pong
                continue
            elif opcode == 0x1:  # Text message (JSON control frame)
                text_msg = payload.decode("utf-8", errors="replace")
                data = json.loads(text_msg)
                event = data.get("event")

                # 1. Metadata declaration
                if event == "meta":
                    meta = data
                    filename = os.path.basename(data.get("name", "upload.bin"))
                    target_path = os.path.join(UPLOAD_DIR, filename)
                    target_fp = open(target_path, "wb")
                    md5_hasher = hashlib.md5()
                    sha256_hasher = hashlib.sha256()

                    resp = json.dumps({"event": "ready", "chunk_size": 65536})
                    writer.write(make_ws_frame(resp.encode("utf-8"), 0x1))
                    await writer.drain()

                # 2. Transfer complete -> trigger checksum verification and action
                elif event == "complete":
                    if target_fp:
                        target_fp.close()
                        target_fp = None

                    calc_md5 = md5_hasher.hexdigest()
                    calc_sha256 = sha256_hasher.hexdigest()

                    # Verify MD5
                    exp_md5 = meta.get("md5", "").strip().lower()
                    if exp_md5 and exp_md5 != calc_md5.lower():
                        err = f"MD5 checksum mismatch! Expected: {exp_md5}, Actual: {calc_md5}"
                        if os.path.exists(target_path): os.remove(target_path)
                        writer.write(make_ws_frame(json.dumps({"event": "error", "message": err}).encode("utf-8"), 0x1))
                        await writer.drain()
                        continue

                    # Verify SHA256
                    exp_sha256 = meta.get("sha256", "").strip().lower()
                    if exp_sha256 and exp_sha256 != calc_sha256.lower():
                        err = f"SHA256 checksum mismatch! Expected: {exp_sha256}, Actual: {calc_sha256}"
                        if os.path.exists(target_path): os.remove(target_path)
                        writer.write(make_ws_frame(json.dumps({"event": "error", "message": err}).encode("utf-8"), 0x1))
                        await writer.drain()
                        continue

                    writer.write(make_ws_frame(json.dumps({
                        "event": "log",
                        "data": f"✓ Checksum verified | MD5: {calc_md5} | SHA256: {calc_sha256[:16]}..."
                    }).encode("utf-8"), 0x1))
                    await writer.drain()

                    action = meta.get("action", "deb")

                    # Execute package installation via opkg (force install by default)
                    if action == "deb":
                        force = meta.get("force", True)
                        if force:
                            cmd = f"opkg install --force-depends --force-reinstall --force-overwrite --force-downgrade '{target_path}'"
                        else:
                            cmd = f"opkg install '{target_path}'"

                        writer.write(make_ws_frame(json.dumps({"event": "log", "data": f">>> Executing: {cmd}"}).encode("utf-8"), 0x1))
                        await writer.drain()

                        ret = await run_cmd_stream(cmd, writer)
                        if ret == 0:
                            done_msg = json.dumps({"event": "done", "message": "Package installed successfully."})
                        else:
                            done_msg = json.dumps({"event": "error", "message": f"Installation failed with exit code: {ret}"})

                        writer.write(make_ws_frame(done_msg.encode("utf-8"), 0x1))
                        await writer.drain()
                        if os.path.exists(target_path): os.remove(target_path)

                    # Execute full system upgrade via sysupgrade
                    elif action == "sysupgrade":
                        writer.write(make_ws_frame(json.dumps({
                            "event": "log",
                            "data": f">>> Triggering system upgrade: /usr/sbin/sysupgrade '{target_path}'"
                        }).encode("utf-8"), 0x1))
                        writer.write(make_ws_frame(json.dumps({
                            "event": "rebooting",
                            "message": "Firmware flashing in progress, rebooting soon. Do not power off!"
                        }).encode("utf-8"), 0x1))
                        await writer.drain()

                        # Detach completely from current session and trigger sysupgrade in background
                        subprocess.Popen(
                            f"sleep 1 && /usr/sbin/sysupgrade '{target_path}'",
                            shell=True,
                            close_fds=True,
                            start_new_session=True
                        )
                        break

                # 3. Execute factory reset via firstboot -y
                elif event == "firstboot":
                    writer.write(make_ws_frame(json.dumps({
                        "event": "log",
                        "data": ">>> Executing factory reset: /usr/sbin/firstboot -y"
                    }).encode("utf-8"), 0x1))
                    writer.write(make_ws_frame(json.dumps({
                        "event": "rebooting",
                        "message": "System is resetting to factory defaults and rebooting..."
                    }).encode("utf-8"), 0x1))
                    await writer.drain()

                    subprocess.Popen(
                        "sleep 1 && /usr/sbin/firstboot -y",
                        shell=True,
                        close_fds=True,
                        start_new_session=True
                    )
                    break

            # 4. Binary chunk frame (append to disk and update hashers)
            elif opcode == 0x2:
                if target_fp:
                    target_fp.write(payload)
                    if md5_hasher: md5_hasher.update(payload)
                    if sha256_hasher: sha256_hasher.update(payload)

                    ack_msg = json.dumps({"event": "ack"})
                    writer.write(make_ws_frame(ack_msg.encode("utf-8"), 0x1))
                    await writer.drain()

    except (asyncio.IncompleteReadError, ConnectionResetError, BrokenPipeError):
        pass
    finally:
        if target_fp and not target_fp.closed:
            target_fp.close()


async def handle_client(reader, writer):
    """Dispatcher for WebSocket handshake and HTTP heartbeat check."""
    try:
        req_line = await reader.readline()
        if not req_line:
            writer.close()
            return

        words = req_line.decode("utf-8", errors="replace").split()
        if len(words) < 2:
            writer.close()
            return

        method, path = words[0], words[1]
        headers = {}
        while True:
            line = await reader.readline()
            if not line or not line.strip():
                break
            parts = line.decode("utf-8", errors="replace").split(":", 1)
            if len(parts) == 2:
                headers[parts[0].strip().lower()] = parts[1].strip()

        # Handle WebSocket Upgrade handshake
        if headers.get("upgrade", "").lower() == "websocket":
            ws_key = headers.get("sec-websocket-key")
            if not ws_key:
                writer.close()
                await writer.wait_closed()
                return

            accept_val = base64.b64encode(
                hashlib.sha1((ws_key + WS_GUID).encode("utf-8")).digest()
            ).decode("utf-8")

            handshake = (
                "HTTP/1.1 101 Switching Protocols\r\n"
                "Upgrade: websocket\r\n"
                "Connection: Upgrade\r\n"
                f"Sec-WebSocket-Accept: {accept_val}\r\n\r\n"
            ).encode("utf-8")
            writer.write(handshake)
            await writer.drain()

            await handle_ws_session(reader, writer)
            try:
                writer.close()
                await writer.wait_closed()
            except Exception:
                pass
            return

        # Simple HTTP ping probe for heartbeat testing
        if path == "/api/ping":
            body = b'{"status":"ok"}'
            resp = (
                b"HTTP/1.1 200 OK\r\n"
                b"Content-Type: application/json\r\n"
                b"Access-Control-Allow-Origin: *\r\n"
                b"Content-Length: " + str(len(body)).encode("ascii") + b"\r\n"
                b"Connection: close\r\n\r\n" + body
            )
            writer.write(resp)
            await writer.drain()

        writer.close()
        await writer.wait_closed()

    except Exception:
        pass
    finally:
        try:
            writer.close()
            await writer.wait_closed()
        except Exception:
            pass


async def main():
    server = await asyncio.start_server(handle_client, "0.0.0.0", PORT)
    async with server:
        await server.serve_forever()


if __name__ == "__main__":
    asyncio.run(main())
