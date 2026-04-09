# Slack App Home 설정 UI 구현 플랜

## 목표

`config.yaml`과 환경변수에 의존하던 모든 설정을 Slack App Home 탭에서 관리할 수 있게 한다.
관리자 권한을 부여하여 일반 사용자와 관리자의 화면을 분리한다.

## 아키텍처

```
[App Home 탭]
├── 일반 사용자 ──► 조직도 탐색 UI + 검색 바로가기
└── 관리자 ──────► 설정 관리 UI + 조직도 탐색 UI

[설정 저장소]
config.yaml (초기 로드) ──► 메모리 (런타임) ◄── App Home 모달 (수정)
                                              │
                                              ▼
                                         config.yaml (저장)
```

## 사전 준비

### Slack 앱 설정 추가
1. api.slack.com/apps → Event Subscriptions 활성화
2. Subscribe to bot events: `app_home_opened` 추가
3. Bot Token Scopes 추가: (기존에 없으면)
   - `chat:write` (이미 있음)

### config.yaml에 관리자 설정 추가
```yaml
admin:
  emails:
    - "hyh@hunet.co.kr"
```

## Phase 1: App Home 프레임워크 + 관리자 권한

### 구현 항목
- [ ] `app_home_opened` 이벤트 핸들러
- [ ] 관리자 판별 (config.yaml의 admin.emails 기반)
- [ ] 일반 사용자 홈 뷰 (조직도 바로가기, 도움말)
- [ ] 관리자 홈 뷰 (설정 메뉴 버튼 + 일반 사용자 뷰)
- [ ] `views.publish` API로 사용자별 화면 렌더링

### 일반 사용자 홈 뷰
```
📂 조직도
[전사 조직도 보기]    [직원 검색 도움말]

💡 사용법
/orgchart — 조직도 보기
/whois — 직원/부서 검색
```

### 관리자 홈 뷰
```
⚙️ 관리 설정

*조직 설정*               — 조직명, 이메일 도메인, 언어 등 기본 설정
*소속 부서 관리*           — 직원의 추가 소속 부서 등록/삭제
*직원 추가 속성 관리*      — 직책, 직급 등 직원 추가 속성 정의 및 해석 규칙 설정
*부서 추가 속성 관리*      — 부서 설명, 부서장 등 부서 추가 속성 정의
*직원 보기 템플릿*         — 직원 카드/리스트의 이름 형식, 표시 항목, 프로필 이미지 설정
*부서 보기 템플릿*         — 부서 카드/검색 결과에 표시할 항목 설정
*필터 설정*               — 서비스 계정 제외, 갱신 주기 등
*관리자 관리*              — 이 설정 화면에 접근할 수 있는 관리자 관리
*캐시 갱신*               — LDAP 데이터를 즉시 다시 불러옵니다

📂 조직도
[전사 조직도 보기]    [직원 검색 도움말]
```

### 파일 구조
```
src/
├── app_home.py          # App Home 뷰 렌더링 + 이벤트 핸들러
└── app_home_modals.py   # 설정 모달 (Phase 2~4에서 확장)
```

## Phase 2: 겸직 관리 모달

### 구현 항목
- [ ] "겸직 관리" 버튼 → 모달 열기
- [ ] 모달: 직원 이메일 입력 → 현재 겸직 목록 표시
- [ ] 겸직 추가 (조직명 + 직책)
- [ ] 겸직 삭제
- [ ] 변경 사항을 메모리에 즉시 반영 + config 파일에 저장

### 데이터 저장
- 겸직 데이터를 `config.yaml`의 `concurrent_assignments` 섹션에 저장
- 또는 별도 `data/concurrent.yaml`에 저장 (config와 분리)
- 앱 시작 시 로드, 모달에서 수정 시 즉시 반영 + 파일 저장

### 모달 UI
```
겸직 관리

직원 이메일: [hyh@hunet.co.kr    ]  [조회]

현재 겸직:
  AI LAB | 자문위원                [삭제]
  구독500 TFT | 위원              [삭제]

겸직 추가:
  조직명: [____________]
  직책:   [____________]  (선택)
                               [추가]
```

## Phase 3: 조직 설정 모달 ✅

- [x] 조직 표시 이름, 루트 OU, 이메일 도메인, 아바타 URL 수정
- [x] 언어 변경 + App Home 즉시 갱신
- [x] config.yaml 저장 + Config 메모리 반영

## Phase 4: 직원 추가 속성 관리 모달 (구 커스텀 필드) ✅

- [x] 속성 목록 표시 (이름, 라벨, 모드) + 수정/삭제 버튼
- [x] 속성 추가/수정 모달 (push)
- [x] 미리보기 (가상 직원 카드)
- [x] 기본값으로 초기화
- [x] 프로필 이미지 표시 설정

## Phase 4.5: 관리자 관리 모달 ✅

- [x] 현재 관리자 리스트 (이름/이메일/소속 + 삭제 버튼)
- [x] 직원 자동완성으로 관리자 추가
- [x] 자기 자신 삭제 방지

## Phase 5: 필터 설정 모달 ✅

- [x] 제외 부서 (이름 일치 + 키워드 포함)
- [x] 제외 계정 (이름 일치 + 키워드 포함)
- [x] 대소문자/공백 무시 매칭
- [x] 계단식 필터링 (상위 부서 제외 → 하위도 제외)
- [x] 제외된 부서 직원: 겸직 조직 또는 회사명 표시, 최상위 멤버에 포함
- [x] 저장 시 데이터 자동 재로드

## Phase 5.5: LDAP(AD) 관리 모달 ✅

- [x] 읽기 전용 표시 + 개별 [수정] 버튼 방식
- [x] Host, Port, Bind DN: 텍스트 수정
- [x] SSL: 체크박스 토글 (즉시 저장)
- [x] 비밀번호: [비밀번호 수정] 버튼 → push 모달 (보안 안내)
- [x] Base DN, User Base DN: LDAP 브라우저 (선택형 드롭다운)
- [x] 루트 조직 단위: User Base DN에서 자동 결정 (읽기 전용)
- [x] 데이터 갱신 주기 수정
- [x] 접속 테스트 (현재 입력값 기반, 타임아웃 5초, 접속 중 표시)
- [x] 자동 감지 (Base DN + User Base DN + Root OU 자동 조회)
- [x] 미리보기 (직원 수 + 샘플 + 하위 조직 표시)
- [x] 캐시 갱신 (App Home에서 LDAP 관리로 이동)
- [x] 접속 실패 시 자동감지/미리보기/캐시갱신 버튼 숨김
- [x] config.yaml 저장, .env fallback
- 비밀번호도 config.yaml에 저장 (초기 설정 시 .env, 이후 모달에서 변경 시 config.yaml)

## Phase 6: 즉시 실행 기능

### 구현 항목
- [x] "캐시 갱신" 버튼 → LDAP 데이터 즉시 재로드
- [ ] "Slack 유저 갱신" 버튼 → Slack 유저 캐시 즉시 갱신
- [ ] 마지막 갱신 시간, 직원 수 등 App Home에 표시

## Phase 6.5: 메시지 그룹 기반 네비게이션 개선 ✅

- [x] 메시지 그룹 ID (gid): org_tree_block에서 자동 생성, 사용자별 최신 gid 추적
- [x] 드릴다운/뒤로/홈 버튼 값을 JSON으로 변경 (`{"dn": "...", "g": "gid"}`)
- [x] 핸들러: 내 gid == 최신 → replace, 아니면 → new message
- [x] 최신이 아닌 메시지 버튼은 활성 유지 (허브 역할)
- [x] gid가 없는 연속 메시지(더보기)도 이전 gid 무효화
- [x] 더 보기 버튼 캡션: "더 보기 (N/M명 또는 개)"

## Phase 7: 직원 추가 속성 관리 리팩토링 ✅

### 구현 항목
- [x] `custom_fields` → `employee_attrs` 완전 전환 (config.yaml, config.example.yaml, 코드 전체)
- [x] `Config.CUSTOM_FIELDS` 별칭 및 `_parse_custom_fields` 제거
- [x] `in_name` 필드 제거 (이름 표시는 name_format 템플릿으로 대체)
- [x] `Employee.honorific`: in_name 순회 → `field_used_in_name()` 템플릿 기반 전환
- [x] `Employee.detail_fields` 제거 (blocks.py `_get_detail_fields()`로 대체 완료)
- [x] AD 속성 매핑 (attr, format)을 모달에서 직접 편집 가능하게 변경
- [x] 모달 UI 개선: 타이틀 변경, 프로필 이미지 체크박스, 모드명 한국어화
- [x] 목록 표시 개선: 라벨 + AD 속성 매핑 + 표시 규칙 2줄 구성
- [x] `display` 섹션 config.yaml에 명시적 생성 (fallback chain에서 연락처 필드 제외)
- [x] `empty_display` 옵션 추가 (표시 안함 / "없음"으로 표시 / 빈 값으로 표시)
- [x] 미리보기 기능 제거 (Phase 9 직원 보기 템플릿으로 이동 예정)
- [x] AD 속성 자동완성 (external_select): 잘 알려진 속성 + 샘플 합집합, 사용 통계 표시
- [x] 속성 추가/삭제 시 display.employee_card.fields 자동 동기화
- [x] whitelist 목록 순서를 직책 정렬 우선순위로 활용 (Employee.title_priority)

## Phase 8: 부서 추가 속성 관리 모달 ✅

### 구현 항목
- [x] `DeptAttrDef` 클래스 + `dept_attrs` config.yaml 섹션 도입
- [x] OrgUnit에 `extra_attrs` 추가, load_ou_tree에서 부서 속성 로드
- [x] 부서 속성 추가/수정/삭제 모달 (목록/편집 push 모달)
- [x] AD OU 속성 자동완성 (external_select, 전체 OU 조회)
- [x] `dn_to_name` 포맷 지원 (managedBy DN → 직원 이름)
- [x] `empty_display` 옵션 (직원 속성과 동일)
- [x] 조직도 부서 드릴다운 시 부서 속성 context 블록 표시
- [x] `/whois` 직원 0명 + 부서 1개 → 바로 조직도 표시
- [x] AD 속성 자동완성에서 등록 속성 중복 제외 제거 (직원/부서 모두)
- [x] `_evict_user_message` 미정의 참조 수정

## Phase 9: 직원 보기 템플릿 관리 모달 ✅

### 구현 항목
- [x] 직원 카드 / 직원 리스트 2개 컨텍스트 설정 (프리셋 + 직접 수정 + 표시 필드 + 프로필 이미지)
- [x] 이름 형식 프리셋 선택 (즉시 저장) + [직접 수정] push 모달 (변수 설명 + 문법 힌트)
- [x] 표시 필드 체크박스 (즉시 저장, employee_attrs 순서 반영)
- [x] 프로필 이미지 체크박스 (카드/리스트 개별, 즉시 저장)
- [x] 미리보기 (카드 + 리스트 동시 표시, 멘션/닉네임 반영)
- [x] 저장 버튼 없는 즉시 반영 방식 (모든 설정 변경 즉시 저장)
- [x] 속성 순서 이동 (▲/▼) 버튼 + display.fields 자동 동기화
- [x] AD 속성 아이콘 자동 매핑 (mobile→📞, telephoneNumber→☎️)
- [x] 연락처 라인 분리 (아이콘 속성은 이메일과 같은 줄에 표시)
- [x] 이름 템플릿에서 사용된 모든 필드 상세 리스트 중복 제외
- [x] 휴대폰 기본 속성 승격 (Employee.mobile, LDAP→Slack fallback, 항상 표시)
- [x] 닉네임 기본 속성 (Employee.nickname, AD→Slack Display Name fallback)
- [x] {nickname} 프리셋 추가, 멘션 연동 (닉네임 사용 시 이름이 멘션으로 표시)
- [x] 겸직 조직에서 해당 조직의 직책으로 표시 (honorific_override)
- [x] 직원 리스트 이름 형식 템플릿 존중 ({name}이면 이름, {nickname}이면 멘션)

## Phase 10: 부서 보기 템플릿 관리 모달 ✅

### 구현 항목
- [x] DeptDisplayConfig (show_member_count, show_full_path_*, fields)
- [x] 표시 필드 체크박스 (dept_attrs 기반, 즉시 저장)
- [x] 인원수 표시 여부 (조직도 드릴다운 + 하위 조직 + 부서 검색 모두 반영)
- [x] 경로 표시 방식 영역별 독립 설정 (직원 카드/리스트/부서 검색/조직도 드릴다운)
- [x] 조직도 드릴다운 전체 경로 시 경로 버튼 네비게이션
- [x] 겸직 조직 전체 경로 표시 + 경로 버튼 추가
- [x] 단말 부서명 모드 시 바로가기 버튼 제한
- [x] 미리보기 (영역별 실시간 반영, 부서 속성 포함)
- [x] 저장 버튼 없는 즉시 반영 방식

## Phase 11: /whois 속성 검색 확장 ✅

### 구현 항목
- [x] /whois에서 직원 추가 속성 값으로 검색 (예: `/whois 팀장`)
- [x] 닉네임 검색 지원 (이름 검색에 nickname 포함)
- [x] org_store.py에 search_by_attr_value 메서드 추가
- [x] exclude_from_search 설정 반영 (해당 값은 속성 검색에서 제외)
- [x] 이름/속성 검색 결과 중복 제거

## Phase 12: /orgchart + /whois 통합 ✅

### 구현 항목
- [x] 통합 핸들러 (handle_unified_command)로 두 명령어 동일 동작
- [x] 텍스트 없이 실행 → 루트 조직도 표시
- [x] 텍스트 있으면 → 이름/닉네임/속성/부서 통합 검색
- [x] 슬래시 명령어 커스터마이징 지원 (config.yaml commands 섹션)

## Phase 13: 검색 설정 + 결과 표시 모드 ✅

### 구현 항목
- [x] 검색 설정 모달 (App Home 관리자 메뉴)
- [x] 검색 대상 on/off (이름/닉네임/이메일/속성/부서)
- [x] 결과 표시 모드: 스마트(기본) / 카드 / 간략
- [x] 스마트 모드: 3명 이하 카드, 4명 이상 간략 리스트
- [x] 간략 모드: [상세] 버튼 → 카드 표시, 더보기 지원
- [x] 부서 자동 이동 on/off
- [x] 휴대폰 번호(일부) 검색 (하이픈/공백 무시, 항상 활성)
- [x] 검색 결과 헤더에 총 결과 수 표시
- [x] 직원 한 줄 텍스트 생성 공통화 (_employee_line_text)

## 기술 요구 사항

### Block Kit 제약
- App Home 탭에서는 `input` 블록 사용 불가 → 모든 입력은 **모달**에서 처리
- 모달은 최대 100 블록, 최대 3개 중첩 가능
- 모달의 `input` 블록에서 텍스트 입력, 드롭다운 선택 가능

### 데이터 일관성
- 모달에서 설정 변경 시:
  1. 메모리(Config/OrgStore) 즉시 반영
  2. config.yaml에 저장 (영속성)
  3. App Home 뷰 새로고침
- 파일 저장 실패 시 에러 표시, 메모리 변경은 유지 (다음 재시작 시 이전 값)

### 보안
- 관리자 이메일 목록은 config.yaml에서만 초기 설정 가능 (부트스트랩)
- App Home에서 관리자 추가/삭제는 기존 관리자만 가능
- 모든 설정 변경은 로그에 기록

## 예상 작업량

| Phase | 예상 시간 | 의존성 |
|-------|----------|--------|
| Phase 1 | 2-3시간 | 없음 |
| Phase 2 | 3-4시간 | Phase 1 |
| Phase 3 | 2-3시간 | Phase 1 |
| Phase 4 | 3-4시간 | Phase 1 |
| Phase 5 | 2-3시간 | Phase 1 |
| Phase 6 | 1-2시간 | Phase 1 |
