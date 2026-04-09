# Slack-Org-Chart

LDAP(AD) 기반 조직도/직원 검색 Slack 앱입니다. 범용 솔루션으로 어떤 조직에서든 config.yaml만 수정하면 바로 사용할 수 있습니다.

> **설치 가이드:** [한국어](docs/INSTALL.ko.md) | [English](docs/INSTALL.en.md) | [日本語](docs/INSTALL.ja.md) | [中文](docs/INSTALL.zh.md)

## 주요 기능

### 통합 검색

`/whois`와 `/orgchart` 두 명령어가 동일하게 동작합니다. 명령어 이름은 config에서 변경 가능합니다.

| 사용법 | 설명 |
|--------|------|
| `/whois` | 전사 조직도 (텍스트 없이 실행) |
| `/whois 홍길동` | 이름/닉네임으로 검색 |
| `/whois user@company.com` | 이메일로 검색 |
| `/whois 1234` | 휴대폰 번호(일부)로 검색 |
| `/whois 팀장` | 직책/직급 등 속성 값으로 검색 |
| `/whois 개발팀` | 부서 검색 (1개 매칭 시 바로 조직도) |
| `/whois "홍길동"` | 정확한 매칭 (따옴표) |
| `/whois name:홍길동` | 필터 검색 (이름 필드에서만) |
| `/whois email:"hyh"` | 필터 + 정확한 매칭 조합 |
| `/whois ?` | 도움말 |

사용 가능한 필터: `name:` `nick:` `email:` `dept:` `phone:` `attr:`
관리자가 검색 설정에서 비활성화한 필드의 필터는 사용할 수 없습니다.

### 검색 결과 표시 모드

- **스마트 모드** (기본): 3명 이하 → 상세 카드, 4명 이상 → 간략 리스트
- **카드 모드**: 항상 상세 카드
- **간략 모드**: 항상 리스트 ([상세] 버튼으로 개별 카드 확인)

### 조직도 탐색

- 하위 조직 드릴다운 + 상위 조직/전체 조직도 네비게이션
- 부서 경로 전체/단말 표시 영역별 설정 (직원 카드/리스트/검색/드릴다운)
- 부서 추가 속성 표시 (설명, 부서장 등)
- 인원수 표시 on/off

### 직원 정보

- 이름 형식 프리셋 + 직접 수정 (닉네임/멘션 지원)
- 휴대폰 번호 (LDAP → Slack 프로필 fallback, 항상 표시)
- 닉네임 (AD → Slack Display Name fallback)
- 추가 속성 자유 정의 (AD 속성 자동완성, 빈 값 처리 방식 설정)
- 연락처 아이콘 자동 매핑 (휴대폰/내선번호)
- 겸직 조직별 직책 표시
- 직책자 우선 정렬 (whitelist 순서 = 우선순위)

### App Home 관리자 설정

| 메뉴 | 설명 |
|------|------|
| 조직 설정 | 조직명, 이메일 도메인, 언어 등 |
| 소속 부서 관리 | 겸직/추가 소속 등록 |
| 직원 추가 속성 | AD 속성 매핑, 표시 규칙, 순서 이동 |
| 부서 추가 속성 | 부서 설명, 부서장 등 (DN → 이름 변환) |
| 직원 보기 템플릿 | 이름 형식, 표시 항목, 프로필 이미지 (카드/리스트 독립) |
| 부서 보기 템플릿 | 인원수, 경로 표시, 부서 속성 (영역별 설정) |
| 검색 설정 | 검색 대상 on/off, 속성별 검색 제어, 표시 모드 |
| 필터 설정 | 제외 부서/계정, 소속 없는 직원 표시 |
| LDAP(AD) 관리 | 접속 정보, Base DN 브라우저, 자동 감지 |
| 관리자 관리 | 관리자 추가/삭제 (알림 채널 자동 초대/강퇴) |
| 알림 채널 | 오류/변동 알림 전용 비공개 Slack 채널 |
| 명령어 관리 | 슬래시 명령어 추가/삭제 |
| 앱 업데이트 | 최신 버전 확인 및 자동 업데이트 (바이너리) |

### 다국어 지원

한국어, 영어, 일본어, 중국어 (App Home에서 변경)

## 아키텍처

```
┌─────────────┐     ┌──────────────┐     ┌─────────────┐
│  Slack API  │<--->│slack_handlers │<--->│  OrgStore   │
│(Socket Mode)│     │  (핸들러)     │     │(메모리 저장소)│
└─────────────┘     └──────────────┘     └──────┬──────┘
                          │                      │
                    ┌─────┴─────┐          ┌─────┴─────┐
                    │  blocks   │          │ LdapClient │
                    │ (UI 빌더) │          │(데이터 로드) │
                    └───────────┘          └─────┬─────┘
                                                 │
                                           ┌─────┴─────┐
                                           │  AD(LDAP) │
                                           └───────────┘
```

- 앱 시작 시 LDAP에서 전체 직원/OU 데이터를 메모리에 로드합니다.
- 검색 인덱스(이메일, OU, 겸직) + 사전 정규화 캐시로 고속 검색.
- 통합 검색은 1회 스캔으로 이름/속성/모바일/이메일ID를 동시에 매칭합니다.
- 백그라운드 비동기 갱신 (기본 5시간 55분 주기). 갱신 중에도 기존 캐시로 즉시 응답.
- 스냅샷 패턴으로 원자적 데이터 교체.
- LDAP 동기화 시 변동 사항(입사/퇴사/부서이동/속성변경) 자동 감지 및 알림.

## 설치

### 바이너리 배포 (권장)

[Releases](https://github.com/jogakdal/slack-org-chart/releases)에서 OS에 맞는 패키지를 다운로드합니다.

```bash
tar xzf slack-org-chart-linux.tar.gz
cd slack-org-chart/
cp config.example.yaml config.yaml    # 편집
cp .env.example .env                  # Slack/LDAP 정보 입력
./run.sh start                        # 시작
./run.sh start --auto-start=true      # 시작 + 서버 재부팅 시 자동 시작
```

### Docker

```bash
# config.yaml과 .env를 먼저 준비
cp config.example.yaml config.yaml    # 편집
cp .env.example .env                  # Slack/LDAP 정보 입력

docker run -d --name slack-org-chart \
  --restart always \
  --env-file .env \
  -v $(pwd)/config.yaml:/app/config.yaml \
  -v $(pwd)/concurrent.json:/app/concurrent.json \
  jogakdal/slack-org-chart:latest
```

`--restart always` 옵션으로 서버 재부팅 시 자동으로 앱이 시작됩니다. 별도의 systemd/launchd 설정이 필요 없습니다.

```bash
docker logs -f slack-org-chart    # 로그 확인
docker restart slack-org-chart    # 재시작
docker stop slack-org-chart       # 종료
```

GitHub Container Registry에서 다운로드:
- `ghcr.io/jogakdal/slack-org-chart:latest`

### 소스 설치

```bash
git clone https://github.com/jogakdal/slack-org-chart.git
cd slack-org-chart
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
cp config.example.yaml config.yaml
cp .env.example .env
./run.sh start
```

## 설정

모든 설정은 `config.yaml`과 `.env`로 관리됩니다. App Home에서 대부분의 설정을 UI로 변경할 수 있습니다.

주요 설정:
- **LDAP 접속**: `.env` (초기) → App Home LDAP 관리에서 변경 가능
- **조직 설정**: 조직명, 이메일 도메인, 언어
- **직원/부서 속성**: AD 속성 매핑, 표시 규칙
- **검색**: 검색 대상, 표시 모드
- **필터**: 제외 부서/계정
- **명령어 이름**: `commands` 섹션에서 `/orgchart`, `/whois` 변경 가능
- **겸직 데이터**: `concurrent.json`에 별도 저장 (App Home에서 관리, 자동 생성)

## 기술 스택

- Python 3.9+
- [Slack Bolt for Python](https://slack.dev/bolt-python/)
- [ldap3](https://ldap3.readthedocs.io/)
- [PyYAML](https://pyyaml.org/)
- [parametric-ttl-cache](https://github.com/jogakdal/python_ttl_cache)
- Socket Mode (인바운드 포트 불필요)
- PyInstaller (바이너리 배포)
- GitHub Actions (자동 빌드)

## 프로젝트 구조

```
slack-org-chart/
├── app.py                      # 메인 엔트리포인트
├── run.sh                      # 시작/종료/재시작 스크립트
├── config.example.yaml         # 설정 템플릿
├── .env.example                # 환경변수 템플릿
├── concurrent.json             # 겸직 데이터 (자동 생성)
├── requirements.txt
├── pyproject.toml              # 프로젝트 메타데이터 + 의존성
├── slack-org-chart.spec        # PyInstaller 빌드 설정
├── .github/workflows/build.yml # GitHub Actions 자동 빌드
├── src/
│   ├── config.py               # config.yaml + .env 설정
│   ├── version.py              # 제품명, 버전
│   ├── name_format.py          # 이름 표시 형식 템플릿 엔진
│   ├── dn_utils.py             # DN 파싱 유틸리티
│   ├── ldap_client.py          # LDAP 데이터 로드 + AD 속성 조회
│   ├── org_store.py            # 메모리 저장소 + 검색 인덱스 + 통합 검색
│   ├── slack_users.py          # Slack 유저 정보 (프로필, 전화번호)
│   ├── slack_handlers.py       # 슬래시 커맨드 핸들러
│   ├── blocks.py               # Block Kit UI 빌더
│   ├── app_home.py             # App Home 탭
│   ├── app_home_modals.py      # App Home 설정 모달
│   ├── setup.py                # 대화형 초기 설정 CLI
│   └── i18n/                   # 다국어 메시지 (ko, en, ja, zh)
├── docs/
│   └── INSTALL.{ko,en,ja,zh}.md
└── tests/
```

## 라이선스

[Business Source License 1.1](LICENSE)

- **자유 사용**: 단일 조직 내부 업무 목적으로 자유롭게 사용, 수정, 재배포 가능.
- **제한**: 제3자에게 호스팅/매니지드 서비스로 제공 불가.
- **변환**: 2030-04-09 이후 MIT 라이선스로 자동 전환.
