#!/usr/bin/env bash
# 7단계 운영 — 계약·고정 테스트 매일 실행(LLM 0). 예약 실행기(launchd 등)가 매일 정해진 시각에 부른다(신선도 계약이 있으면 그 계약이 검사하는 시간대에).
# 한다: devflow/current.json 의 tests_path 폴더마다 scripts/gates/test-green.sh 를 돌리고
#       devflow/<project>/ops/contract-daily.log 에 하루 한 줄(날짜 · 폴더별 결과)을 덧붙인다. <project> = current.json 의 project.
#       하나라도 FAIL 이면 scripts/gates/record.sh --stage 7-ops --gate contract-daily --verdict fail 로 게이트 기록(근거 = 실패 출력).
#       PASS 는 로그 줄만(게이트 폴더를 매일 불리지 않는다). 발송 0 · DB 쓰기 0(계약 테스트는 운영 DB 읽기만).
# 수동: scripts/ops/contract_daily.sh   · 마지막 출력: logs/<project>_contract_last.txt
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT" || exit 2
PROJECT="$(python3 -c 'import json;print(json.load(open("devflow/current.json"))["project"])')"
PATHS="$(python3 -c 'import json;print("\n".join(json.load(open("devflow/current.json"))["tests_path"]))')"
LOG="devflow/$PROJECT/ops/contract-daily.log"; LAST="logs/${PROJECT}_contract_last.txt"
mkdir -p "$(dirname "$LOG")" logs
NOW="$(date '+%Y-%m-%dT%H:%M%z')"
: > "$LAST"
line="$NOW"; fail=0
while IFS= read -r p; do
  [ -n "$p" ] || continue
  out="$(scripts/gates/test-green.sh "$p" 2>&1)"; rc=$?
  printf '== %s (rc=%s)\n%s\n' "$p" "$rc" "$out" >> "$LAST"
  summary="$(printf '%s' "$out" | grep -oE 'collected=[0-9]+ passed=[0-9]+ failed=[0-9]+ errors=[0-9]+ skipped=[0-9]+' | tail -1)"
  [ "$rc" -eq 0 ] && verdict="PASS" || { verdict="FAIL"; fail=1; }
  line="$line | $p $verdict ${summary:-no-summary}"
done <<< "$PATHS"
echo "$line" >> "$LOG"
echo "$line"
if [ "$fail" -ne 0 ]; then
  # 실패 상세(FAILED 줄·오류 요약)만 근거로 — 접속 문자열 등 비밀이 들어가지 않게 pytest 요약 줄만 뽑는다
  grep -E '^== |^FAIL|^PASS|FAILED|ERROR|Error' "$LAST" | head -60 > "$LAST.evidence"
  scripts/gates/record.sh --project "$PROJECT" --stage 7-ops --gate contract-daily --verdict fail --by script:contract_daily.sh --evidence-file "$LAST.evidence" >/dev/null
  exit 1
fi
exit 0
