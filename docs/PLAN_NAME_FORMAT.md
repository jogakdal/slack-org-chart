# 이름 표시 형식 설정 플랜

## 개요

직원 이름 표시 형식을 회사 정책과 언어에 맞게 자유롭게 설정할 수 있도록 한다.

## 템플릿 문법

### 기본 변수
- `{name}` — 표시 이름 (displayName)
- `{display_name}` — name과 동일
- 커스텀 필드명을 변수로 사용 가능: `{position}`, `{rank}`, `{employment}` 등

### Fallback chain (파이프 문법)
```
{position|rank|님}
```
- 왼쪽부터 순서대로 시도, 첫 번째 비어있지 않은 값 사용.
- 따옴표 또는 따옴표 없는 한글/영문 리터럴은 고정 문자열.
- `{position|""}` — position이 없으면 빈 문자열 (해당 위치 생략).

### 빈 값 처리
- 변수가 빈 값으로 resolve되면 해당 위치가 생략되고, 연속 공백은 하나로 축소.

## config.yaml 설정

```yaml
org:
  name_format:
    card:
      ko: "{name} {position|rank|님}"
      en: "{name}, {position|rank}"
      ja: "{name} {position|rank|さん}"
      default: "{name} {position|rank}"
    list:
      ko: "{name} {position|rank}"
      en: "{name}"
      default: "{name}"
```

### 동작 우선순위
1. 현재 언어에 해당하는 템플릿 사용.
2. 없으면 `default` 사용.
3. `default`도 없으면 `{name}` 사용.

## 프리셋

조직 설정 모달에서 언어별 자주 사용하는 패턴을 프리셋으로 제공하고, "직접 입력" 옵션으로 템플릿 변수를 편집할 수 있게 한다.

### 한국어 프리셋
1. `{name} {position|rank}` → 황용호 팀장 / 김철수 수석
2. `{name}님` → 황용호님
3. `{name} {position|rank|님}` → 황용호 팀장 / 김철수 수석 / 이영희 님
4. `{name} {position}` → 황용호 팀장 / 김철수

### 영어 프리셋
1. `{name}` → Yongho Hwang
2. `{name}, {position|rank}` → Yongho Hwang, Manager
3. `{position|rank} {name}` → Manager Yongho Hwang

### 일본어 프리셋
1. `{name} {position|rank}` → 黄龍虎 チーム長
2. `{name}さん` → 黄龍虎さん
3. `{name}様` → 黄龍虎様

## 적용 범위

- `/whois` 직원 카드: `card` 템플릿 사용.
- `/orgchart` 멤버 리스트: `list` 템플릿 사용.
- 비활성 사용자 `(비활성)` 표시는 템플릿 외부에서 자동 추가.

## 구현 순서

1. Phase 4(커스텀 필드 설정) 완료 후 진행.
2. 커스텀 필드에 따라 사용 가능한 변수가 결정되므로 의존성 있음.
3. 기존 `card_suffix`/`list_suffix`와 `emp.honorific` 로직을 템플릿으로 대체.
