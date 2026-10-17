#!/usr/bin/env bash
# 게이트 기록 — 단계·일시·판정·근거를 devflow/<project>/gates/ 에 한 파일로 남긴다. 사람 승인도 같은 형식.
# 사용: scripts/gates/record.sh --project P --stage S --gate G --verdict V --by B (--evidence "문장" | --evidence-file F) [--root DIR]
#   stage  : 0-prep 1-plan 2-design 3-tests 4-impl 5-review 6-eval 7-ops
#   gate   : human-approval plan-review design-review test-red test-green tests-unchanged code-review eval ops-check
#   verdict: pass fail approved rejected
#   by     : human:<이름> | agent:<에이전트명> | script:<스크립트명> | session:<id>
# 파일명: <KST 일시>_<stage>_<gate>_<verdict>.md  (분 단위, 같은 분에 두 번이면 -2, -3 …)
set -eu
PROJECT=""; STAGE=""; GATE=""; VERDICT=""; BY=""; EVIDENCE=""; EVIDENCE_FILE=""; ROOT="devflow"
while [ $# -gt 0 ]; do
  case "$1" in
    --project) PROJECT="$2"; shift 2;; --stage) STAGE="$2"; shift 2;; --gate) GATE="$2"; shift 2;;
    --verdict) VERDICT="$2"; shift 2;; --by) BY="$2"; shift 2;; --evidence) EVIDENCE="$2"; shift 2;;
    --evidence-file) EVIDENCE_FILE="$2"; shift 2;; --root) ROOT="$2"; shift 2;;
    *) echo "unknown arg: $1" >&2; exit 2;;
  esac
done
for v in PROJECT STAGE GATE VERDICT BY; do [ -n "${!v}" ] || { echo "missing --$(echo $v | tr A-Z a-z)" >&2; exit 2; }; done
case "$STAGE" in 0-prep|1-plan|2-design|3-tests|4-impl|5-review|6-eval|7-ops) ;; *) echo "bad --stage $STAGE" >&2; exit 2;; esac
case "$VERDICT" in pass|fail|approved|rejected) ;; *) echo "bad --verdict $VERDICT" >&2; exit 2;; esac
case "$BY" in human:*|agent:*|script:*|session:*) ;; *) echo "bad --by $BY (human:|agent:|script:|session:)" >&2; exit 2;; esac
[ -n "$EVIDENCE" ] || [ -n "$EVIDENCE_FILE" ] || { echo "need --evidence or --evidence-file" >&2; exit 2; }
DIR="$ROOT/$PROJECT/gates"; mkdir -p "$DIR"
AT=$(TZ=Asia/Seoul date +%Y-%m-%dT%H:%M%z | sed 's/\(..\)$/:\1/')
STAMP=$(TZ=Asia/Seoul date +%Y%m%d-%H%M)
BASE="$DIR/${STAMP}_${STAGE}_${GATE}_${VERDICT}"; FILE="$BASE.md"; n=2
while [ -e "$FILE" ]; do FILE="$BASE-$n.md"; n=$((n+1)); done
{
  printf -- '---\nproject: %s\nstage: %s\ngate: %s\nverdict: %s\nat: %s\nby: %s\n---\n\n## 근거\n\n' "$PROJECT" "$STAGE" "$GATE" "$VERDICT" "$AT" "$BY"
  if [ -n "$EVIDENCE_FILE" ]; then printf '```\n'; cat "$EVIDENCE_FILE"; printf '\n```\n'; fi
  [ -n "$EVIDENCE" ] && printf '%s\n' "$EVIDENCE"
} > "$FILE"
echo "RECORDED  $FILE"
