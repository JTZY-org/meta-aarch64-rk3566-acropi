#!/bin/sh
### BEGIN INIT INFO
# Provides:          migrate-irqs
# Required-Start:    $remote_fs $syslog
# Required-Stop:     $remote_fs $syslog
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Migrate sensor/UART IRQs away from CPU0
### END INIT INFO

# CPU3 bitmask is 8 (binary 1000)
MASK="8"

echo "Starting IRQ migration to CPU3..."

# 1. UARTs (ttyS0, ttyS1, ttyS3)
for dev in ttyS0 ttyS1 ttyS3; do
    irq=$(grep "$dev" /proc/interrupts | awk -F: '{print $1}' | tr -d ' ')
    for i in $irq; do
        echo "Moving UART $dev (IRQ $i) to CPU3"
        echo $MASK > /proc/irq/$i/smp_affinity 2>/dev/null
    done
done

# 2. I2C (specifically fe5b0000.i2c from your list)
# We move all i2c if they match the specified addresses
for dev in fe5b0000.i2c fdd40000.i2c; do
    irq=$(grep "$dev" /proc/interrupts | awk -F: '{print $1}' | tr -d ' ')
    for i in $irq; do
        echo "Moving I2C $dev (IRQ $i) to CPU3"
        echo $MASK > /proc/irq/$i/smp_affinity 2>/dev/null
    done
done

# 3. SPI (specifically fe620000.spi from your list)
for dev in fe620000.spi fe640000.spi; do
    irq=$(grep "$dev" /proc/interrupts | awk -F: '{print $1}' | tr -d ' ')
    for i in $irq; do
        echo "Moving SPI $dev (IRQ $i) to CPU3"
        echo $MASK > /proc/irq/$i/smp_affinity 2>/dev/null
    done
done

echo "IRQ migration finished."
