#!/bin/bash
# Slack-Org-Chart 실행/종료/재시작 스크립트

APP_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="slack-org-chart"
LOG_FILE="/tmp/${APP_NAME}.log"
PIDFILE="/tmp/${APP_NAME}.pid"

# 실행 파일 또는 소스 모드 자동 감지
if [ -f "$APP_DIR/$APP_NAME" ]; then
    APP_CMD="$APP_DIR/$APP_NAME"
else
    APP_CMD="python app.py"
fi

# --auto-start 옵션 파싱
AUTO_START=""
for arg in "$@"; do
    case "$arg" in
        --auto-start=true)  AUTO_START="true" ;;
        --auto-start=false) AUTO_START="false" ;;
    esac
done

start() {
    if is_running; then
        echo "이미 실행 중입니다. (PID: $(cat "$PIDFILE"))"
        return 1
    fi

    cd "$APP_DIR" || exit 1
    if [ -f "$APP_DIR/venv/bin/activate" ]; then
        source venv/bin/activate
        PYTHONPATH="$APP_DIR"
    fi
    nohup $APP_CMD > "$LOG_FILE" 2>&1 &
    echo $! > "$PIDFILE"
    echo "시작됨 (PID: $!, 로그: $LOG_FILE)"

    sleep 5
    if is_running; then
        tail -3 "$LOG_FILE"
    else
        echo "시작 실패. 로그를 확인하세요:"
        tail -10 "$LOG_FILE"
        return 1
    fi
}

stop() {
    cleanup_zombies
    if [ -f "$PIDFILE" ]; then
        local pid
        pid=$(cat "$PIDFILE")
        kill -9 "$pid" 2>/dev/null
    fi
    rm -f "$PIDFILE"
    sleep 2
    # 혹시 남아있는 프로세스 재확인
    cleanup_zombies
    echo "종료됨."
}

restart() {
    echo "재시작 중..."
    stop
    sleep 5
    start
}

status() {
    if is_running; then
        echo "실행 중 (PID: $(cat "$PIDFILE"))"
        tail -3 "$LOG_FILE"
    else
        echo "실행 중이 아닙니다."
    fi
}

log() {
    tail -f "$LOG_FILE"
}

cleanup_zombies() {
    # 이전에 남아있는 모든 관련 프로세스를 종료한다.
    ps aux | grep "[P]ython app.py\|[p]ython app.py\|[s]lack-org-chart" | awk '{print $2}' | xargs kill -9 2>/dev/null
}

is_running() {
    [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null
}

auto_start_enable() {
    local os_type
    os_type="$(uname -s)"
    case "$os_type" in
        Linux)
            _systemd_enable
            ;;
        Darwin)
            _launchd_enable
            ;;
        *)
            echo "자동 시작: $os_type 은(는) 지원하지 않습니다."
            ;;
    esac
}

auto_start_disable() {
    local os_type
    os_type="$(uname -s)"
    case "$os_type" in
        Linux)
            _systemd_disable
            ;;
        Darwin)
            _launchd_disable
            ;;
        *)
            echo "자동 시작 해제: $os_type 은(는) 지원하지 않습니다."
            ;;
    esac
}

_systemd_enable() {
    local svc="/etc/systemd/system/${APP_NAME}.service"
    if [ -f "$svc" ]; then
        echo "자동 시작: 이미 등록되어 있습니다. ($svc)"
        return
    fi
    # 실행 명령어 결정
    local exec_start
    if [ -f "$APP_DIR/$APP_NAME" ]; then
        exec_start="$APP_DIR/$APP_NAME"
    else
        exec_start="$APP_DIR/venv/bin/python app.py"
    fi
    cat > "/tmp/${APP_NAME}.service" <<EOF
[Unit]
Description=Slack-Org-Chart
After=network.target

[Service]
Type=simple
User=$(whoami)
WorkingDirectory=$APP_DIR
ExecStart=$exec_start
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
    if sudo mv "/tmp/${APP_NAME}.service" "$svc" && \
       sudo systemctl daemon-reload && \
       sudo systemctl enable "$APP_NAME"; then
        echo "자동 시작: systemd 서비스 등록 완료."
    else
        echo "자동 시작: 등록 실패. sudo 권한을 확인하세요."
    fi
}

_systemd_disable() {
    local svc="/etc/systemd/system/${APP_NAME}.service"
    if [ ! -f "$svc" ]; then
        echo "자동 시작 해제: 등록된 서비스가 없습니다."
        return
    fi
    if sudo systemctl disable "$APP_NAME" && \
       sudo rm -f "$svc" && \
       sudo systemctl daemon-reload; then
        echo "자동 시작 해제: systemd 서비스 제거 완료."
    else
        echo "자동 시작 해제: 실패. sudo 권한을 확인하세요."
    fi
}

_launchd_enable() {
    local plist="$HOME/Library/LaunchAgents/com.${APP_NAME}.plist"
    if [ -f "$plist" ]; then
        echo "자동 시작: 이미 등록되어 있습니다. ($plist)"
        return
    fi
    # 실행 명령어 결정
    local exec_path
    if [ -f "$APP_DIR/$APP_NAME" ]; then
        exec_path="$APP_DIR/$APP_NAME"
    else
        exec_path="$APP_DIR/venv/bin/python"
    fi
    mkdir -p "$HOME/Library/LaunchAgents"
    if [ -f "$APP_DIR/$APP_NAME" ]; then
        cat > "$plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key><string>com.${APP_NAME}</string>
    <key>WorkingDirectory</key><string>${APP_DIR}</string>
    <key>ProgramArguments</key>
    <array><string>${exec_path}</string></array>
    <key>RunAtLoad</key><true/>
    <key>KeepAlive</key><true/>
    <key>StandardOutPath</key><string>${LOG_FILE}</string>
    <key>StandardErrorPath</key><string>${LOG_FILE}</string>
</dict>
</plist>
EOF
    else
        cat > "$plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key><string>com.${APP_NAME}</string>
    <key>WorkingDirectory</key><string>${APP_DIR}</string>
    <key>ProgramArguments</key>
    <array>
        <string>${exec_path}</string>
        <string>app.py</string>
    </array>
    <key>RunAtLoad</key><true/>
    <key>KeepAlive</key><true/>
    <key>StandardOutPath</key><string>${LOG_FILE}</string>
    <key>StandardErrorPath</key><string>${LOG_FILE}</string>
</dict>
</plist>
EOF
    fi
    launchctl load "$plist"
    echo "자동 시작: launchd 서비스 등록 완료."
}

_launchd_disable() {
    local plist="$HOME/Library/LaunchAgents/com.${APP_NAME}.plist"
    if [ ! -f "$plist" ]; then
        echo "자동 시작 해제: 등록된 서비스가 없습니다."
        return
    fi
    launchctl unload "$plist"
    rm -f "$plist"
    echo "자동 시작 해제: launchd 서비스 제거 완료."
}

handle_auto_start() {
    if [ "$AUTO_START" = "true" ]; then
        auto_start_enable
    elif [ "$AUTO_START" = "false" ]; then
        auto_start_disable
    fi
}

case "${1:-}" in
    setup)
        cd "$APP_DIR" || exit 1
        source venv/bin/activate
        PYTHONPATH="$APP_DIR" python app.py setup
        ;;
    start)   start; handle_auto_start ;;
    stop)    stop; handle_auto_start ;;
    restart) restart; handle_auto_start ;;
    status)  status; handle_auto_start ;;
    log)     log ;;
    *)
        echo "사용법: $0 {setup|start|stop|restart|status|log} [--auto-start={true|false}]"
        exit 1
        ;;
esac
