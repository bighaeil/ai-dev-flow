#!/usr/bin/env bash
# 에이전트 전용 PreToolUse 훅 — 역할별 금지 경로를 차단한다(종료 2 = 차단, 메시지는 stderr).
# 사용(에이전트 frontmatter hooks): bash "$CLAUDE_PROJECT_DIR"/scripts/gates/hook-path-guard.sh <role>
#   role = planner | plan-reviewer | designer | design-reviewer | test-writer | implementer | code-reviewer
# 경로 기준 = devflow/current.json {project, src_paths[], tests_path, docs_dir} — 2단계 설계가 정한다(없으면 test-writer·implementer는 전부 차단).
# contract_tests_path 도 tests 로 본다(test-writer 쓰기 허용·implementer 쓰기 금지).
# 범위: Read·Edit·Write·MultiEdit·NotebookEdit·Grep·Glob 의 file_path/path/notebook_path 만 본다.
#       ★Bash 안의 cat·sed·리다이렉션은 여기서 막지 않는다 → tests-unchanged.sh·transcript-audit.py 가 사후 검사.
set -u
ROLE="${1:-}"; [ -n "$ROLE" ] || { echo "hook-path-guard: role missing" >&2; exit 1; }
ROOT="${CLAUDE_PROJECT_DIR:-$(pwd)}"
exec python3 "$(dirname "$0")/hook_path_guard.py" "$ROLE" "$ROOT"
