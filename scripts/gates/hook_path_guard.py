# hook-path-guard.sh 의 본체 — 역할별 금지 경로 판정(stdin = 훅 JSON, argv = role root). 설명은 .sh 머리글.
import sys, json, os, fnmatch
role, root = sys.argv[1], sys.argv[2]
try:
    ev = json.load(sys.stdin)
except Exception:
    sys.exit(0)  # 입력이 없으면 판단하지 않는다(차단도 허용도 아님 → 허용)
tool = ev.get("tool_name", ""); inp = ev.get("tool_input", {}) or {}
target = inp.get("file_path") or inp.get("notebook_path") or inp.get("path") or ""
if not target:
    # Grep/Glob 에 path 가 없으면 저장소 전체 검색 = 금지 경로 내용이 섞여 들어올 수 있다 → 읽기 금지 역할은 차단
    if tool in ("Grep", "Glob") and role in ("test-writer",):
        print(f"[{role}] {tool} 에 path 를 지정해라 — 저장소 전체 검색은 금지 경로(src)를 포함한다", file=sys.stderr); sys.exit(2)
    sys.exit(0)
def rel(p):
    p = os.path.abspath(os.path.join(root, p)) if not os.path.isabs(p) else os.path.abspath(p)
    return os.path.relpath(p, root)
t = rel(target)
if t.startswith(".."):
    print(f"[{role}] 저장소 밖 경로 금지: {target}", file=sys.stderr); sys.exit(2)
cfg_path = os.path.join(root, "devflow", "current.json")
cfg = None
if os.path.exists(cfg_path):
    try: cfg = json.load(open(cfg_path))
    except Exception: cfg = None
def under(p, dirs):
    return any(p == d.rstrip("/") or p.startswith(d.rstrip("/") + "/") for d in dirs)
WRITE = tool in ("Edit", "Write", "MultiEdit", "NotebookEdit")
READ = tool in ("Read", "Grep", "Glob")
def deny(msg): print(f"[{role}] {msg}: {t}", file=sys.stderr); sys.exit(2)
if role in ("test-writer", "implementer", "code-reviewer"):
    if cfg is None:
        deny("devflow/current.json 이 없다 — 2단계 설계가 src_paths·tests_path 를 정하기 전엔 이 역할을 쓸 수 없다")
    def _l(v): return v if isinstance(v, list) else ([v] if v else [])
    src = _l(cfg.get("src_paths")); tests = _l(cfg.get("tests_path")) + _l(cfg.get("contract_tests_path")); docs = cfg.get("docs_dir", "")
    if role == "test-writer":
        if under(t, src): deny("src 읽기·쓰기 금지(설계·criteria.yaml 만 보고 테스트를 쓴다)")
        if WRITE and not under(t, tests): deny("tests_path 밖 쓰기 금지")
    elif role == "implementer":
        if WRITE and under(t, tests): deny("tests/ 수정 금지(테스트는 3단계에서 고정됐다)")
        if WRITE and (docs and under(t, [docs])): deny("설계 문서 수정 금지(설계와 다르면 review 로 돌려보낸다)")
    elif role == "code-reviewer":
        if WRITE and os.path.basename(t) != "review.md": deny("review.md 외 쓰기 금지")
        if WRITE and docs and not under(t, [docs]): deny("review.md 는 devflow/<project>/ 아래에만")
elif role in ("planner", "designer", "plan-reviewer", "design-reviewer"):
    if WRITE and not t.startswith("devflow/"): deny("devflow/ 밖 쓰기 금지(기획·설계 단계는 문서만 만든다)")
    if WRITE and role == "plan-reviewer" and os.path.basename(t) != "plan-review.md": deny("plan-review.md 외 쓰기 금지")
    if WRITE and role == "design-reviewer" and os.path.basename(t) != "design-review.md": deny("design-review.md 외 쓰기 금지")
sys.exit(0)
