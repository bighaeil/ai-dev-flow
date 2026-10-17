# AI 개발 플로우 (정본) — 7단계, 에이전트 7개, 게이트

> 요청을 기획·설계·테스트 작성·구현·리뷰·검증·운영 일곱 단계로 나누고, 만드는 에이전트와 검사하는 에이전트를 분리하며, 단계마다 게이트 통과 기록을 파일로 남기는 개발 방식. 2026-10-14 trading-system-main 저장소에서 만들어 첫 프로젝트(ant-bot, 뉴스 정형화)에 적용한 것을 2026-10-18 프로젝트 내용 없이 이 저장소로 옮겼다. 첫 적용에서 배운 것은 `docs/case-ant-bot-2026-10.md`.
> 이 문서가 플로우의 정본이다. 에이전트 정의는 `.claude/agents/`, 게이트 스크립트는 `scripts/gates/`, 기록 구조는 `devflow/`(양식 = `devflow/README.md`).

## 0. 왜 플로우부터인가
지금까지는 AI에게 만들게만 하고 검증은 하지 않았다. 결과물이 얼마나 정확한지 설명할 근거가 없었다. 이번에는 단계마다 **만드는 주체와 검증하는 주체를 분리**하고, 산출물과 **게이트 통과 기록을 파일로** 남긴 뒤 개발을 시작한다. 그 기록이 "어떻게 검증했는가"의 증거다. 이 저장소의 협업 원칙(CLAUDE.md "구현 전 검증·구현 후 확인·진행 전 승인")을 단계와 파일로 구체화한 것이기도 하다.


## 2. 7단계
| 단계 | 만듦 | 검증 | 산출물(`devflow/<project>/`) | 게이트(통과 조건) | 기록 |
|---|---|---|---|---|---|
| 1. 기획 | `planner` | `plan-reviewer`(체크리스트 6) | `01-goal.md` · `plan-review.md` | **대표 승인** | `record.sh --stage 1-plan --gate plan-review` + `--gate human-approval` |
| 2. 설계 | `designer` | `design-reviewer`(추적표) | `02-design.md` · `criteria.yaml` · `design-review.md` · `devflow/current.json` | **대표 승인** | `--stage 2-design` 같은 두 기록 |
| 3. 테스트 작성 | `test-writer` | 코드: `test-red.sh` — 새 동작 테스트 전부 실패 · `test-green.sh` — 현행 고정·계약 테스트 전부 통과 | `<tests_path>/…` · `<contract_tests_path>/…` | 자동(새 = 전부 red · 계약 = 전부 green) | `--stage 3-tests --gate test-red` · `--gate test-green` + `tests-unchanged.sh snapshot` |
| 4. 구현 | `implementer` | 코드: `test-green.sh <tests_path>`(계약 포함 전부 통과) + `tests-unchanged.sh check` + `transcript-audit.py` | `<src_paths>/…` | 자동(green · tests 불변 · 감사 PASS) | `--stage 4-impl --gate test-green` · `--gate tests-unchanged` |
| 5. 리뷰 | 없음 | `code-reviewer`(구현 과정 모름) | `review.md` | 지적 사항 해소(→4단계 반복) | `--stage 5-review --gate code-review` |
| 6. 검증 | 평가 스크립트(`criteria.yaml` kind: eval) | 정답셋 정확도 · 재실행 일치율 · 사이트↔DB 대조 | `eval-report.md` | **대표 판정** | `--stage 6-eval --gate eval` + `human-approval` |
| 7. 운영 | 자동 점검(kind: ops) | 매일 갱신·일치·발행 점검, 주간 지표 | 운영 기록 | 3개월 뒤 최종 판정 | `--stage 7-ops --gate ops-check` |

핵심 셋. ① 만드는 에이전트와 검증하는 에이전트를 **분리**한다 — 같은 에이전트가 만들고 채점하면 검증이 아니다. ② **코드로 판정할 수 있는 것(3·4)은 코드로**, LLM 판단이 필요한 곳(1·2·5)은 별도 에이전트가 체크리스트·추적표로. ③ 사람은 **1·2단계 승인과 6단계 판정, 세 지점만** 맡는다. CLAUDE.md 협업 원칙 6("진행 전 반드시 승인")은 이 세 지점으로 구체화된다 — 3~5단계는 게이트가 통과시키고 사람은 기록만 본다.

## 3. 왜 이 순서인가
- **테스트 작성이 구현보다 앞선다.** 구현을 먼저 하면 AI가 만든 코드에 맞춰 테스트를 쓰게 되어, 테스트가 "코드가 하는 일"만 확인하고 "코드가 해야 할 일"은 확인하지 못한다. 테스트를 먼저 쓰면 기준이 설계 문서에서 나온다. 구현 전에 **전부 실패하는지** 보는 이유는, 처음부터 통과하는 테스트는 아무것도 검사하지 않을 수 있기 때문이다. 같은 이유로 `test-writer` 는 src 를 읽지 못하고, `implementer` 는 tests 를 고치지 못한다.
- **리뷰와 검증을 나눈다.** 리뷰는 코드를 설계와 비교해 테스트가 놓친 것을 찾고, 검증은 완성된 제품을 실데이터로 돌려 목적을 달성했는지 본다. 테스트와 리뷰를 다 통과해도 중복 판정 정확도가 낮으면 제품은 목적을 이루지 못한다. 리뷰를 먼저 하는 이유는 검증이 무겁고, 리뷰에서 코드가 바뀌면 검증을 다시 해야 하기 때문이다.
- **기획과 설계를 나누고 둘 다 사람이 승인한다.** 성공 기준(기획)이 흔들리면 그 아래 전부가 흔들린다. 설계 리뷰의 추적표는 "모든 성공 기준이 검사 항목 ≥1 에 연결됐는가"만 보는데, 그게 6단계에서 "증명했다"고 말할 수 있는 최소 조건이다.

- **기존 코드는 "현행 고정"부터 시작한다.** 이미 돌아가는 모듈은 기획·설계·테스트 기록이 없다("구현만 되어 있다"). 그래서 2단계 설계가 §0 에 **현행 동작 표와 경계 계약**(상류 입력의 스키마·신선도, 하류 소비자가 기대하는 형식)을 적고, 3단계가 그 표만 보고 **현행 고정·계약 테스트**를 쓴다. 이 테스트는 지금 코드에 대해 처음부터 통과해야 한다 — 통과하지 못하면 표가 코드를 잘못 적은 것이고 설계로 되돌아간다(설계 기록 자체가 검증된다). 그 위에 바꿀 동작의 테스트는 red 로 쓴다. 구현 뒤엔 둘 다 통과해야 하므로 "바꾸지 않기로 한 것"이 지켜졌다는 증거가 남고, 계약 테스트는 7단계에서 매일 돌아 상류가 바뀌면 먼저 깨진다. test-writer 가 코드를 못 읽는 규칙은 그대로다 — 현행도 설계 표를 통해서만 본다.

## 4. 디렉터리 구조
```
docs/ai-dev-flow.md                 ← 이 문서(정본)
.claude/agents/                     ← 단계 에이전트 7개(planner plan-reviewer designer design-reviewer test-writer implementer code-reviewer)
scripts/gates/
  test-red.sh                       ← 3단계 게이트: 새 동작 테스트 구현 전 전부 실패(--ignore=<contract_tests_path>)
  test-green.sh                     ← 3단계 계약 테스트 전부 통과 · 4단계 전체 전부 통과
  tests-unchanged.sh                ← 4단계 게이트: tests 불변(snapshot | git ref)
  record.sh                         ← 게이트·승인 기록 쓰기(§5 형식)
  hook-path-guard.sh + hook_path_guard.py   ← 에이전트 전용 PreToolUse 훅(역할별 금지 경로 차단)
  transcript-audit.py               ← 서브에이전트 전사 사후 감사(훅이 못 막는 Bash 경로)
  selftest.sh                       ← 게이트 자가 시험(샘플 테스트 1개로 실패·통과 양쪽 확인)
devflow/
  current.json                      ← 2단계 설계가 쓴다 {project, src_paths[], tests_path, contract_tests_path, docs_dir} — 3~5단계 훅의 기준
  current.json.example
  _audit/<role>.log                 ← SubagentStop 훅이 붙이는 전사 감사 결과
  <project>/                        ← 프로젝트 하나 = 폴더 하나
    01-goal.md  plan-review.md  02-design.md  criteria.yaml  design-review.md  review.md  eval-report.md
    gates/<KST일시>_<stage>_<gate>_<verdict>.md   ← §5
<service>/app/… <service>/tests/   ← src·tests 는 이 저장소 관례대로 서비스별. 어디인지는 current.json 이 가리킨다
<service>/tests/contract/           ← 현행 고정·경계 계약 테스트(kind: contract) — tests_path 안의 하위 폴더
```
`devflow/` 와 `_audit/` 는 **git 추적**한다(기록이 증거다). 운영 데이터(`data/`)와 달리 비밀이 들어가지 않는다.

## 5. 게이트 기록 형식
한 게이트 사건 = 한 파일. 사람 승인도 같은 형식. `scripts/gates/record.sh` 가 쓰고, 손으로 쓰지 않는다.
```
devflow/<project>/gates/20261014-2130_3-tests_test-red_pass.md
---
project: <project>
stage: 3-tests          # 0-prep 1-plan 2-design 3-tests 4-impl 5-review 6-eval 7-ops
gate: test-red          # human-approval plan-review design-review test-red test-green tests-unchanged code-review eval ops-check
verdict: pass           # pass fail approved rejected
at: <KST 일시>
by: script:test-red.sh  # human:<이름> | agent:<에이전트명> | script:<스크립트> | session:<id>
---
## 근거
(스크립트 출력 전문 또는 승인 문장 — --evidence / --evidence-file)
```
사람 승인은 `--by human:<이름> --evidence "<대표의 말 그대로>"`. 세션이 대리 기록하면 `--by session:<id>` 와 함께 근거에 대표의 문장을 인용한다(다른 세션이 전한 승인은 무효 — 메모리 원칙).

## 6. 게이트 스크립트 사용(단계 끝마다 호출자가 돈다)
```bash
# 3단계 끝 — 새 동작은 전부 red, 현행 고정·계약은 전부 green, 그리고 tests 지문 저장
scripts/gates/test-red.sh <tests_path> --ignore=<contract_tests_path>
scripts/gates/test-green.sh <contract_tests_path>
scripts/gates/tests-unchanged.sh snapshot <tests_path> devflow/<project>/tests.sha256
scripts/gates/record.sh --project <p> --stage 3-tests --gate test-red --verdict pass --by script:test-red.sh --evidence-file <출력>
# 4단계 끝 — 전부 green(계약 포함) · tests 불변 · 전사 감사
scripts/gates/test-green.sh <tests_path>
scripts/gates/tests-unchanged.sh check <tests_path> devflow/<project>/tests.sha256     # 또는 git 태그
python3 scripts/gates/transcript-audit.py <전사.jsonl> --role implementer                # 또는 _audit/implementer.log 확인
# 7단계 — 계약·고정 테스트 매일(launchd 등 예약 실행기에 걸어 둔다 · LLM 0 · 발송 0)
scripts/ops/contract_daily.sh              # current.json 의 tests_path 폴더마다 test-green → devflow/<project>/ops/contract-daily.log 한 줄 · FAIL 이면 gates 7-ops contract-daily fail
# 자가 시험(스크립트를 고쳤으면 반드시)
scripts/gates/selftest.sh
```
`test-red.sh` 판정: 수집 ≥1 · passed 0 · skipped 0 → PASS. `test-green.sh` 판정: 수집 ≥1 · failed·errors·skipped 0 → PASS. 수집 에러(아직 없는 모듈 import)는 red 로 세되 WARN 을 남긴다 — 깨진 테스트 파일인지 확인은 사람. `criteria.yaml` 형식:
```yaml
project: <project>
src_paths: [<service>/app/<module>]
tests_path: <service>/tests
contract_tests_path: <service>/tests/contract
criteria:
  - id: C1
    goal_ref: "01-goal.md §성공 기준 — 사이트 갱신률"
    statement: "영업일 갱신률 95% 이상"
    checks:
      - {id: C1-E1, kind: eval, where: scripts/eval/<name>.py, measure: "영업일 중 갱신된 날 / 영업일"}
      - {id: C1-T1, kind: test, where: "<service>/tests/test_x.py::test_y", measure: "…"}
  - id: C2
    goal_ref: "01-goal.md §범위 — 바꾸지 않을 현행 동작"
    statement: "<산출물> 문서 형식은 소비자 N곳이 읽는 필드를 유지한다"
    checks:
      - {id: C2-K1, kind: contract, where: "<service>/tests/contract/test_<산출물>_schema.py", measure: "필수 필드·타입 존재, 최신 문서 신선도 ≤ N분"}
```
`kind` 넷: `test`(새 동작, 3단계 red) · `contract`(현행 고정·경계 계약, 3단계부터 green, 7단계 매일) · `eval`(6단계) · `ops`(7단계).

### 6.1 계약 테스트가 떨어졌을 때(첫 적용 묶음 1·2 실측으로 굳힌 규칙)
현행 고정·계약 테스트는 **설계 §0 표만 보고** 쓰므로, 떨어지면 거의 언제나 표 쪽이다. 분류 셋: ① **표의 사실 오류**(예: `sp500_daily.date` 는 str 아닌 datetime · B8 "응답 없음 → bad=True" 의 조건 누락) ② **표의 정보 부족**(상수·함수의 소속 모듈·정확한 이름 · 함수 시그니처 · `Context` 같은 객체를 가짜 DB로 만드는 법 · 코드가 쓰는 `find().sort().limit()` 커서 체인 · import 시 환경 요구) ③ **테스트 구현 오류**(표는 맞는데 가짜 컬렉션이 표의 메서드를 안 흉내 냄). ①②는 designer 가 §0 을 고치고 design-reviewer 가 **범위 한정 + 코드 대조**로 다시 판정한 뒤 test-writer 가 표대로 다시 쓴다(코드를 읽어 짐작하지 않는다 — 그래서 묶음 2 는 설계 3왕복이 걸렸다). ③만 test-writer 혼자 고친다. 분류와 왕복은 `gates/` 기록 근거에 적는다. **설계 §0 을 처음 쓸 때 ②를 미리 채우면 왕복이 준다** — 5·6차가 그 체크리스트(소속 모듈·시그니처·커서 체인·mock 자리·import 환경).

pytest 는 **폴더별로** 돈다 — 두 서비스의 contract 폴더에 같은 파일 이름(`test_upstream_contract.py`)이 있어 한 명령에 함께 넣으면 "import file mismatch" 수집 에러(`__init__.py` 없는 관례 때문). 게이트 스크립트는 경로 하나만 받으므로 자연히 지켜진다.

### 6.3 코드 리뷰(5단계)가 잡는 것 — 첫 적용 묶음 3 실측
테스트 전부 green 인 구현을 리뷰가 세 번 돌려보냈다. 1차 5건: 경계값 미구현(E-20 — 설계가 CLI 의 DB 접근을 안 적어 테스트 항목도 없었음) · **설계의 측정 방법이 운영 DB 쓰기**(재실행 일치율 "처리기 2회 실행" = 지킬 선 4 위반 — 테스트로는 절대 안 잡히는 종류) · 예외 경로 3(날짜·JSON·파일 없음). 2차 2건: 문서 불일치(§① 읽기 목록) · 새 분기 미테스트. 3차 0. **코드가 먼저 있는 분기에 테스트를 붙이려면 red 가 안 된다** → 그 분기를 순수 함수로 뽑는 설계 보완(함수가 아직 없으니 red) → 구현이 CLI 를 그 함수로 교체. 설계 §③ 을 처음 쓸 때 "CLI 분기도 전부 함수로" 원칙을 두면 왕복이 준다. 리뷰 참고 절(접속 문자열이 오류 문구에 들어갈 수 있음)은 다음 리뷰에서 판정 항목으로 올렸다 — 참고는 한 번만 참고다.

### 6.2 headless(`claude -p --agent`) 실행 규칙(첫 적용 실측)
이 세션은 에이전트가 만들어진 뒤 시작된 것이 아니어서 Agent 도구로 못 부르고 headless 로 돌렸다(27회). 함정 셋: ① 경로 훅 미강제(§7) → 매번 `git status` + `transcript-audit.py` 사후 검사 ② **출력 상한 32k** — 테스트 25개를 한 응답에 몰아 쓰면 실패하고 파일이 0개 남는다(31분 소모) → `CLAUDE_CODE_MAX_OUTPUT_TOKENS=60000` + "Write 한 번 호출하고 결과 받은 뒤 다음 Write" ③ 그 지시를 "파일 하나 쓰고 종료"로 해석해 텍스트로 끝내 버림 → "텍스트 답변으로 실행을 끝내지 마라, 전부 끝난 뒤에만 보고" 를 같이 적는다. 전사는 `~/.claude/projects/<프로젝트>/<세션>.jsonl`(가장 최근 파일, 사람 세션 제외)이고 감사 스크립트가 그걸 읽는다.

## 7. 에이전트 7개와 제약 — 무엇이 강제되고 무엇이 지시인가
공식 문서(code.claude.com/docs — sub-agents·hooks·permissions·cli-reference·headless, 2026-10-14 확인)로 확인한 사실만 적는다. 등급은 셋: **A 설정으로 강제** · **B 설정으로 강제(조건부)** · **C 지시 + 사후 검사**.

확인된 사실:
- 서브에이전트 frontmatter `tools:`(허용 목록)·`disallowedTools:` 는 도구 자체를 빼므로 **강제**된다. 단 `Bash(git push *)` 처럼 지정자를 붙여도 도구 전체가 빠진다(부분 제한 불가).
- **경로별** 제한은 frontmatter 필드로는 문서화되어 있지 않다. 문서화된 길은 frontmatter `hooks:`(그 에이전트가 활동하는 동안만 도는 PreToolUse 훅, 종료 코드 2 = 차단, 문서의 db-reader 예시)다. 훅 입력 JSON 에 `agent_type`·`agent_id` 가 있고, SubagentStop 은 `agent_transcript_path` 를 준다.
- 훅은 Read·Edit·Write 같은 **파일 도구의 인자**만 본다. Bash 안의 `cat`·`sed -i`·리다이렉션은 훅이 못 막는다(settings 의 deny 규칙은 cat·sed·tee·리다이렉션까지 보지만 세션 전체에 걸리고, `sh -c`·경로 호출·스크립트 내부 파일 열기는 못 본다 — 문서 그대로).
- ★조건: 프로젝트 서브에이전트의 frontmatter 훅은 **작업 폴더 신뢰 대화상자를 수락한 뒤**에만 돈다. headless `claude -p` 는 수락으로 치지 않는다 → **headless 에서는 경로 훅이 강제되지 않는다**(사후 검사만).
- 서브에이전트는 자기 컨텍스트로 시작한다(구조). 호출 프롬프트에 무엇을 넣는지는 호출자 책임(지시).
- 확인 못 한 것: `permissionMode` 가 deny 규칙을 덮는지(문서 없음 — 그래서 어떤 에이전트에도 `permissionMode` 를 쓰지 않는다) · SubagentStop 훅을 서브에이전트 frontmatter 에 둘 때 실제로 그 에이전트 종료에 도는지(문서가 명시하지 않음 — **첫 실행 때 `devflow/_audit/<role>.log` 생성 여부로 확인**, 안 돌면 §6 수동 명령으로 감사).

| 에이전트 | 도구(`tools:`) | 제약 | 등급 | 강제 수단 | 사후 검사 |
|---|---|---|---|---|---|
| planner | Read Glob Grep Write Edit | `devflow/` 밖 쓰기 금지 | B | 훅 `hook-path-guard.sh planner` | `git status` 로 devflow 밖 변경 0 확인 |
| | | 코드·DB 변경 금지 | A | Bash·MCP 쓰기 도구 없음 | — |
| | | 미정 임의 확정·측정 안 한 수치 금지 | C | 지시 | plan-reviewer 체크리스트 4·5 |
| plan-reviewer | Read Glob Grep Write | `plan-review.md` 외 쓰기 금지 | B | 훅 | git status |
| designer | Read Glob Grep Write Edit + MCP mongo 조회 5개 | `devflow/` 밖 쓰기 금지 · 코드 작성 금지 | B | 훅(쓰기 경로) · Bash 없음(A) | git status |
| | | DB 쓰기 금지 | A | MCP 조회 도구만 허용(쓰기 도구 목록에 없음) | — |
| design-reviewer | Read Glob Grep Write | `design-review.md` 외 쓰기 금지 | B | 훅 | git status |
| **test-writer** | Read Glob Grep Write Edit (**Bash 없음**) | **src 읽기 금지** | B | 훅: Read·Grep·Glob 의 경로가 `src_paths` 면 차단, path 없는 Grep·Glob 차단 · Bash 를 아예 빼서 우회 경로 제거(A) | `transcript-audit.py --role test-writer`(SubagentStop 훅 → `_audit/`) |
| | | `tests_path` 밖 쓰기 금지 | B | 훅 | git status |
| | | 처음부터 통과하는 테스트·skip 금지(새 동작) | C | 지시 | **`test-red.sh`**(passed 0·skipped 0) |
| | | 현행 고정·계약 테스트는 표대로만, 떨어지면 보고(수정 금지) | C | 지시 | **`test-green.sh <contract_tests_path>`** — FAIL 이면 설계 §0 으로 되돌림 |
| **implementer** | Read Glob Grep Edit Write **Bash** | **tests 수정 금지**(계약 테스트 포함) | B+C | 훅: Edit·Write 가 `tests_path`·`contract_tests_path` 면 차단 / Bash 경로는 못 막음 | **`tests-unchanged.sh check`** + `transcript-audit.py --role implementer` — FAIL 이면 구현 폐기 |
| | | 설계 문서 수정 금지 | B | 훅(`docs_dir`) | git status |
| | | 테스트 밖 기능 추가·외부 쓰기 금지 | C | 지시 | code-reviewer |
| code-reviewer | Read Glob Grep Write | 코드·테스트 수정 금지 | A+B | Edit·Bash 없음 · 훅: `review.md` 외 쓰기 차단 | git status |
| | | 구현 과정 모름 | 구조+C | 새 컨텍스트(구조) · 호출자가 경위를 넘기지 않음(지시) | 호출 프롬프트를 `gates/` 기록 근거에 그대로 남김 |

공통: 세 역할(test-writer·implementer·code-reviewer)의 훅은 `devflow/current.json` 이 없으면 **전부 차단**한다 — 2단계 설계가 끝나기 전엔 3단계를 시작할 수 없게 순서를 강제한다. 모델은 지정하지 않았다(앱에서 핀, 메모리 원칙).

