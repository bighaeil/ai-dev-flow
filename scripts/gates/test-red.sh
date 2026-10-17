#!/usr/bin/env bash
# 게이트 3단계 — 구현 전 "전부 실패(red)" 확인.
# 사용: scripts/gates/test-red.sh <tests_path> [추가 pytest 인자...]
# 판정: 수집된 테스트 ≥1 이고 통과(passed) 0 이면 PASS(전부 red). 하나라도 통과하면 FAIL.
#       수집 에러(아직 없는 모듈 import 등)는 red로 세되 경고를 남긴다 — 4단계 green에서 다시 걸러진다.
# 종료 코드: 0 = PASS(전부 red) · 1 = FAIL · 2 = 사용법/실행 오류
set -u
if [ $# -lt 1 ]; then echo "usage: $0 <tests_path> [pytest args...]" >&2; exit 2; fi
TESTS="$1"; shift
[ -e "$TESTS" ] || { echo "FAIL  tests path not found: $TESTS"; exit 1; }
JUNIT="$(mktemp -t gate-red.XXXXXX).xml"
python3 -m pytest -q --tb=no -p no:cacheprovider --junitxml="$JUNIT" "$TESTS" "$@" >/dev/null 2>&1
PYTEST_RC=$?
read -r TOTAL FAILURES ERRORS SKIPPED <<<"$(python3 - "$JUNIT" <<'PY'
import sys, xml.etree.ElementTree as ET
try:
    root = ET.parse(sys.argv[1]).getroot()
except Exception:
    print("0 0 0 0"); sys.exit()
suites = [root] if root.tag == "testsuite" else root.findall("testsuite")
t=f=e=s=0
for su in suites:
    t+=int(su.get("tests",0)); f+=int(su.get("failures",0)); e+=int(su.get("errors",0)); s+=int(su.get("skipped",0))
print(t,f,e,s)
PY
)"
rm -f "$JUNIT"
PASSED=$(( TOTAL - FAILURES - ERRORS - SKIPPED ))
SUMMARY="collected=$TOTAL passed=$PASSED failed=$FAILURES errors=$ERRORS skipped=$SKIPPED pytest_rc=$PYTEST_RC path=$TESTS"
if [ "$TOTAL" -eq 0 ]; then echo "FAIL  no tests collected (or pytest could not run). $SUMMARY"; exit 1; fi
if [ "$PASSED" -gt 0 ]; then echo "FAIL  $PASSED test(s) already pass before implementation — they may test nothing. $SUMMARY"; exit 1; fi
if [ "$SKIPPED" -gt 0 ]; then echo "FAIL  $SKIPPED skipped test(s) — a skipped test is not red. $SUMMARY"; exit 1; fi
[ "$ERRORS" -gt 0 ] && echo "WARN  $ERRORS collection/run error(s) counted as red — confirm they are 'module not yet implemented', not broken test files."
echo "PASS  all red. $SUMMARY"; exit 0
