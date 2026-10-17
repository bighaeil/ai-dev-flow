# devflow/ — 기록 구조와 양식

프로젝트마다 `devflow/<project>/` 폴더 하나. 플로우의 모든 산출물과 게이트 기록이 여기에 쌓이고, 코드는 여기 두지 않는다. 양식의 정본은 `docs/ai-dev-flow.md` §4~§6이고 빈 틀은 `_template/`.

```
devflow/
  current.json                 ← 2단계 설계가 쓴다 {project, src_paths[], tests_path[], contract_tests_path[], docs_dir}
                                  3~5단계 에이전트의 경로 훅이 이 파일을 읽는다. 없으면 전부 차단.
  _template/                   ← 01-goal.md · 02-design.md · criteria.yaml · current.json 빈 틀
  _audit/                      ← SubagentStop 훅이 적는 전사 감사 로그(<role>.log) — 커밋하지 않아도 된다
  <project>/
    01-goal.md                 1단계 기획(목적 문장·범위·성공 기준·지킬 선·미정)
    plan-review.md             plan-reviewer 판정(verdict PASS|FAIL, 항목별 ✓/✗, 근거)
    02-design.md               2단계 설계(§0 현행 기록·§①~§⑦). 고칠 땐 지우지 않고 N차로 덧붙이고 amended·변경 이력에 적는다
    criteria.yaml              성공 기준 → 검사 항목(kind test|contract|eval|ops · where · measure)
    design-review.md           design-reviewer 최신 판정 · design-review-roundN.md 사본은 호출자가 복사
    review.md                  code-reviewer 최신 판정 · review-<묶음>-roundN.md 사본은 호출자가 복사
    tests-<folder>.sha256      3단계 끝에 찍는 테스트 지문(tests-unchanged.sh snapshot)
    gates/                     게이트 기록 — <KST일시>_<stage>_<gate>_<verdict>.md (record.sh 가 만든다, 손으로 쓰지 않는다)
    labelset/ eval-report.md   6단계 정답셋·측정 보고
    inputs/                    핸드오프·측정 메모(세션이 쓴 입력)
    ops/                       7단계 로그(contract-daily.log)
```

## 게이트 기록 한 건의 꼴

```
---
project: <project>
stage: 3-tests            # 0-prep 1-plan 2-design 3-tests 4-impl 5-review 6-eval 7-ops
gate: test-red            # human-approval plan-review design-review test-red test-green tests-unchanged code-review eval ops-check …
verdict: pass             # pass fail approved rejected
at: <KST 일시>
by: script:test-red.sh    # human:<이름> | agent:<에이전트> | script:<스크립트> | session:<id>
---

## 근거
<스크립트 출력 또는 대표 문구 그대로>
```

사람 승인도 같은 꼴로, 대표의 문구를 그대로 `--evidence`에 넣는다. 실패 기록은 지우지 않는다 — "왜 두 번째가 필요했나"의 증거다.

## criteria.yaml 의 kind

| kind | 뜻 | 언제 통과해야 하나 |
| --- | --- | --- |
| test | 새 동작 | 3단계엔 전부 실패(red), 4단계 뒤 전부 통과 |
| contract | 현행 고정·경계 계약(설계 §0에서) | 3단계부터 통과, 7단계 매일 재실행 |
| eval | 6단계 측정 스크립트 | 측정 결과를 eval-report에 기록, 판정은 대표 |
| ops | 7단계 운영 점검 | 배포 뒤·주기적으로 확인 |

성공 기준 하나마다 검사 항목이 하나 이상 있어야 설계 리뷰를 통과한다. 검사 항목 없는 성공 기준은 FAIL.
