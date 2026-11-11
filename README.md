# review-loop — AI가 쓴 코드를 "믿지 않고 검증"하는 코드리뷰 루프 스킬

버전 1.0.0 · Claude Code / Cursor 양쪽 대응 · Agent Skills 표준(SKILL.md) 기반

## 이 스킬이 하는 일

AI가 생성한 코드를 AI의 인상평으로 리뷰하던 방식을, 아래 루프로 바꿉니다.

0. **범위·기준 고정** — 무엇을 리뷰하는지, 코드가 "원래 무엇을 해야 하는지(명세·불변식)"를 먼저 확정. 명세가 없으면 추정한 명세라고 명시합니다.
1. **기계 게이트** — 테스트·타입·린트·빌드·비밀키·의존성을 실제로 실행. 실행하지 않은 검사는 "통과"가 아니라 "건너뜀"으로 기록합니다.
2. **렌즈별 분리 리뷰** — 보안/권한, ACID/트랜잭션, 동시성/멱등성, 데이터 무결성, 오류 처리, 의존성/공급망, 아키텍처/표류. 한 번에 뭉뚱그려 보지 않습니다.
3. **재현 먼저** — 재현(실패하는 테스트·스크립트·요청 순서)이 없는 지적은 "미검증"으로 분류하고, 코드 수정에 쓰지 않습니다.
4. **수정 루프** — 확정된 지적만, 한 번에 하나씩, 최소 수정. 매 수정마다 재현과 게이트를 재실행. 시도 횟수 상한(지적당 3회, 전체 2회전)을 넘기면 멈추고 보고합니다. 테스트를 약하게 만들어 통과시키는 행위는 금지됩니다.
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

### 방법 B — Claude Code 플러그인으로

이 폴더 자체가 플러그인입니다(`.claude-plugin/plugin.json` 포함).

```
# Claude Code에서, 이 폴더가 있는 위치를 로컬 마켓플레이스로 추가
/plugin marketplace add /path/to/review-loop
/plugin install review-loop@review-loop-local
```

### 방법 C — 전역(모든 프로젝트) 설치

`skills/review-loop` 폴더를 아래 위치에 복사하면 전 프로젝트에서 쓸 수 있습니다.

- Claude Code: `~/.claude/skills/review-loop/`
- Cursor: `~/.cursor/skills/review-loop/` (또는 `~/.agents/skills/review-loop/`)

참고: Cursor는 `.claude/skills/` 폴더의 스킬도 호환 로드하므로, 한쪽만 설치해도 다른 쪽에서 보일 수 있습니다. 다만 룰(`.mdc`)은 Cursor 전용입니다.

## 사용법

Claude Code / Cursor Agent 채팅에서:

```
/review-loop                      # 현재 diff + 마지막 커밋을 기본 범위로 리뷰
/review-loop main..feature/pay    # 브랜치 범위 지정
/review-loop src/orders public    # 경로 + 위험 등급 지정
```

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

- 이 스킬은 절차를 강제하지만, 실행하지 않은 검사를 통과로 만들지는
  못합니다. 도구가 없는 환경에서는 그만큼 SKIPPED가 늘어납니다.
- 서로 다른 모델끼리의 교차 점검도 공통 사각지대를 완전히 없애지는
  못합니다. 그래서 이 스킬은 교차 점검보다 기계 게이트와 재현을
  먼저 둡니다.
- 결제·의료·개인정보처럼 실패 비용이 큰 서비스는, 이 스킬의 통과
  판정과 별개로 사람 전문가의 감사가 필요합니다.

## 근거

설계 배경(바이브 코딩의 보안 실패율, 신뢰 보정, Flow-Debt tradeoff,
기술부채, ACID와 멱등성 등)은 이 패키지가 만들어진 대화의 정리 내용을
따릅니다. 대표 출처: Veracode GenAI Code Security Report (2025),
Perry et al., ACM CCS 2023, GitClear (2024), DORA (2024/2025),
Waseem et al., Vibe Coding in Practice (2025),
Duran, HHAI-WS 2025.
