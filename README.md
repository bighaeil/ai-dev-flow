# ai-dev-flow — AI 에이전트 7단계 개발 플로우

요청을 **기획 → 설계 → 테스트 작성 → 구현 → 리뷰 → 검증 → 운영** 일곱 단계로 나누고, 만드는 에이전트와 검사하는 에이전트를 분리하며, 단계를 넘어갈 때마다 게이트 통과 기록을 파일로 남긴다. 목적은 "AI가 만든 것이 맞는지 틀린지를 말할 근거"를 파일로 갖는 것이다. 2026-10-14 trading-system-main 저장소에서 만들어 첫 프로젝트(ant-bot)에 적용한 것을 프로젝트 내용 없이 옮겼다.

| 단계 | 만드는 쪽 | 검사하는 쪽 | 사람 |
| --- | --- | --- | --- |
| 1 기획 | planner | plan-reviewer(체크리스트 6) | **승인** |
| 2 설계 | designer | design-reviewer(추적표 7) | **승인** + 미정 항목 결정 |
| 3 테스트 작성 | test-writer(소스 읽기 차단·Bash 없음) | `test-red.sh`(전부 실패) · 계약은 `test-green.sh` · `tests-unchanged.sh snapshot` | — |
| 4 구현 | implementer(테스트·설계 쓰기 차단) | `test-green.sh` · `tests-unchanged.sh check` · `transcript-audit.py` | — |
| 5 리뷰 | — | code-reviewer(설계 ↔ 코드 ↔ 테스트 줄 번호 대조) | — |
| 6 검증 | 측정 스크립트(운영 DB 읽기만) | — | **판정** |
| 7 운영 | 배포 절차 · `contract_daily.sh` 매일 | — | 배포 지시 |

정본은 [docs/ai-dev-flow.md](docs/ai-dev-flow.md). 첫 적용에서 배운 것(분리가 잡은 11건, 왕복 원인, 사람의 자리, 플로우가 플로우를 고친 이력)은 [docs/case-ant-bot-2026-10.md](docs/case-ant-bot-2026-10.md).

## 구성

```
.claude/agents/      에이전트 7개 — 역할·읽기 허용 범위·금지·훅(PreToolUse 경로 가드, SubagentStop 전사 감사)
scripts/gates/       게이트 — test-red.sh · test-green.sh · tests-unchanged.sh · record.sh · hook-path-guard.sh(+.py) · transcript-audit.py · selftest.sh
scripts/ops/         contract_daily.sh — current.json 의 tests_path 를 매일 test-green 으로(예약 실행기에 건다)
devflow/README.md    기록 구조·양식(current.json · criteria.yaml · 게이트 파일)
devflow/_template/   01-goal.md · 02-design.md · criteria.yaml · current.json 빈 틀
devflow/<project>/   프로젝트마다 하나 — 기획·설계·리뷰·게이트·측정 기록이 쌓이는 곳
docs/                플로우 정본 · 첫 적용 사례
```

## 새 프로젝트에 적용하는 순서

1. 이 저장소의 `.claude/agents/`·`scripts/gates/`·`scripts/ops/`·`devflow/_template/`을 대상 저장소 루트에 복사한다. 훅이 `$CLAUDE_PROJECT_DIR` 기준으로 `scripts/gates/hook-path-guard.sh`를 부르므로 **대상 저장소 루트에서 세션을 연다.**
2. `scripts/gates/selftest.sh`를 한 번 돌려 게이트가 그 환경에서 서는지 본다.
3. `devflow/<project>/`를 만들고 `_template/`을 복사한다. `devflow/current.json`은 2단계 설계가 쓴다 — **그 파일이 없으면 3단계 이후 에이전트의 훅이 전부 차단**하므로 순서가 강제된다.
4. 1단계: 핸드오프(대표의 요청·범위·지킬 선 초안)를 주고 `planner`를 부른다 → `plan-reviewer` → PASS면 대표 승인을 `record.sh --stage 1-plan --gate human-approval`로 기록(문구 그대로).
5. 2단계: `designer` → `design-reviewer` → 대표 승인(+ 미정 항목 결정). 기존 모듈이 있으면 §0 현행 기록과 계약 테스트부터.
6. 3~5단계는 사람 승인 없이 게이트만으로 진행한다. 단계마다 `record.sh`로 기록.
7. 6단계 측정 → 대표 판정. 7단계 배포(대표 지시) → `contract_daily.sh`를 예약 실행기에 건다.

에이전트는 범용이다. 프로젝트 고유 지식은 전부 `devflow/<project>/` 아래 파일과 호출 때의 지시문에 둔다. 운영 DB 읽기 전용 조회 도구가 있으면 `designer.md`의 `tools:`에 추가한다(쓰기 도구는 넣지 않는다).

## 이 저장소에 대해

개인이 자기 프로젝트에서 쓰려고 만든 작업 방식의 기록이다. 범용으로 쓸 수 있게 프로젝트 내용은 빼고 옮겼지만, 검증된 적용은 첫 프로젝트 하나(2026-10-14~17, `docs/case-ant-bot-2026-10.md`)뿐이다. 에이전트 정의는 Claude Code의 서브에이전트·훅 기능을 전제한다. 라이선스는 MIT(`LICENSE`).

## 지킬 것 세 가지

- 같은 에이전트가 만들고 검사하지 않는다. 테스트 작성자는 소스를 못 읽고, 구현자는 테스트를 못 고친다.
- 3·4·5단계 에이전트는 성공 기준과 설계를 바꾸지 못한다. 틀렸다고 보면 멈추고 보고한다("1단계로 되돌림" 표시).
- 측정하지 않은 수치를 적지 않는다. 결과를 본 뒤 기준을 바꾸면 그 사실과 이유를 기록하고, 새 표본으로만 판정한다.
