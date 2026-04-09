# Slack-Org-Chart 安装指南

> 🌐 [한국어](INSTALL.ko.md) | [English](INSTALL.en.md) | [日本語](INSTALL.ja.md) | **中文**

本指南介绍如何为您的组织设置组织图 Slack 应用。

## 前置条件

- 具有只读服务账号的 **LDAP/AD 服务器**
- 具有应用安装权限的 **Slack 工作区**
- 应用需要同时访问 LDAP 服务器和互联网（Slack API）

## Step 1. 安装应用服务器

从以下两种方式中选择一种。

### 方法 A：二进制安装（推荐）

从 [Releases](https://github.com/jogakdal/slack-org-chart/releases) 下载适合您操作系统的安装包。无需安装 Python。

```bash
tar xzf slack-org-chart-linux.tar.gz   # Linux
tar xzf slack-org-chart-macos.tar.gz   # macOS
# Windows: 解压 zip 文件
cd slack-org-chart/
```

### 方法 B：Docker 安装

只需安装 Docker 即可使用，无需其他依赖。

```bash
mkdir slack-org-chart && cd slack-org-chart
docker pull ghcr.io/jogakdal/slack-org-chart:latest
# 在 Step 3 中配置 config.yaml 和 .env 后再运行。
```


## Step 2. 创建 Slack 应用

1. 访问 https://api.slack.com/apps
2. 点击 **"Create New App"** → **"From scratch"**
3. 输入 App Name 并选择工作区
   - 建议名称: `组织图` 或 `公司名 + 组织图`
4. 点击 **"Create App"**

### 2-1. Bot User 设置

1. 点击左侧菜单 **"App Home"**
2. 在 **"App Display Name"** 下点击 **"Edit"**
3. 输入 Display Name 和 Default Username
4. 点击 **"Save"**

### 2-2. 启用 Socket Mode

1. 点击左侧菜单 **"Socket Mode"**
2. 启用 Socket Mode
3. 输入 Token Name 后点击 **"Generate"**
4. 复制 **App-Level Token** (`xapp-...`)

### 2-3. 注册斜杠命令

在 **"Slash Commands"** 中注册以下两个命令：

| 字段 | 命令 1 | 命令 2 |
|------|--------|--------|
| Command | `/orgchart` | `/whois` |
| Short Description | `Org Chart / Search` | `Org Chart / Search` |
| Usage Hint | `[name/nickname/dept/title/phone] (? help)` | `[name/nickname/dept/title/phone] (? help)` |

> **注意:** 两个命令的功能完全相同。不输入文本运行显示组织图，输入文本进行统一搜索。
> 命令名称可在 `config.yaml` 的 `commands` 部分中更改。

### 2-4. 启用 Interactivity

在 **"Interactivity & Shortcuts"** 中确认 Interactivity 已开启。

### 2-5. Event Subscriptions 设置

1. 点击左侧菜单 **"Event Subscriptions"**
2. 开启 **"Enable Events"**
3. 在 **"Subscribe to bot events"** 中添加 `app_home_opened`
4. 点击 **"Save Changes"**

### 2-6. 启用 App Home 标签

1. 点击左侧菜单 **"App Home"**
2. 在 **"Show Tabs"** 中开启 **"Home Tab"**

### 2-7. Bot Token Scopes 设置

在 **"OAuth & Permissions"** 中添加以下 scope：

| Scope | 用途 |
|-------|------|
| `commands` | 注册斜杠命令 |
| `chat:write` | 发送消息 |
| `users:read` | 读取用户信息 |
| `users:read.email` | 基于邮箱的 Slack ↔ LDAP 用户映射 |
| `channels:manage` | 创建通知频道 |
| `channels:read` | 查询频道 |
| `groups:write` | 创建私有频道及管理成员 |
| `groups:read` | 查询私有频道 |

### 2-8. 安装到工作区

1. 在 **"Install App"** 中点击 **"Install to Workspace"**
2. 如需管理员审批，请等待审批通过。
3. 安装完成后复制 **Bot User OAuth Token** (`xoxb-...`)

### 2-9. 获取 Signing Secret

在 **"Basic Information"** → **"App Credentials"** 中复制 **Signing Secret**。

## Step 3. 配置

### 方法 A：手动配置（二进制/Docker）

```bash
cp config.example.yaml config.yaml
cp .env.example .env
```

编辑 `config.yaml` 和 `.env`。在 `.env` 中输入 Step 2 中复制的 Slack 令牌和 LDAP 连接信息。

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


## Step 4. LDAP 模式确认

默认的 AD 属性映射适用于大多数 AD 环境。如果贵公司的 AD 使用不同的属性名，请修改 `config.yaml` 中的 `ldap.attr_map`。

## Step 5. 运行

### 二进制

```bash
./run.sh start                        # 启动
./run.sh start --auto-start=true      # 启动 + 服务器重启时自动启动
./run.sh status                       # 查看状态
./run.sh log                          # 查看日志
./run.sh restart                      # 重启
./run.sh stop                         # 停止
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

使用 `--restart always` 可在服务器重启时自动启动。

```bash
docker logs -f slack-org-chart        # 查看日志
docker restart slack-org-chart        # 重启
docker stop slack-org-chart           # 停止
```

首次启动时会从 LDAP 加载全部数据（约 5~10 秒），之后即可在 Slack 中使用 `/orgchart` 或 `/whois`。

## Step 6. 测试

在 Slack 中执行以下命令：

- `/orgchart` — 查看组织图
- `/whois 张三` — 搜索员工
- `/whois name:张三` — 筛选搜索（仅名称字段）
- `/whois "张三"` — 精确匹配
- `/orgchart help` — 查看帮助

可用筛选器: `name:` `nick:` `email:` `dept:` `phone:` `attr:`

## 高级配置

初始设置完成后，可以直接编辑 `config.yaml` 进行细节调整。

### 职称/职位显示模式

可以在 `config.yaml` 中配置职称/职位的显示方式：

```yaml
# 仅显示列表中的职称（默认）
titles:
  mode: "whitelist"
  list: ["经理", "总监", "副总裁", "总裁"]

# 仅隐藏列表中的职称，显示其他所有职称
titles:
  mode: "blacklist"
  list: ["实习生", "见习"]

# 按原样显示所有职称
titles:
  mode: "all"

# 不显示职称
titles:
  mode: "none"
```

筛选规则、缓存周期等请参考 `config.example.yaml`。

## 故障排除

| 问题 | 解决方法 |
|------|---------|
| 应用无响应 | 检查 `./run.sh status` 和 `./run.sh log` |
| LDAP 连接失败 | 检查 `.env` 中的 LDAP 主机/端口/凭据 |
| Slack 连接错误 | 检查 Slack 令牌；重新生成 App-Level Token |
| 员工未显示 | 确认 `LDAP_USER_BASE_DN` 指向正确的 OU |
| 显示旧数据 | 重启应用或等待自动刷新 |
| 机器人回复重复 | 执行 `./run.sh stop` 后 `./run.sh start` 清理僵尸进程 |
