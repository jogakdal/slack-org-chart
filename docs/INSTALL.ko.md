# Slack-Org-Chart 설치 가이드

> 🌐 **한국어** | [English](INSTALL.en.md) | [日本語](INSTALL.ja.md) | [中文](INSTALL.zh.md)

조직도 Slack 앱을 설치하는 방법을 안내합니다.

## 사전 요구 사항

- 읽기 전용 서비스 계정이 있는 **LDAP/AD 서버**
- 앱 설치 권한이 있는 **Slack 워크스페이스**
- 앱을 실행할 머신에 **Python 3.9+** 설치
- 앱에서 LDAP 서버와 인터넷(Slack API)에 모두 접근 가능해야 합니다.

## Step 1. 클론 및 설치

```bash
git clone <repository-url>
cd org-chart

python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

## Step 2. Slack 앱 생성

1. https://api.slack.com/apps 접속
2. **"Create New App"** → **"From scratch"** 선택
3. App Name 입력 후 워크스페이스 선택
   - 권장 이름: `조직도` 또는 `조직명 + 조직도`
4. **"Create App"** 클릭

### 2-1. Bot User 설정

1. 왼쪽 메뉴 **"App Home"** 클릭
2. **"App Display Name"** 에서 **"Edit"** 클릭
3. Display Name과 Default Username 입력
   - 이 이름이 Slack 메시지에서 봇 이름으로 표시됩니다.
4. **"Save"** 클릭

### 2-2. Socket Mode 활성화

1. 왼쪽 메뉴 **"Socket Mode"** 클릭
2. Socket Mode 활성화
3. Token Name 입력 (예: `orgchart-socket`) 후 **"Generate"** 클릭
4. **App-Level Token** (`xapp-...`)을 복사해 둡니다.

### 2-3. 슬래시 커맨드 등록

**"Slash Commands"** 에서 아래 두 개의 커맨드를 등록합니다.

| 항목 | 커맨드 1 | 커맨드 2 |
|------|---------|---------|
| Command | `/orgchart` | `/whois` |
| Short Description | `조직도/직원 검색` | `조직도/직원 검색` |
| Usage Hint | `[이름/닉네임/부서/직책/번호] (? 도움말)` | `[이름/닉네임/부서/직책/번호] (? 도움말)` |

> **참고:** 두 명령어는 동일하게 동작합니다. 텍스트 없이 실행하면 전사 조직도, 텍스트가 있으면 통합 검색입니다.
> 명령어 이름은 `config.yaml`의 `commands` 섹션에서 변경할 수 있습니다. Slack 앱 설정과 동일하게 맞춰야 합니다.
> 다국어 환경이라면 Short Description과 Usage Hint를 영어로 설정하는 것이 범용적입니다.

### 2-4. Interactivity 활성화

1. **"Interactivity & Shortcuts"** 에서 **Interactivity** 토글이 켜져 있는지 확인합니다.

### 2-5. Event Subscriptions 설정

1. 왼쪽 메뉴 **"Event Subscriptions"** 클릭
2. **"Enable Events"** 토글 ON (Socket Mode 사용 시 자동 활성화될 수 있음)
3. **"Subscribe to bot events"** 에서 **"Add Bot User Event"** 클릭 후 추가:
   - `app_home_opened`
4. **"Save Changes"** 클릭

### 2-6. App Home 탭 활성화

1. 왼쪽 메뉴 **"App Home"** 클릭
2. **"Show Tabs"** 에서 **"Home Tab"** 토글 ON

### 2-7. Bot Token Scopes 설정

**"OAuth & Permissions"** 에서 아래 scope를 추가합니다.

| Scope | 용도 |
|-------|------|
| `commands` | 슬래시 커맨드 등록 |
| `chat:write` | 메시지 전송 |
| `users:read` | 유저 정보 조회 |
| `users:read.email` | 이메일 기반 Slack ↔ LDAP 유저 매핑 |
| `channels:manage` | 알림 채널 생성 |
| `channels:read` | 채널 조회 |
| `groups:write` | 비공개 채널 생성 및 멤버 관리 |
| `groups:read` | 비공개 채널 조회 |

### 2-8. 워크스페이스에 설치

1. **"Install App"** 에서 **"Install to Workspace"** 클릭
2. 관리자 승인이 필요하면 승인을 기다립니다.
3. 설치 완료 후 **Bot User OAuth Token** (`xoxb-...`)을 복사합니다.

### 2-9. Signing Secret 확인

1. **"Basic Information"** → **"App Credentials"** 에서 **Signing Secret**을 복사합니다.

## Step 3. 설정

### 방법 A: 대화형 설정 (권장)

```bash
source venv/bin/activate
python app.py setup
```

조직 정보, LDAP 접속 정보, Slack 토큰, 언어를 대화형으로 입력하면 `config.yaml`과 `.env`가 자동 생성됩니다. LDAP/Slack 연결 테스트도 자동으로 수행됩니다.

### 방법 B: 수동 설정

```bash
cp config.example.yaml config.yaml
cp .env.example .env
```

`config.yaml`과 `.env`를 직접 편집합니다. 설정 항목은 `config.example.yaml`을 참고하세요.

## Step 4. LDAP 스키마 확인

기본 AD 속성 매핑은 대부분의 AD 환경에서 동작합니다. 회사의 AD가 다른 속성명을 사용한다면 `config.yaml`의 `ldap.attr_map`을 수정하세요.

## Step 5. 실행

```bash
./run.sh start     # 시작
./run.sh status    # 상태 확인
./run.sh log       # 로그 확인
./run.sh restart   # 재시작
./run.sh stop      # 종료
```

첫 시작 시 LDAP에서 전체 데이터를 로드하며 (약 5~10초), 이후 Slack에서 `/orgchart` 또는 `/whois`를 사용할 수 있습니다.

## Step 6. 테스트

Slack에서 아래 명령어를 실행합니다.

- `/orgchart` — 조직도 보기
- `/whois 홍길동` — 직원 검색
- `/whois name:홍길동` — 필터 검색 (이름 필드에서만)
- `/whois "홍길동"` — 정확한 매칭
- `/orgchart help` — 도움말

사용 가능한 필터: `name:` `nick:` `email:` `dept:` `phone:` `attr:`

## 고급 설정

초기 설정 후 `config.yaml`을 직접 편집하여 세부 조정할 수 있습니다.

### 직책/직급 표시 모드

`config.yaml`에서 직책/직급 표시 방식을 설정할 수 있습니다:

```yaml
# 목록에 있는 직책만 표시 (기본값)
titles:
  mode: "whitelist"
  list: ["팀장", "본부장", "대표", "사장"]

# 목록에 있는 직책만 숨기고 나머지는 모두 표시
titles:
  mode: "blacklist"
  list: ["인턴", "수습"]

# 모든 직책을 그대로 표시
titles:
  mode: "all"

# 직책을 표시하지 않음
titles:
  mode: "none"
```

필터링 규칙, 캐시 주기 등은 `config.example.yaml`을 참고하세요.

## 문제 해결

| 증상 | 해결 방법 |
|------|----------|
| 앱이 반응하지 않음 | `./run.sh status`와 `./run.sh log` 확인 |
| LDAP 연결 실패 | `.env`의 LDAP 호스트/포트/계정 확인 |
| Slack 연결 오류 | Slack 토큰 확인. App-Level Token 재발급 |
| 직원이 안 보임 | `LDAP_USER_BASE_DN`이 올바른 OU를 가리키는지 확인 |
| 이전 데이터가 보임 | 앱 재시작 또는 자동 갱신 대기 |
| 봇 응답이 중복됨 | `./run.sh stop` 후 `./run.sh start`로 좀비 프로세스 정리 |
