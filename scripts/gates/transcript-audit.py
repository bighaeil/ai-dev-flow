#!/usr/bin/env python3
"""서브에이전트 전사(JSONL) 사후 감사 — 훅이 못 막는 경로(Bash 안의 cat·sed·리다이렉션, path 없는 Grep 등)를 전사에서 찾아낸다.

사용:
  python3 scripts/gates/transcript-audit.py <transcript.jsonl> --role <role> [--root DIR] [--config devflow/current.json]
  (SubagentStop 훅 입력을 stdin 으로 받으면 인자 없이: 훅 JSON 의 agent_type·agent_transcript_path 를 쓴다)
판정: 금지 경로가 등장한 tool_use 가 0 이면 PASS(종료 0), 있으면 FAIL(종료 1) — 각 건을 "도구 / 경로 / 입력 요약" 으로 출력.
한계: 문자열 매칭이다. 금지 경로를 변수·와일드카드·심볼릭 링크로 가리키면 못 본다 → 이 감사는 '지시 + 사후 검사' 등급의 사후 검사일 뿐이다.
"""
import sys, json, os, re, argparse

ROLE_RULES = {
    # role: (금지 '읽기' 경로 키, 금지 '쓰기' 경로 키)  — 키는 current.json 의 필드명
    "test-writer": ("src_paths", "src_paths"),
    "implementer": (None, ("tests_path", "contract_tests_path")),
    "code-reviewer": (None, "src_paths"),
}
WRITE_TOOLS = {"Edit", "Write", "MultiEdit", "NotebookEdit"}
READ_TOOLS = {"Read", "Grep", "Glob"}
BASH_WRITE = re.compile(r"(>>?|\btee\b|\bsed\s+-i|\bcp\b|\bmv\b|\brm\b|\btouch\b|\bpython3?\s+-c\b|\bcat\s*>)")

def walk(obj):
    if isinstance(obj, dict):
        if obj.get("type") == "tool_use" and "name" in obj:
            yield obj
        for v in obj.values(): yield from walk(v)
    elif isinstance(obj, list):
        for v in obj: yield from walk(v)

def load_uses(path):
    with open(path, encoding="utf-8", errors="replace") as f:
        for ln in f:
            ln = ln.strip()
            if not ln: continue
            try: yield from walk(json.loads(ln))
            except Exception: continue

def mentions(text, dirs):
    return [d for d in dirs if d and (d.rstrip("/") in text)]

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("transcript", nargs="?"); ap.add_argument("--role"); ap.add_argument("--root", default=os.environ.get("CLAUDE_PROJECT_DIR") or os.getcwd())
    ap.add_argument("--config", default=None)
    a = ap.parse_args()
    transcript, role = a.transcript, a.role
    if transcript is None and not sys.stdin.isatty():
        try:
            ev = json.load(sys.stdin); transcript = ev.get("agent_transcript_path"); role = role or ev.get("agent_type")
        except Exception: pass
    if not transcript or not role:
        print("usage: transcript-audit.py <transcript.jsonl> --role <role>", file=sys.stderr); return 2
    cfg_path = a.config or os.path.join(a.root, "devflow", "current.json")
    try: cfg = json.load(open(cfg_path))
    except Exception:
        print(f"FAIL  config not found/invalid: {cfg_path}"); return 1
    if role not in ROLE_RULES:
        print(f"PASS  role {role} has no path rules to audit"); return 0
    rk, wk = ROLE_RULES[role]
    def dirs(k):
        if not k: return []
        keys = k if isinstance(k, tuple) else (k,)
        out = []
        for kk in keys:
            v = cfg.get(kk, []); out += v if isinstance(v, list) else [v]
        return [x for x in out if x]
    rd, wd = dirs(rk), dirs(wk)
    hits = []
    for u in load_uses(transcript):
        name, inp = u["name"], u.get("input", {}) or {}
        blob = json.dumps(inp, ensure_ascii=False)
        tgt = inp.get("file_path") or inp.get("notebook_path") or inp.get("path") or ""
        if name in READ_TOOLS and rd:
            m = mentions(tgt or blob, rd)
            if m or (name in ("Grep", "Glob") and not inp.get("path")):
                hits.append((name, m or ["(no path — repo-wide)"], blob[:120]))
        if name in WRITE_TOOLS and wd and mentions(tgt, wd):
            hits.append((name, mentions(tgt, wd), blob[:120]))
        if name == "Bash":
            cmd = inp.get("command", "")
            if rd and mentions(cmd, rd): hits.append(("Bash(read)", mentions(cmd, rd), cmd[:120]))
            cmd_w = re.sub(r"\d*>&\d+|\d*>\s*/dev/null", " ", cmd)  # 2>&1 · 2>/dev/null 은 파일 쓰기가 아니다(10/14 거짓 양성 6+1건)
            if wd and mentions(cmd, wd) and BASH_WRITE.search(cmd_w): hits.append(("Bash(write?)", mentions(cmd, wd), cmd[:120]))
    if not hits:
        print(f"PASS  {role}: no forbidden-path tool use in {transcript}"); return 0
    print(f"FAIL  {role}: {len(hits)} forbidden-path tool use(s) in {transcript}")
    for n, m, s in hits: print(f"  {n:<12} {','.join(m):<32} {s}")
    return 1

if __name__ == "__main__":
    sys.exit(main())
