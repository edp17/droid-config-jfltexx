#!/bin/sh

# Galaxy S4 (jfltexx)
# Wait for the external Qualcomm modem and a stable Android RIL process
# before allowing oFono to start.  This service runs independently of ofono.

GPIO=/sys/kernel/debug/gpio
GETPROP=/system/bin/getprop
MARKER=/run/jfltexx-modem-ready
TIMEOUT=90
STABLE_REQUIRED=10

elapsed=0
stable=0
last_pid=""

# Never trust a readiness marker left from an earlier monitor invocation.
rm -f "$MARKER"
echo "jfltexx-modem: waiting for external modem and Android RIL"

while [ "$elapsed" -lt "$TIMEOUT" ]; do
    gpio_ready=no
    if grep -Eq \
        'MDM2AP_STATUS[[:space:]]*\)[[:space:]]+in[[:space:]]+hi' \
        "$GPIO" 2>/dev/null; then
        gpio_ready=yes
    fi

    qmux_state=$("$GETPROP" init.svc.qmuxd 2>/dev/null)
    ril_state=$("$GETPROP" init.svc.ril-daemon 2>/dev/null)
    ril_pid=$(pgrep -f '/vendor/bin/hw/rild' 2>/dev/null | head -n 1)

    if [ "$gpio_ready" = yes ] &&
       [ "$qmux_state" = running ] &&
       [ "$ril_state" = running ] &&
       [ -n "$ril_pid" ]; then

        if [ "$ril_pid" = "$last_pid" ]; then
            stable=$((stable + 1))
        else
            stable=1
        fi
        last_pid="$ril_pid"

        if [ "$stable" -ge "$STABLE_REQUIRED" ]; then
            echo "jfltexx-modem: ready after ${elapsed}s, rild PID ${ril_pid}"
            touch "$MARKER" || exit 1
            echo "jfltexx-modem: starting oFono"
            systemctl start ofono.service
            exit $?
        fi
    else
        stable=0
        last_pid=""
    fi

    if [ $((elapsed % 10)) -eq 0 ]; then
        echo "jfltexx-modem: ${elapsed}s gpio=${gpio_ready} qmux=${qmux_state} ril=${ril_state} pid=${ril_pid:-none} stable=${stable}"
    fi

    sleep 1
    elapsed=$((elapsed + 1))
done

echo "jfltexx-modem: ERROR - readiness timeout after ${TIMEOUT}s"
exit 1
