# Slack-Org-Chart インストールガイド

> 🌐 [한국어](INSTALL.ko.md) | [English](INSTALL.en.md) | **日本語** | [中文](INSTALL.zh.md)

組織図 Slackアプリのセットアップ手順を説明します。

## 前提条件

- 読み取り専用サービスアカウントがある **LDAP/ADサーバー**
- アプリインストール権限がある **Slackワークスペース**
- アプリを実行するマシンに **Python 3.9+**
- アプリからLDAPサーバーとインターネット（Slack API）の両方にアクセス可能

## Step 1. クローンとインストール

```bash
git clone <repository-url>
cd org-chart

python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

## Step 2. Slackアプリ作成

1. https://api.slack.com/apps にアクセス
2. **"Create New App"** → **"From scratch"** を選択
3. App Nameを入力しワークスペースを選択
   - 推奨名: `組織図` または `組織名 + 組織図`
4. **"Create App"** をクリック

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

### 2-6. ワークスペースにインストール

1. **"Install App"** で **"Install to Workspace"** をクリック
2. インストール後、**Bot User OAuth Token** (`xoxb-...`) をコピー

### 2-7. Signing Secret確認

**"Basic Information"** → **"App Credentials"** で **Signing Secret** をコピーします。

## Step 3. 設定

### 方法A: 対話式セットアップ（推奨）

```bash
source venv/bin/activate
python app.py setup
```

組織情報、LDAP接続情報、Slackトークン、言語を対話形式で入力すると `config.yaml` と `.env` が自動生成されます。

### 方法B: 手動設定

```bash
cp config.example.yaml config.yaml
cp .env.example .env
```

各ファイルを直接編集します。設定項目は `config.example.yaml` を参照してください。

## Step 4. 実行

```bash
./run.sh start     # 起動
./run.sh status    # 状態確認
./run.sh log       # ログ確認
./run.sh restart   # 再起動
./run.sh stop      # 停止
```

## Step 5. テスト

Slackで以下のコマンドを実行します。

- `/orgchart` — 組織図を表示
- `/whois 田中` — 社員検索
- `/whois name:田中` — フィルタ検索（名前フィールドのみ）
- `/whois "田中"` — 完全一致
- `/orgchart help` — ヘルプ

利用可能なフィルタ: `name:` `nick:` `email:` `dept:` `phone:` `attr:`

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

## トラブルシューティング

| 症状 | 解決方法 |
|------|---------|
| アプリが反応しない | `./run.sh status` と `./run.sh log` を確認 |
| LDAP接続失敗 | `.env` のLDAPホスト/ポート/認証情報を確認 |
| Slack接続エラー | Slackトークンを確認。App-Level Tokenを再発行 |
| 社員が表示されない | `LDAP_USER_BASE_DN` が正しいOUを指しているか確認 |
