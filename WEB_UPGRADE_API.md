# RK3566 Web Upgrade & Control API 开发指导规范

## 1. 基础信息

* **服务端口**：`8088`（默认监听 `0.0.0.0:8088`）
* **基础 HTTP 路径**：`http://<设备IP>:8088/`
* **WebSocket 路径**：`ws://<设备IP>:8088/ws`
* **通信协议**：HTTP/1.1 + RFC 6455 WebSocket（支持文本 JSON 帧与二进制 ArrayBuffer 帧）
* **数据流控策略**：基于 **ACK 确认的分片传输（步进控制）**，防止客户端网速过快撑爆嵌入式写缓冲区。
* **落盘与防爆空间**：落盘路径为 `/overlay/upgrade_tmp/`（持久存储，有 12GB 可用空间），**不占用 RAM 内存**。

---

## 2. HTTP 接口定义

### 2.1 心跳探针 / 重连检测
用于固件升级或出厂重置后，前端定时轮询设备是否重新上线。

* **请求方式**：`GET`
* **接口路径**：`/api/ping`
* **请求参数**：无
* **响应格式**：`application/json`
* **响应示例**：
  ```json
  HTTP/1.1 200 OK
  Content-Type: application/json
  Access-Control-Allow-Origin: *

  {
    "status": "ok"
  }
  ```

---

## 3. WebSocket 核心接口规范

WebSocket 连接生命周期分为 **5 个阶段**：

### 阶段 1：声明元数据（Client -> Server）
建立 WebSocket 连接成功后，客户端第一步必须发送 **文本 JSON 帧**，告知服务端即将上传的文件信息与目标动作。

#### 请求报文格式：
```json
{
  "event": "meta",
  "name": "example-app_1.0_arm64.deb", // 文件名
  "size": 10485760,                    // 文件总字节数 (bytes)
  "action": "deb",                     // 动作类型: "deb" 或 "sysupgrade"
  "force": true,                       // 是否强制安装 (仅对 deb 生效，默认 true)
  "md5": "e10adc3949ba59abbe56e057f20f883e", // 预期的 MD5 校验码 (32位十六进制，可选)
  "sha256": ""                         // 预期的 SHA256 校验码 (64位十六进制，可选)
}
```

#### 服务端响应（Server -> Client）：
服务端完成存储路径准备与 Hash 计算器初始化后回复 `ready`：
```json
{
  "event": "ready",
  "chunk_size": 65536                  // 推荐的单片字节大小 (64 KB)
}
```

---

### 阶段 2：二进制分片传输与流控（Client <-> Server）
前端收到 `ready` 后进入分片传输循环。

1. **客户端发送**：
   * **帧类型**：**二进制帧（Binary Frame, `ArrayBuffer` 或 `Blob`）**
   * **分片大小**：推荐 `64 * 1024`（64 KB）。
2. **服务端确认（ACK）**：
   服务端接收到该分片并写入磁盘后，回传文本 JSON 帧：
   ```json
   {
     "event": "ack"
   }
   ```
3. **流控规则**：**客户端只有在收到上一片的 `ack` 后，才读取并发送下一个分片**，以实现平滑的背压控制并计算精准传输速率。

---

### 阶段 3：传输完成通知（Client -> Server）
所有分片发送完毕后，客户端发送文本帧通知服务端截断并开始校验：

#### 请求报文：
```json
{
  "event": "complete"
}
```

#### 服务端校验反馈：
* **若校验通过**：服务端推送校验日志：
  ```json
  {
    "event": "log",
    "data": "✓ 校验通过 | MD5: e10adc3949... | SHA256: 7f83b1657f..."
  }
  ```
* **若校验失败**：服务端推送错误信息并**中止流程、清理临时文件**：
  ```json
  {
    "event": "error",
    "message": "MD5 校验失败！预期值: e10adc39..., 实际计算值: a87ff679..."
  }
  ```

---

### 阶段 4：执行与日志实时推送（Server -> Client）

校验通过后，服务端根据 `action` 启动子进程，将标准输出/错误逐行通过文本帧推送给前端：

#### 实时日志格式：
```json
{
  "event": "log",
  "data": "Installing example-app (1.0) on root..."
}
```

#### 场景 A：DEB 安装结束通知 (opkg 强制安装)
* **执行命令**：`opkg install --force-depends --force-reinstall --force-overwrite --force-downgrade <file.deb>`
* **成功**：
  ```json
  {
    "event": "done",
    "message": "DEB 软件包安装成功！"
  }
  ```
* **失败**：
  ```json
  {
    "event": "error",
    "message": "安装退出，返回值: 255"
  }
  ```

#### 场景 B：固件刷入与重启通知 (`sysupgrade`)
* **执行命令**：脱离会话延迟执行 `/usr/sbin/sysupgrade <firmware>`
* **服务端回显**：
  ```json
  {
    "event": "rebooting",
    "message": "固件写入与系统重启中，请勿断电！"
  }
  ```
*收到此消息后，服务端在 1 秒内执行刷写并重启。前端应弹出遮罩锁定页面，启动 90 秒倒计时并开始轮询 `/api/ping`。*

---

### 独立接口：出厂重置 (`firstboot`)
无需上传文件，可随时通过已有 WebSocket 连接发送指令触发：

#### 请求报文：
```json
{
  "event": "firstboot"
}
```

#### 执行命令：
调用 `/usr/sbin/firstboot -y` 静默清空 Overlay 并重启。

#### 服务端响应：
```json
{
  "event": "log",
  "data": ">>> 正在执行: /usr/sbin/firstboot -y"
}
```
随后立即回复：
```json
{
  "event": "rebooting",
  "message": "系统出厂重置中，即将重启..."
}
```

---

## 4. 前端 JavaScript 集成 SDK（开箱即用）

前端工程师可直接使用以下封装好的 `DeviceUpgradeClient` 类：

```javascript
class DeviceUpgradeClient {
  constructor(options = {}) {
    this.host = options.host || location.hostname || '192.168.222.1';
    this.port = options.port || 8088;
    this.chunkSize = 64 * 1024; // 64KB
    
    // 事件回调
    this.onProgress = options.onProgress || (() => {});
    this.onLog = options.onLog || (() => {});
    this.onSuccess = options.onSuccess || (() => {});
    this.onError = options.onError || (() => {});
    this.onRebooting = options.onRebooting || (() => {});
  }

  /**
   * 上传并执行更新 (deb 或 sysupgrade)
   * @param {File} file 浏览器 File 对象
   * @param {"deb"|"sysupgrade"} action 目标动作
   * @param {Object} [opts] 配置项 { md5, sha256, force }
   */
  startUpload(file, action, opts = {}) {
    const wsUrl = `ws://${this.host}:${this.port}/ws`;
    const ws = new WebSocket(wsUrl);
    ws.binaryType = 'arraybuffer';

    let offset = 0;
    let lastTime = Date.now();
    let lastBytes = 0;

    ws.onopen = () => {
      this.onLog(`[SYS] WebSocket 已连接，正在声明文件元数据...`);
      ws.send(JSON.stringify({
        event: 'meta',
        name: file.name,
        size: file.size,
        action: action,
        force: opts.force !== undefined ? opts.force : true,
        md5: opts.md5 || '',
        sha256: opts.sha256 || ''
      }));
    };

    ws.onmessage = (e) => {
      const msg = JSON.parse(e.data);

      if (msg.event === 'ready' || msg.event === 'ack') {
        if (offset < file.size) {
          const slice = file.slice(offset, offset + this.chunkSize);
          const reader = new FileReader();
          reader.onload = (evt) => {
            ws.send(evt.target.result); // 发送二进制分片
            offset += slice.size;

            const now = Date.now();
            const percent = Math.min(100, Math.round((offset / file.size) * 100));
            const speedKB = ((offset - lastBytes) / 1024) / ((now - lastTime) / 1000);
            
            this.onProgress({
              percent,
              loaded: offset,
              total: file.size,
              speedKB: speedKB.toFixed(1)
            });

            lastBytes = offset;
            lastTime = now;
          };
          reader.readAsArrayBuffer(slice);
        } else {
          this.onLog(`[SYS] 分片传输完毕，请求服务端验证并执行...`);
          ws.send(JSON.stringify({ event: 'complete' }));
        }
      } else if (msg.event === 'log') {
        this.onLog(msg.data);
      } else if (msg.event === 'done') {
        this.onSuccess(msg.message);
        ws.close();
      } else if (msg.event === 'error') {
        this.onError(msg.message);
        ws.close();
      } else if (msg.event === 'rebooting') {
        this.onRebooting(msg.message);
      }
    };

    ws.onerror = (err) => this.onError('WebSocket 发生错误');
  }

  /**
   * 触发恢复出厂设置
   */
  triggerFirstboot() {
    const ws = new WebSocket(`ws://${this.host}:${this.port}/ws`);
    ws.onopen = () => ws.send(JSON.stringify({ event: 'firstboot' }));
    ws.onmessage = (e) => {
      const msg = JSON.parse(e.data);
      if (msg.event === 'log') this.onLog(msg.data);
      if (msg.event === 'rebooting') this.onRebooting(msg.message);
    };
    ws.onerror = () => this.onError('出厂重置连接失败');
  }

  /**
   * 设备重启后轮询检测心跳重连
   * @param {Function} onOnline 上线回调
   * @param {number} intervalMs 轮询间隔 (毫秒)
   */
  pollUntilOnline(onOnline, intervalMs = 2000) {
    const timer = setInterval(() => {
      fetch(`http://${this.host}:${this.port}/api/ping`, { cache: 'no-store' })
        .then((res) => {
          if (res.ok) {
            clearInterval(timer);
            onOnline();
          }
        })
        .catch(() => {});
    }, intervalMs);
  }
}
```

### 4.1 调用示例（Vue / React / 原生 JS 通用）
```javascript
const client = new DeviceUpgradeClient({
  host: '192.168.222.1',
  port: 8088,
  onProgress: (p) => {
    console.log(`上传进度: ${p.percent}% (${p.speedKB} KB/s)`);
  },
  onLog: (line) => {
    terminal.append(line); // 追加到前端黑底绿字控制台
  },
  onSuccess: (msg) => {
    alert('安装成功: ' + msg);
  },
  onError: (errMsg) => {
    alert('操作失败: ' + errMsg);
  },
  onRebooting: (msg) => {
    showModal('设备正在刷机重启，请勿断电...');
    // 开始心跳探测
    client.pollUntilOnline(() => {
      alert('设备已重新上线！');
      location.reload();
    });
  }
});

// 示例 1: 安装 deb
const debFile = document.getElementById('debFile').files[0];
client.startUpload(debFile, 'deb', { force: true, md5: 'e10adc...' });

// 示例 2: 刷写固件
const fwFile = document.getElementById('fwFile').files[0];
client.startUpload(fwFile, 'sysupgrade', { sha256: '7f83b1...' });

// 示例 3: 恢复出厂设置
// client.triggerFirstboot();
```

---

## 5. 异常处理与排查指南

| 异常现象 / 错误信息 | 原因分析 | 前端与后端应对措施 |
| :--- | :--- | :--- |
| `MD5/SHA256 校验失败` | 浏览器端文件损坏或网络误码 | 服务端已自动删除暂存包，前端应提醒用户重新选择文件并检查输入的校验码 |
| `opkg install 返回值 255` | 安装包格式非法（非 deb/ipk）或文件不完整 | 检查日志中 `opkg` 具体输出报错，确认架构（arm64）是否匹配 |
| `WebSocket 握手失败` | 目标端口 `8088` 未启动或防火墙阻拦 | 检查目标板 `/etc/init.d/web-upgrade status` 是否处于运行状态 |
| 重启后无法 ping 通 | 固件写入错误或网络 IP 变化 | 检查串口控制台输出，确认 `sysupgrade` 是否成功执行 |
