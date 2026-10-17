#!/usr/bin/env bash
# 게이트 자가 시험 — 임시 git 저장소에 샘플 테스트 하나를 두고 각 게이트가 실패·통과 양쪽 판정을 실제로 내는지 확인한다.
# 사용: scripts/gates/selftest.sh   (종료 코드 0 = 6개 기대 전부 일치)
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
TMP="$(mktemp -d -t gate-selftest.XXXXXX)"; trap 'rm -rf "$TMP"' EXIT
cd "$TMP" && git init -q . && git -c user.email=g@t -c user.name=gate commit -q --allow-empty -m init
mkdir -p tests src && touch src/__init__.py
cat > tests/test_sample.py <<'PY'
from src.calc import add
def test_add(): assert add(2, 3) == 5
def test_add_zero(): assert add(0, 0) == 0
PY
ok=0; bad=0
expect() { # expect <설명> <기대 rc> <명령...>
  local desc="$1" want="$2"; shift 2; local out; out="$("$@" 2>&1)"; local rc=$?
  if [ "$rc" -eq "$want" ]; then ok=$((ok+1)); printf '  ok   %-44s rc=%s  %s\n' "$desc" "$rc" "$(echo "$out" | head -1)"
  else bad=$((bad+1)); printf '  BAD  %-44s rc=%s (want %s)\n%s\n' "$desc" "$rc" "$want" "$out"; fi
}
echo "[test-red]"
expect "구현 전(src.calc 없음) → PASS(red)" 0 "$HERE/test-red.sh" tests
printf 'def add(a, b):\n    return None\n' > src/calc.py
expect "틀린 구현(단언 전부 실패) → PASS(red, 경고 없음)" 0 "$HERE/test-red.sh" tests
printf 'def add(a, b):\n    return a + b\n' > src/calc.py
expect "구현 후(전부 통과) → FAIL(red 아님)" 1 "$HERE/test-red.sh" tests
rm -rf tests_empty && mkdir tests_empty
expect "테스트 0개 → FAIL" 1 "$HERE/test-red.sh" tests_empty
echo "[test-green / contract 분리]"
mkdir -p tests/contract && cat > tests/contract/test_asis.py <<'PY2'
def test_current_behaviour_is_fixed(): assert 1 + 1 == 2
PY2
expect "계약 테스트(현행 고정) → PASS(green)" 0 "$HERE/test-green.sh" tests/contract
expect "구현 뒤 전체 → PASS(green)" 0 "$HERE/test-green.sh" tests
printf 'def add(a, b):\n    return None\n' > src/calc.py
expect "미구현 상태 전체 → FAIL(green 아님)" 1 "$HERE/test-green.sh" tests
expect "red 게이트에 contract 포함 → FAIL(통과 테스트 섞임)" 1 "$HERE/test-red.sh" tests
expect "red 게이트에 --ignore=contract → PASS(red)" 0 "$HERE/test-red.sh" tests --ignore=tests/contract
printf 'def add(a, b):\n    return a + b\n' > src/calc.py
echo "[tests-unchanged]"
expect "snapshot 저장" 0 "$HERE/tests-unchanged.sh" snapshot tests "$TMP/tests.sha256"
git add -A && git -c user.email=g@t -c user.name=gate commit -q -m "tests frozen" && git tag frozen
expect "변경 없음(snapshot) → PASS" 0 "$HERE/tests-unchanged.sh" check tests "$TMP/tests.sha256"
expect "변경 없음(git ref) → PASS" 0 "$HERE/tests-unchanged.sh" check tests frozen
echo "def test_sneaky(): assert True" >> tests/test_sample.py
expect "테스트 수정 뒤(snapshot) → FAIL" 1 "$HERE/tests-unchanged.sh" check tests "$TMP/tests.sha256"
expect "테스트 수정 뒤(git ref) → FAIL" 1 "$HERE/tests-unchanged.sh" check tests frozen
echo "[record]"
expect "기록 파일 생성" 0 "$HERE/record.sh" --root "$TMP/devflow" --project sample --stage 3-tests --gate test-red --verdict pass --by script:selftest --evidence "자가 시험"
expect "잘못된 stage → 거부" 2 "$HERE/record.sh" --root "$TMP/devflow" --project sample --stage 9-x --gate test-red --verdict pass --by script:selftest --evidence x
echo; echo "selftest: ok=$ok bad=$bad"; [ "$bad" -eq 0 ]
