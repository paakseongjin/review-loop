# review-loop — AI가 쓴 코드를 "믿지 않고 검증"하는 코드리뷰 루프 스킬

버전 1.1.0 · Claude Code / Cursor 양쪽 대응 · Agent Skills 표준(SKILL.md) 기반

## 이 스킬이 하는 일

AI가 생성한 코드를 AI의 인상평으로 리뷰하던 방식을, 아래 루프로 바꿉니다.

0. **범위·기준 고정** — 무엇을 리뷰하는지, 코드가 "원래 무엇을 해야 하는지(명세·불변식)"를 먼저 확정. 명세가 없으면 추정한 명세라고 명시합니다.
1. **기계 게이트** — 테스트·타입·린트·빌드·비밀키·의존성을 실제로 실행. 실행하지 않은 검사는 "통과"가 아니라 "건너뜀"으로 기록합니다. 테스트가 명세의 동작을 실제로 확인하는지도 살핍니다. 화면 변경이 있으면 안전한 테스트 환경에서 대표 사용자 흐름과 오류 경로를 직접 확인하고, 불가능하면 이유를 기록합니다.
2. **렌즈별 분리 리뷰** — 보안/권한, ACID/트랜잭션, 동시성/멱등성, 데이터 무결성, 오류 처리, 의존성/공급망, 아키텍처/표류. 한 번에 뭉뚱그려 보지 않습니다.
3. **증거와 실질적 영향** — 재현 또는 결정적 코드 추적을 요구하고, 영향이 없는 스타일 지적과 중복 지적은 제외합니다. 기존 문제와 변경으로 생긴 문제를 구분합니다.
4. **수정 루프** — 수정이 허용된 경우 실질적인 결함을 원인별로 수정하고 재현·영향받는 검사를 다시 실행합니다. 같은 원인의 지적은 하나로 추적하고, 후속 리뷰는 수정분과 필요한 주변 맥락에 집중합니다. 지적당 수정 3회, 리뷰 3회전을 상한으로 하되 해결되지 않은 위험은 숨기지 않고 보고합니다. 테스트를 약하게 만들어 통과시키는 행위는 금지됩니다.
5. **수정분 교차 점검** — 수정이 새 결함을 만들지 않았는지 새 눈으로 재검토.
6. **판정 보고** — 비개발자도 읽을 수 있는 평문 판정(배포 가능 / 조건부 / 불가 / 중단)과, 실제로 돌린 검사표, 미검증·차단 목록, 롤백 방법까지.

핵심 원칙: **LLM 리뷰는 가설 생성기이고, 결정적 도구와 재현이 심판입니다.**

## 설치

### 방법 A — 설치 스크립트 (권장, 프로젝트별)

```bash
# macOS / Linux
bash install.sh /path/to/your-project both     # claude | cursor | both

# Windows (PowerShell)
.\install.ps1 C:\path\to\your-project both
```

설치되는 것:

- Claude Code: `<project>/.claude/skills/review-loop/`
- Cursor: `<project>/.cursor/skills/review-loop/` + 상시 가드레일 룰 `<project>/.cursor/rules/review-loop-guardrails.mdc`

기존 설치가 있으면 덮어쓰지 않고 `.bak-날짜` 백업을 만든 뒤 설치합니다.

### 방법 B — Claude Code 마켓플레이스 플러그인

터미널에서 GitHub 저장소를 마켓플레이스로 등록하고 설치합니다.

```bash
claude plugin marketplace add paakseongjin/review-loop
claude plugin install review-loop@review-loop-local
claude plugin list
```

Claude Code 세션 안에서 `/plugin`으로 설치 상태를 확인하고 다음과 같이
호출합니다. 플러그인으로 설치한 스킬에는 플러그인 이름이 접두사로 붙습니다.

```text
/review-loop:review-loop
```

로컬 저장소에서 시험하려면 `claude plugin marketplace add /path/to/review-loop`를
사용하거나, 일회성으로 `claude --plugin-dir /path/to/review-loop`를 실행합니다.
업데이트할 때는 다음 명령을 실행하고 새 세션을 시작하거나 안내에 따라
`/reload-plugins`를 실행합니다. 이 마켓플레이스는 타사 마켓플레이스이므로
자동 업데이트가 기본적으로 꺼져 있습니다.

```bash
claude plugin marketplace update review-loop-local
claude plugin update review-loop@review-loop-local
```

공식 안내: [마켓플레이스 등록](https://code.claude.com/docs/en/plugin-marketplaces),
[플러그인 설치와 업데이트](https://code.claude.com/docs/en/discover-plugins).

### 방법 C — 전역(모든 프로젝트) 설치

`skills/review-loop` 폴더를 아래 위치에 복사하면 전 프로젝트에서 쓸 수 있습니다.

- Claude Code: `~/.claude/skills/review-loop/`
- Cursor: `~/.cursor/skills/review-loop/` (또는 `~/.agents/skills/review-loop/`)

Cursor의 **Customize → Skills**에서 설치 여부를 확인할 수 있습니다. 전역 스킬 복사는
Cursor 상시 룰을 자동으로 설치하지 않습니다. 이 저장소는 현재 Claude Code
플러그인 매니페스트를 제공하며, Cursor 플러그인 매니페스트는 제공하지 않습니다.
Cursor에서는 방법 A의 프로젝트별 설치 또는 위 스킬 복사 방식을 사용하세요.
[Cursor 스킬](https://cursor.com/docs/skills), [Cursor 플러그인](https://cursor.com/docs/plugins).

## 사용법

프로젝트 또는 전역 스킬로 설치한 경우 Claude Code / Cursor Agent 채팅에서:

```text
/review-loop                      # 현재 diff + 마지막 커밋을 기본 범위로 리뷰
/review-loop main..feature/pay    # 브랜치 범위 지정
/review-loop src/orders public    # 경로 + 위험 등급 지정
```

Claude Code 플러그인으로 설치한 경우 `/review-loop:review-loop`를 사용합니다.
리뷰만 요청하면 코드를 변경하지 않습니다. 수정을 원하면 다음처럼 명시하세요.

```text
/review-loop 변경 사항을 리뷰하고 확인된 실질적 결함을 수정해줘
```

첫 회전은 요청 범위를 검토하고 이후에는 수정분과 필요한 맥락을 검토합니다.
3회전 상한에 도달하거나 더 이상 진행할 수 없으면 미해결 위험과 이유를 보고합니다.
스킬 지침은 모델의 판단을 안내하며, 모든 오류를 발견하거나 절차가 항상
완벽하게 실행된다고 보장하지 않습니다.

위험 등급: `prototype`(실사용자·실데이터 없음) · `internal`(사내용) ·
`public`(공개 SaaS, 계정·개인정보) · `critical`(결제·의료·파괴적 데이터 작업).
`critical`에서는 스킬이 통과 판정을 해도 "사람 전문가 감사가 추가로 필요하다"는
문구가 보고서에 고정으로 남습니다.

모드 단축:

- "게이트만 돌려줘" → 1단계 검사표만 보고
- "빠른 리뷰 해줘" → 범위·게이트·렌즈 1~3만 수행하고 부분 리뷰임을 명시

## 함께 쓰면 좋은 것

- `skills/review-loop/templates/project-guardrails.md`의 내용을 프로젝트
  `AGENTS.md` / `CLAUDE.md`에 붙여 넣으면, 리뷰를 돌리지 않는 평소 작업에도
  같은 금지 규칙(테스트 약화 금지, 트랜잭션 강제 등)이 상시 적용됩니다.
- `skills/review-loop/templates/spec-invariants.md`로 프로젝트의
  `SPEC.md`(불변식 목록)를 만들어 두면, 리뷰의 판정 기준이 추정이 아니라
  확정된 의도가 됩니다. ACID 문장 예시가 들어 있습니다.
- `skills/review-loop/scripts/gate.sh`는 스킬 없이 단독으로도 실행할 수
  있는 기계 게이트 스크립트입니다. 도구를 설치하지 않으며 없는 도구는
  SKIPPED로 표시합니다. 테스트·빌드 명령은 파일을 변경하거나 네트워크에
  접근할 수 있으므로 실행 전에 확인하세요. 종료 코드 0은 실행된 검사에
  실패가 없다는 뜻이며, 건너뛴 검사까지 통과했다는 뜻은 아닙니다.
  실패 출력은 비밀 노출 방지를 위해 표시하지 않습니다.

## 구성

```
review-loop/
├── README.md
├── .claude-plugin/
│   ├── plugin.json          # Claude Code 플러그인 매니페스트
│   └── marketplace.json     # 로컬 마켓플레이스 (방법 B용)
├── skills/review-loop/
│   ├── SKILL.md             # 본체: 루프 절차와 강제 규칙
│   ├── references/
│   │   ├── lenses.md            # 렌즈 7종 상세 체크리스트 (ACID 포함)
│   │   ├── loop-engineering.md  # 지적 선별, 중복 제거, 리뷰 종료 기준
│   │   ├── evaluation-cases.md  # 결함·정상·회귀 시나리오 평가 사례
│   │   ├── evidence-and-severity.md  # 지적 증거 형식·심각도·판정 매핑
│   │   └── mechanical-gates.md       # 스택별 게이트 명령표
│   ├── templates/
│   │   ├── review-report.md     # 판정 보고서 양식
│   │   ├── spec-invariants.md   # 명세·불변식 양식
│   │   ├── fix-loop-log.md      # 수정 시도 기록 양식
│   │   └── project-guardrails.md# AGENTS.md 상시 규칙
│   └── scripts/
│       └── gate.sh              # 스택 자동감지 기계 게이트
├── cursor/
│   └── review-loop-guardrails.mdc  # Cursor 상시 적용 룰
├── examples/
│   └── example-report.md    # 판정 보고서 예시(가상 사례)
├── install.sh / install.ps1
└── validate.py              # 패키지 자체 검증 스크립트
```

## 한계 (정직하게)

- 이 스킬은 절차를 안내하지만, 실행하지 않은 검사를 통과로 만들지는
  못합니다. 도구가 없는 환경에서는 그만큼 SKIPPED가 늘어납니다.
- 서로 다른 모델끼리의 교차 점검도 공통 사각지대를 완전히 없애지는
  못합니다. 그래서 이 스킬은 교차 점검보다 기계 게이트와 재현을
  먼저 둡니다.
- 결제·의료·개인정보처럼 실패 비용이 큰 서비스는, 이 스킬의 통과
  판정과 별개로 사람 전문가의 감사가 필요합니다.

## 근거와 참고 문서

- [Claude Code 팀의 코드 리뷰 방식](https://claude.dev/blog/solving-code-review-at-anthropic/)에서 리뷰 수렴, 기존 문제 구분, 중복 지적 방지, 실제 사례 기반 평가를 참고했습니다. 이 스킬의 세부 종료 규칙과 판정 방식은 해당 글을 바탕으로 한 자체 설계입니다.
- [Claude Code 플러그인](https://code.claude.com/docs/en/plugins)과 [마켓플레이스](https://code.claude.com/docs/en/plugin-marketplaces) 문서.
- [Cursor 플러그인 구성](https://cursor.com/docs/reference/plugins)과 [로컬 플러그인 안내](https://cursor.com/docs/plugins).

`skills/review-loop/references/evaluation-cases.md`의 사례는 합성 평가 예시입니다.
실제 오탐률이나 개선 효과를 입증한 벤치마크 결과가 아닙니다.
