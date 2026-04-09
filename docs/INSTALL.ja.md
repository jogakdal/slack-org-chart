# Slack-Org-Chart インストールガイド

> 🌐 [한국어](INSTALL.ko.md) | [English](INSTALL.en.md) | **日本語** | [中文](INSTALL.zh.md)

組織図 Slackアプリのセットアップ手順を説明します。

## 前提条件

- 読み取り専用サービスアカウントがある **LDAP/ADサーバー**
- アプリインストール権限がある **Slackワークスペース**
- アプリからLDAPサーバーとインターネット（Slack API）の両方にアクセス可能

## Step 1. アプリサーバーのインストール

2つの方法から選択します。

### 方法A: バイナリインストール（推奨）

[Releases](https://github.com/jogakdal/slack-org-chart/releases) からOSに合ったパッケージをダウンロードします。Pythonのインストールは不要です。

```bash
tar xzf slack-org-chart-linux.tar.gz   # Linux
tar xzf slack-org-chart-macos.tar.gz   # macOS
# Windows: zipファイルを解凍
cd slack-org-chart/
```

### 方法B: Dockerインストール

Dockerのみインストールされていれば使えます。追加の依存関係は不要です。

```bash
mkdir slack-org-chart && cd slack-org-chart
docker pull ghcr.io/jogakdal/slack-org-chart:latest
# config.yamlと.envをStep 3で設定してから実行します。
```


## Step 2. Slackアプリ作成

1. https://api.slack.com/apps にアクセス
2. **"Create New App"** → **"From scratch"** を選択
3. App Nameを入力しワークスペースを選択
   - 推奨名: `組織図` または `組織名 + 組織図`
4. **"Create App"** をクリック
5. (任意) **"Basic Information"** → **"Display Information"** でアプリアイコンを登録します。
   - 512x512px以上のPNG/JPG推奨

### 2-1. Bot User設定

1. 左メニューの **"App Home"** をクリック
2. **"App Display Name"** の **"Edit"** をクリック
3. Display NameとDefault Usernameを入力
4. **"Save"** をクリック

### 2-2. Socket Mode有効化

1. 左メニューの **"Socket Mode"** をクリック
2. Socket Modeを有効化
3. Token Nameを入力して **"Generate"** をクリック
4. **App-Level Token** (`xapp-...`) をコピー

### 2-3. スラッシュコマンド登録

**"Slash Commands"** で以下の2つのコマンドを登録します。

| 項目 | コマンド1 | コマンド2 |
|------|----------|----------|
| Command | `/orgchart` | `/whois` |
| Short Description | `Org Chart / Search` | `Org Chart / Search` |
| Usage Hint | `[name/nickname/dept/title/phone] (? help)` | `[name/nickname/dept/title/phone] (? help)` |

> **注意:** 両方のコマンドは同じ動作をします。テキストなしで実行すると組織図、テキストありで統合検索です。
> コマンド名は `config.yaml` の `commands` セクションで変更できます。

### 2-4. Interactivity有効化

**"Interactivity & Shortcuts"** でInteractivityがオンになっていることを確認します。

### 2-5. Event Subscriptions設定

1. 左メニューの **"Event Subscriptions"** をクリック
2. **"Enable Events"** をオン
3. **"Subscribe to bot events"** で `app_home_opened` を追加
4. **"Save Changes"** をクリック

### 2-6. App Homeタブ有効化

1. 左メニューの **"App Home"** をクリック
2. **"Show Tabs"** で **"Home Tab"** をオン

### 2-7. Bot Token Scopes設定

**"OAuth & Permissions"** で以下のscopeを追加します。

| Scope | 用途 |
|-------|------|
| `commands` | スラッシュコマンド登録 |
| `chat:write` | メッセージ送信 |
| `users:read` | ユーザー情報取得 |
| `users:read.email` | メールベースのSlack ↔ LDAPユーザーマッピング |
| `channels:manage` | アラートチャンネル作成 |
| `channels:read` | チャンネル一覧取得 |
| `groups:write` | プライベートチャンネル作成・メンバー管理 |
| `groups:read` | プライベートチャンネル一覧取得 |

### 2-8. ワークスペースにインストール

1. **"Install App"** で **"Install to Workspace"** をクリック
2. 管理者の承認が必要な場合は承認を待ちます。
3. インストール後、**Bot User OAuth Token** (`xoxb-...`) をコピー

### 2-9. Signing Secret確認

**"Basic Information"** → **"App Credentials"** で **Signing Secret** をコピーします。

## Step 3. 設定

### 方法A: 手動設定（バイナリ/Docker）

```bash
cp config.example.yaml config.yaml
cp .env.example .env
```

`config.yaml` と `.env` を編集します。`.env` にはStep 2でコピーしたSlackトークンとLDAP接続情報を入力します。

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


## Step 4. LDAPスキーマ確認

デフォルトのAD属性マッピングはほとんどのAD環境で動作します。会社のADが異なる属性名を使用している場合は `config.yaml` の `ldap.attr_map` を修正してください。

## Step 5. 実行

### バイナリ

```bash
./run.sh start                        # 起動
./run.sh start --auto-start=true      # 起動 + サーバー再起動時に自動起動
./run.sh status                       # 状態確認
./run.sh log                          # ログ確認
./run.sh restart                      # 再起動
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

`--restart always` でサーバー再起動時に自動起動されます。

```bash
docker logs -f slack-org-chart        # ログ確認
docker restart slack-org-chart        # 再起動
docker stop slack-org-chart           # 停止
```

初回起動時にLDAPから全データをロードします（約5〜10秒）。その後、Slackで `/orgchart` または `/whois` が使用可能になります。

## Step 6. テスト

Slackで以下のコマンドを実行します。

- `/orgchart` — 組織図を表示
- `/whois 田中` — 社員検索
- `/whois name:田中` — フィルタ検索（名前フィールドのみ）
- `/whois "田中"` — 完全一致
- `/orgchart help` — ヘルプ

利用可能なフィルタ: `name:` `nick:` `email:` `dept:` `phone:` `attr:`

## LDAP変更検知

LDAPデータが更新されると（定期同期またはアプリ再起動時）、変更点を自動検知してアラートチャンネルに通知します。

検知項目:
- ➕ 新規入社
- ➖ 退職
- 🔄 部署異動
- ✏️ 属性変更（名前、ニックネーム、電話番号、検索可能カスタム属性）
- 📁 組織の追加/削除

> アラートチャンネルの設定が必要です。App Home → アラートチャンネルで設定してください。

## 詳細設定

初期設定後、`config.yaml` を直接編集して細かい調整ができます。

### 役職/肩書きの表示モード

`config.yaml` で役職/肩書きの表示方法を設定できます：

```yaml
# リストにある役職のみ表示（デフォルト）
titles:
  mode: "whitelist"
  list: ["課長", "部長", "本部長", "社長"]

# リストにある役職のみ非表示にし、それ以外はすべて表示
titles:
  mode: "blacklist"
  list: ["インターン", "研修生"]

# すべての役職をそのまま表示
titles:
  mode: "all"

# 役職を表示しない
titles:
  mode: "none"
```

フィルタリングルール、キャッシュ周期などは `config.example.yaml` を参照してください。

## トラブルシューティング

| 症状 | 解決方法 |
|------|---------|
| アプリが反応しない | `./run.sh status` と `./run.sh log` を確認 |
| LDAP接続失敗 | `.env` のLDAPホスト/ポート/認証情報を確認 |
| Slack接続エラー | Slackトークンを確認。App-Level Tokenを再発行 |
| 社員が表示されない | `LDAP_USER_BASE_DN` が正しいOUを指しているか確認 |
| 古いデータが表示される | アプリを再起動するか自動更新を待つ |
| ボットの応答が重複する | `./run.sh stop` 後 `./run.sh start` でゾンビプロセスを整理 |
