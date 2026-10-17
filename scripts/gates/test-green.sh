#!/usr/bin/env bash
# 게이트 — "전부 통과(green)" 확인. 3단계의 현행 고정·계약 테스트(contract_tests_path)와 4단계 구현 뒤 전체 테스트에 쓴다.
# 사용: scripts/gates/test-green.sh <tests_path> [추가 pytest 인자...]
# 판정: 수집 ≥1 이고 failed·errors·skipped 전부 0 이면 PASS. 종료 코드: 0 PASS · 1 FAIL · 2 사용법 오류
set -u
if [ $# -lt 1 ]; then echo "usage: $0 <tests_path> [pytest args...]" >&2; exit 2; fi
TESTS="$1"; shift
[ -e "$TESTS" ] || { echo "FAIL  tests path not found: $TESTS"; exit 1; }
JUNIT="$(mktemp -t gate-green.XXXXXX).xml"
python3 -m pytest -q --tb=short -p no:cacheprovider --junitxml="$JUNIT" "$TESTS" "$@" >/dev/null 2>&1
PYTEST_RC=$?
read -r TOTAL FAILURES ERRORS SKIPPED <<<"$(python3 - "$JUNIT" <<'PY'
import sys, xml.etree.ElementTree as ET
try: root = ET.parse(sys.argv[1]).getroot()
except Exception: print("0 0 0 0"); sys.exit()
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
if [ "$TOTAL" -eq 0 ]; then echo "FAIL  no tests collected. $SUMMARY"; exit 1; fi
if [ "$FAILURES" -gt 0 ] || [ "$ERRORS" -gt 0 ] || [ "$SKIPPED" -gt 0 ]; then echo "FAIL  not all green. $SUMMARY"; exit 1; fi
echo "PASS  all green. $SUMMARY"; exit 0
