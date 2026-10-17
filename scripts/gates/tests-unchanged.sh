#!/usr/bin/env bash
# 게이트 4단계 — 구현 전후로 tests/ 가 바뀌지 않았는지 확인.
# 사용:
#   scripts/gates/tests-unchanged.sh snapshot <tests_path> <snapshot_file>   # 구현 시작 전 지문 저장
#   scripts/gates/tests-unchanged.sh check    <tests_path> <ref_or_snapshot> # 구현 뒤 비교
#     ref_or_snapshot = git 커밋/태그(git diff + 미추적 파일 검사) 또는 snapshot 파일(sha256 비교)
# 종료 코드: 0 = PASS(변경 없음) · 1 = FAIL(변경 있음) · 2 = 사용법/실행 오류
set -u
MODE="${1:-}"; TESTS="${2:-}"; REF="${3:-}"
[ -n "$MODE" ] && [ -n "$TESTS" ] && [ -n "$REF" ] || { echo "usage: $0 snapshot|check <tests_path> <snapshot_file|git_ref>" >&2; exit 2; }
[ -d "$TESTS" ] || { echo "FAIL  tests path not a directory: $TESTS"; exit 1; }
fingerprint() { ( cd "$1" && find . -type f -not -path '*/__pycache__/*' -not -name '*.pyc' -print0 | sort -z | xargs -0 shasum -a 256 ); }
case "$MODE" in
  snapshot)
    fingerprint "$TESTS" > "$REF" || exit 2
    echo "SNAPSHOT  $(wc -l < "$REF" | tr -d ' ') file(s) of $TESTS -> $REF"; exit 0 ;;
  check)
    if git rev-parse --verify --quiet "$REF^{commit}" >/dev/null 2>&1; then
      CHANGED=$(git diff --name-status "$REF" -- "$TESTS")
      UNTRACKED=$(git ls-files --others --exclude-standard -- "$TESTS")
      if [ -z "$CHANGED" ] && [ -z "$UNTRACKED" ]; then echo "PASS  $TESTS unchanged since $REF"; exit 0; fi
      echo "FAIL  $TESTS changed since $REF"; [ -n "$CHANGED" ] && echo "$CHANGED" | sed 's/^/  tracked: /'; [ -n "$UNTRACKED" ] && echo "$UNTRACKED" | sed 's/^/  untracked: /'; exit 1
    elif [ -f "$REF" ]; then
      NOW=$(mktemp -t gate-unchanged.XXXXXX); fingerprint "$TESTS" > "$NOW"
      if diff -q "$REF" "$NOW" >/dev/null; then rm -f "$NOW"; echo "PASS  $TESTS matches snapshot $REF"; exit 0; fi
      echo "FAIL  $TESTS differs from snapshot $REF"; diff "$REF" "$NOW" | grep '^[<>]' | sed 's/^</  before:/; s/^>/  after: /'; rm -f "$NOW"; exit 1
    else
      echo "usage: third argument must be a git ref or an existing snapshot file: $REF" >&2; exit 2
    fi ;;
  *) echo "usage: $0 snapshot|check <tests_path> <snapshot_file|git_ref>" >&2; exit 2 ;;
esac
