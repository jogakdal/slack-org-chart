#!/bin/bash
# Slack-Org-Chart run/stop/restart script

APP_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="slack-org-chart"
LOG_FILE="/tmp/${APP_NAME}.log"
PIDFILE="/tmp/${APP_NAME}.pid"

# Auto-detect binary or source mode
if [ -f "$APP_DIR/$APP_NAME" ]; then
    APP_CMD="$APP_DIR/$APP_NAME"
else
    APP_CMD="python app.py"
fi

# Parse --auto-start option
AUTO_START=""
for arg in "$@"; do
    case "$arg" in
        --auto-start=true)  AUTO_START="true" ;;
        --auto-start=false) AUTO_START="false" ;;
    esac
done

start() {
    if is_running; then
        echo "Already running. (PID: $(cat "$PIDFILE"))"
        return 1
    fi

    cd "$APP_DIR" || exit 1
    export APP_DIR
    unset SSL_CERT_FILE
    if [ -f "$APP_DIR/venv/bin/activate" ]; then
        source venv/bin/activate
        PYTHONPATH="$APP_DIR"
    fi
    nohup $APP_CMD > "$LOG_FILE" 2>&1 &
    echo $! > "$PIDFILE"
    echo "Started (PID: $!, log: $LOG_FILE)"

    sleep 5
    if is_running; then
        tail -3 "$LOG_FILE"
    else
        echo "Start failed. Check logs:"
        tail -10 "$LOG_FILE"
        return 1
    fi
}


stop() {
    if [ -f "$PIDFILE" ]; then
        local pid
        pid=$(cat "$PIDFILE")
        if kill -0 "$pid" 2>/dev/null; then
            kill -TERM "$pid" 2>/dev/null
            for i in 1 2 3 4 5; do
                kill -0 "$pid" 2>/dev/null || break
                sleep 1
            done
            kill -9 "$pid" 2>/dev/null
        fi
    fi
    rm -f "$PIDFILE"
    sleep 1
    cleanup_zombies
    echo "Stopped."
}

restart() {
    echo "Restarting..."
    touch "$APP_DIR/.restart_user"
    stop
    sleep 5
    start
}

status() {
    if is_running; then
        echo "Running (PID: $(cat "$PIDFILE"))"
        tail -3 "$LOG_FILE"
    else
        echo "Not running."
    fi
}

log() {
    tail -f "$LOG_FILE"
}

cleanup_zombies() {
    local my_pid=$$
    ps aux | grep "[P]ython app.py\|[p]ython app.py\|[s]lack-org-chart" \
        | grep -v "run\.sh" \
        | awk '{print $2}' \
        | grep -v "^${my_pid}$" \
        | xargs kill -9 2>/dev/null
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
            echo "Auto-start: $os_type is not supported."
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
            echo "Auto-start disable: $os_type is not supported."
            ;;
    esac
}

_systemd_enable() {
    local svc="/etc/systemd/system/${APP_NAME}.service"
    if [ -f "$svc" ]; then
        echo "Auto-start: Already registered. ($svc)"
        return
    fi
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
        echo "Auto-start: systemd service registered."
    else
        echo "Auto-start: Failed. Check sudo permissions."
    fi
}

_systemd_disable() {
    local svc="/etc/systemd/system/${APP_NAME}.service"
    if [ ! -f "$svc" ]; then
        echo "Auto-start disable: No registered service."
        return
    fi
    if sudo systemctl disable "$APP_NAME" && \
       sudo rm -f "$svc" && \
       sudo systemctl daemon-reload; then
        echo "Auto-start disable: systemd service removed."
    else
        echo "Auto-start disable: Failed. Check sudo permissions."
    fi
}

_launchd_enable() {
    local plist="$HOME/Library/LaunchAgents/com.${APP_NAME}.plist"
    if [ -f "$plist" ]; then
        echo "Auto-start: Already registered. ($plist)"
        return
    fi
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
    echo "Auto-start: launchd service registered."
}

_launchd_disable() {
    local plist="$HOME/Library/LaunchAgents/com.${APP_NAME}.plist"
    if [ ! -f "$plist" ]; then
        echo "Auto-start disable: No registered service."
        return
    fi
    launchctl unload "$plist"
    rm -f "$plist"
    echo "Auto-start disable: launchd service removed."
}

handle_auto_start() {
    if [ "$AUTO_START" = "true" ]; then
        auto_start_enable
    elif [ "$AUTO_START" = "false" ]; then
        auto_start_disable
    fi
}

_read_env_value() {
    # Read a value from existing .env file
    local key="$1"
    local env_file="$APP_DIR/.env"
    if [ -f "$env_file" ]; then
        grep "^${key}=" "$env_file" 2>/dev/null | head -1 | cut -d'=' -f2-
    fi
}

_mask_value() {
    local val="$1"
    local len=${#val}
    if [ "$len" -le 10 ]; then
        printf "%s...%s" "${val:0:2}" "${val: -2}"
    else
        printf "%s...%s" "${val:0:4}" "${val: -4}"
    fi
}

_prompt_value() {
    # $1: env key, $2: "silent" for masked input, $3: prompt label
    local key="$1"
    local silent="$2"
    local label="$3"
    local current
    current=$(_read_env_value "$key")
    if [ -n "$current" ]; then
        local display
        display=$(_mask_value "$current")
        echo "  Current: $display" >&2
        echo "  Press Enter to keep, or paste a new value to change." >&2
        if [ "$silent" = "silent" ]; then
            printf "  %s: " "$label" >&2
            read -rs input
            echo "" >&2
        else
            printf "  %s: " "$label" >&2
            read -r input
        fi
        if [ -z "$input" ]; then
            __PROMPT_RESULT="$current"
            echo "  (kept)" >&2
        else
            __PROMPT_RESULT="$input"
            echo "  (updated)" >&2
        fi
    else
        echo "  No value set. This field is required." >&2
        while true; do
            if [ "$silent" = "silent" ]; then
                printf "  %s: " "$label" >&2
                read -rs input
                echo "" >&2
            else
                printf "  %s: " "$label" >&2
                read -r input
            fi
            if [ -n "$input" ]; then
                break
            fi
            echo "  Value cannot be empty. Please try again." >&2
        done
        __PROMPT_RESULT="$input"
    fi
}

show_banner() {
    local ver=""
    if [ -f "$APP_DIR/VERSION" ]; then
        ver=$(cut -d'"' -f2 < "$APP_DIR/VERSION")
    elif [ -f "$APP_DIR/src/version.py" ]; then
        ver=$(grep 'VERSION' "$APP_DIR/src/version.py" | head -1 | cut -d'"' -f2)
    fi
    cat <<'BANNER'

  ____  _            _         ___              ____ _                _
 / ___|| | __ _  ___| | __    / _ \ _ __ __ _  / ___| |__   __ _ _ __| |_
 \___ \| |/ _` |/ __| |/ /___| | | | '__/ _` || |   | '_ \ / _` | '__| __|
  ___) | | (_| | (__|   <____| |_| | | | (_| || |___| | | | (_| | |  | |_
 |____/|_|\__,_|\___|_|\_\    \___/|_|  \__, | \____|_| |_|\__,_|_|   \__|
                                         |___/
BANNER
    if [ -n "$ver" ]; then
        printf "  v%s\n\n" "$ver"
    else
        echo ""
    fi
}

install() {
    echo "=== Setup ==="
    echo ""
    echo "Get the values below from https://api.slack.com/apps (select your app)."
    echo ""

    echo "[1/4] Bot User OAuth Token (xoxb-...)"
    echo "  Find at: api.slack.com > OAuth & Permissions > Bot User OAuth Token"
    _prompt_value "SLACK_BOT_TOKEN" silent "Bot User OAuth Token"; bot_token="$__PROMPT_RESULT"
    echo ""

    echo "[2/4] Signing Secret"
    echo "  Find at: api.slack.com > Basic Information > App Credentials > Signing Secret"
    _prompt_value "SLACK_SIGNING_SECRET" silent "Signing Secret"; signing_secret="$__PROMPT_RESULT"
    echo ""

    echo "[3/4] App-Level Token (xapp-...)"
    echo "  Find at: api.slack.com > Basic Information > App-Level Tokens"
    echo "  If none exists, click 'Generate Token and Scopes' to create one."
    _prompt_value "SLACK_APP_TOKEN" silent "App-Level Token"; app_token="$__PROMPT_RESULT"
    echo ""

    echo "[4/4] Initial Admin Email"
    echo "  The Slack account that will manage all settings via App Home."
    # Admin email - no masking, show full value
    local current_admin
    current_admin=$(_read_env_value "ADMIN_EMAIL")
    if [ -n "$current_admin" ]; then
        echo "  Current: $current_admin" >&2
        echo "  Press Enter to keep, or type a new email to change." >&2
        printf "  Admin Email: " >&2
        read -r input
        if [ -z "$input" ]; then
            admin_email="$current_admin"
            echo "  (kept)" >&2
        else
            admin_email="$input"
            echo "  (updated)" >&2
        fi
    else
        echo "  No value set. This field is required." >&2
        while true; do
            printf "  Admin Email: " >&2
            read -r input
            if [ -n "$input" ]; then break; fi
            echo "  Value cannot be empty. Please try again." >&2
        done
        admin_email="$input"
    fi
    echo ""

    # Validate all fields
    local missing=""
    [ -z "$bot_token" ] && missing="$missing Bot_Token"
    [ -z "$signing_secret" ] && missing="$missing Signing_Secret"
    [ -z "$app_token" ] && missing="$missing App_Token"
    [ -z "$admin_email" ] && missing="$missing Admin_Email"
    if [ -n "$missing" ]; then
        echo "The following required fields are empty:$missing"
        echo "Please run ./run.sh install again."
        exit 1
    fi

    # Generate .env
    cat > "$APP_DIR/.env" <<EOF
# Slack
SLACK_BOT_TOKEN=$bot_token
SLACK_SIGNING_SECRET=$signing_secret
SLACK_APP_TOKEN=$app_token

# Initial Admin
ADMIN_EMAIL=$admin_email
EOF

    # Copy config.yaml if not exists
    if [ ! -f "$APP_DIR/config.yaml" ]; then
        cp "$APP_DIR/config.example.yaml" "$APP_DIR/config.yaml"
    fi

    echo "Setup complete!"
    echo ""
    echo "  .env file has been created."
    echo "  LDAP and other settings can be configured from App Home after starting."
    echo ""
    if is_running; then
        printf "App is currently running. Restart now? [Y/n]: "
        read -r yn
        case "$yn" in
            [Nn]*) echo "You can restart later with: ./run.sh restart" ;;
            *)     restart ;;
        esac
    else
        printf "Start the app now? [Y/n]: "
        read -r yn
        case "$yn" in
            [Nn]*) echo "You can start later with: ./run.sh start" ;;
            *)     start ;;
        esac
    fi
}

show_banner

case "${1:-}" in
    install) install ;;
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
        echo "Usage: $0 {install|start|stop|restart|status|log} [--auto-start={true|false}]"
        exit 1
        ;;
esac
