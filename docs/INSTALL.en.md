# Slack-Org-Chart Installation Guide

> 🌐 [한국어](INSTALL.ko.md) | **English** | [日本語](INSTALL.ja.md) | [中文](INSTALL.zh.md)

This guide walks you through setting up the Org Chart Slack App for your organization.

## Prerequisites

- **LDAP/AD server** with a read-only service account
- **Slack workspace** with admin access to install apps
- Network access from the app to both the LDAP server and the internet (Slack API)

## Step 1. Install App Server

Choose one of the following methods.

### Method A: Binary Install (Recommended)

Download the package for your OS from [Releases](https://github.com/jogakdal/slack-org-chart/releases). No Python installation required.

```bash
tar xzf slack-org-chart-linux.tar.gz   # Linux
tar xzf slack-org-chart-macos.tar.gz   # macOS
# Windows: extract the zip file
cd slack-org-chart/
```

### Method B: Docker Install

Only Docker is required. No additional dependencies needed.

```bash
mkdir slack-org-chart && cd slack-org-chart
docker pull ghcr.io/jogakdal/slack-org-chart:latest
# Configure config.yaml and .env in Step 3 before running.
```

## Step 2. Create a Slack App

1. Go to https://api.slack.com/apps
2. Click **"Create New App"** → **"From scratch"**
3. Enter an App Name and select your workspace
   - Recommended name: `Org Chart` or your organization name + `Org Chart`
4. Click **"Create App"**
5. (Optional) Go to **"Basic Information"** → **"Display Information"** to upload an app icon.
   - Recommended: 512x512px or larger, PNG/JPG

### 2-1. Bot User

1. Go to **"App Home"** in the left menu
2. Click **"Edit"** under **"App Display Name"**
3. Set the Display Name and Default Username
   - This name will appear as the bot's name in Slack messages
   - Examples: `Org Chart`, `조직도`, `組織図`
4. Click **"Save"**

### 2-2. Socket Mode

1. Go to **"Socket Mode"** in the left menu
2. Enable Socket Mode
3. Enter a Token Name (e.g., `orgchart-socket`) and click **"Generate"**
4. Copy the **App-Level Token** (`xapp-...`) — you'll need this later

### 2-3. Slash Commands

Go to **"Slash Commands"** and create two commands:

| Field | Command 1 | Command 2 |
|-------|-----------|-----------|
| Command | `/orgchart` | `/whois` |
| Short Description | `Org Chart / Search` | `Org Chart / Search` |
| Usage Hint | `[name/nickname/dept/title/phone] (? help)` | `[name/nickname/dept/title/phone] (? help)` |

> **Note:** Both commands work identically. Run without text for org chart, with text for unified search.
> Command names can be changed in `config.yaml` under the `commands` section. Must match your Slack app settings.
> If your workspace primarily uses a non-English language, you can set the Short Description and Usage Hint in that language instead.

### 2-4. Interactivity

1. Go to **"Interactivity & Shortcuts"**
2. Make sure **Interactivity** is turned on (it may be enabled automatically with Socket Mode)

### 2-5. Event Subscriptions

1. Go to **"Event Subscriptions"** in the left menu
2. Enable Events (may be auto-enabled with Socket Mode)
3. Under **"Subscribe to bot events"**, click **"Add Bot User Event"** and add:
   - `app_home_opened`
4. Click **"Save Changes"**

### 2-6. App Home Tab

1. Go to **"App Home"** in the left menu
2. Under **"Show Tabs"**, enable **"Home Tab"**

### 2-7. Bot Token Scopes

1. Go to **"OAuth & Permissions"**
2. Under **"Bot Token Scopes"**, add:

| Scope | Purpose |
|-------|---------|
| `commands` | Register slash commands |
| `chat:write` | Send messages |
| `users:read` | Read user info |
| `users:read.email` | Map Slack users to LDAP by email |
| `channels:manage` | Create alert channel |
| `channels:read` | List channels |
| `groups:write` | Create private channels and manage members |
| `groups:read` | List private channels |

### 2-8. Install to Workspace

1. Go to **"Install App"**
2. Click **"Install to Workspace"** (or **"Request to Install"** if admin approval is required)
3. After installation, copy the **Bot User OAuth Token** (`xoxb-...`)

### 2-9. Signing Secret

1. Go to **"Basic Information"**
2. Under **"App Credentials"**, copy the **Signing Secret**

## Step 3. Configure

```bash
cp config.example.yaml config.yaml
cp .env.example .env
```

Edit `config.yaml` and `.env`. Enter the Slack tokens and LDAP connection details from Step 2 into `.env`.

```env
# Slack
SLACK_BOT_TOKEN=xoxb-...
SLACK_SIGNING_SECRET=...
SLACK_APP_TOKEN=xapp-...

# LDAP
LDAP_HOST=ldap.company.com
LDAP_PORT=389
LDAP_BIND_DN=cn=readonly,dc=company,dc=com
LDAP_BIND_PASSWORD=your-password
LDAP_BASE_DN=DC=company,DC=com
LDAP_USER_BASE_DN=OU=Users,DC=company,DC=com
```

## Step 4. LDAP Schema Check

The default AD attribute mapping works for most AD environments. If your AD uses different attribute names, update `attr_map` in `config.yaml`.

## Step 5. Run

### Binary

```bash
./run.sh start                        # Start
./run.sh start --auto-start=true      # Start + auto-start on server reboot
./run.sh status                       # Check status
./run.sh log                          # View logs
./run.sh restart                      # Restart
./run.sh stop                         # Stop
```

### Docker

```bash
docker run -d --name slack-org-chart \
  --restart always \
  --env-file .env \
  -v $(pwd)/config.yaml:/app/config.yaml \
  -v $(pwd)/concurrent.json:/app/concurrent.json \
  ghcr.io/jogakdal/slack-org-chart:latest
```

`--restart always` ensures the container auto-starts on server reboot.

```bash
docker logs -f slack-org-chart        # View logs
docker restart slack-org-chart        # Restart
docker stop slack-org-chart           # Stop
```

On first start, the app loads all data from LDAP (~5-10 seconds), then you can use `/orgchart` or `/whois` in Slack.

## Step 6. Test

In Slack, try:
- `/orgchart` — View the organization chart
- `/whois John` — Search for an employee
- `/whois name:John` — Filtered search (name field only)
- `/whois "John"` — Exact match
- `/orgchart help` — View help

Available filters: `name:` `nick:` `email:` `dept:` `phone:` `attr:`

## LDAP Change Detection

When LDAP data is refreshed (periodic sync or app restart), changes are automatically detected and sent to the alert channel.

Detected changes:
- ➕ New employee
- ➖ Departed employee
- 🔄 Department transfer
- ✏️ Attribute changes (name, nickname, phone, searchable custom attributes)
- 📁 Organization added/removed

> Requires an alert channel to be configured. Set up via App Home → Alert Channel.

## Advanced Configuration

After initial setup, you can fine-tune `config.yaml`:

### Title/Position Display Mode

You can configure how titles/positions are displayed in `config.yaml`:

```yaml
# Show only titles in the list (default)
titles:
  mode: "whitelist"
  list: ["Manager", "Director", "VP", "CEO"]

# Hide only titles in the list, show everything else
titles:
  mode: "blacklist"
  list: ["Intern", "Trainee"]

# Show all title values as-is
titles:
  mode: "all"

# Never show titles
titles:
  mode: "none"
```

### Filters

```yaml
filters:
  excluded_ou_prefixes:               # OUs starting with these are hidden
    - "("
  service_account_names:              # Exact name matches to exclude
    - "syslog"
    - "admin"
  service_account_keywords:           # Names containing these are excluded
    - "shared"
    - "test"
```

### Cache

```yaml
cache:
  refresh_interval: 21300             # Data refresh interval (seconds)
  slack_user_ttl: 21600               # Slack user cache TTL (seconds)
```

## Handling Concurrent Positions (Multiple Assignments)

AD allows only one OU per user, so employees with concurrent positions across multiple departments cannot be natively represented. Below are recommended approaches:

### Option A: Use an Extension Attribute (Recommended)

Store concurrent assignments in an AD extension attribute using the **concurrent notation**:

```
Org1:Position1;Org2:Position2
```

**Examples:**
- `AI LAB:Advisor;TF Team:Member`
- `AI LAB` (position can be omitted)
- `Engineering:Manager;AI LAB:Advisor;TF Team`

Store this string in an AD extension attribute (e.g., `extensionAttribute10`), then configure:

```yaml
employee_attrs:
  - name: "concurrent"
    label: "Concurrent Positions"
    attr: "extensionAttribute10"
    format: "concurrent"          # Enables parsing of the notation
    in_name: false
```

The app will parse the notation and display each assignment in the employee card:

```
📎 AI LAB: Advisor
📎 TF Team: Member
```

This requires IT team coordination to populate the AD attribute.

### Option B: App Home UI Management

You can manage concurrent positions directly from the App Home admin panel (**Concurrent Positions** menu) without modifying AD. Assignments are stored in `concurrent.json` (auto-generated, separate from `config.yaml`).

### Option C: Duplicate AD Accounts

Some organizations create separate AD accounts per assignment (e.g., `user-eng`, `user-ai`). This works out of the box but creates duplicate entries in the org chart. Use the service account filter to hide the secondary accounts if needed.

## Troubleshooting

| Issue | Solution |
|-------|---------|
| App not responding | Check `./run.sh status` and `./run.sh log` |
| LDAP connection failed | Verify LDAP host/port/credentials in `.env` |
| Slack connection error | Check Slack tokens; regenerate App-Level Token if needed |
| Missing employees | Check `LDAP_USER_BASE_DN` points to the correct OU |
| Old data showing | Restart the app or wait for auto-refresh |
| Multiple bot responses | Run `./run.sh stop` then `./run.sh start` to clear zombie processes |
