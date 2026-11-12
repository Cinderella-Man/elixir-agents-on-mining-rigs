#!/usr/bin/env python3
"""collect.py: the tables of a teacher run made by drive.sh: one row per session, one row per model call, totals.

Reads, for each task in DRIVE_OUT/cases.tsv:
  RUNS/<run>/events.jsonl            the run's phases with times: preparation, the session (phase "running"), grading
  RUNS/<run>/<task>/attempt.json     how the attempt ended (status, stop_reason) and its grade
  RUNS/<run>/<task>/grade.json       the five steps of the grade (factory README 2.2), when present
  RUNS/<run>/<task>/usage-NNNN.json  the prompt and generated tokens of each model call, as the engine counted them
  RUNS/<run>/<task>/request-NNNN.json and response-NNNN.sse   their file times: when a call was sent (before the
                                     engine counts its prompt) and when its answer had arrived; the answer's stop
                                     reason and tool calls
  RUNS/<run>/<task>/pi-events.jsonl  Pi's tool calls
  DRIVE_OUT/cases/<task>*/kept.json  the factory's kept list, the one of this run
  DRIVE_OUT/metrics/requests.jsonl   the server's own record of each request (metrics_log.py): prompt tokens, the
                                     part reused from the previous request, prompt and generation milliseconds
  TASKS/<task>/case.json, ticket.md  the task's kind and the description's length
Each call is matched to the server's record by order, time and token counts (prompt and generated equal).
Writes DEST/sessions.tsv, DEST/calls.tsv and DEST/totals.json. Times are seconds unless named _ms.
Environment: RUNS, DRIVE_OUT, TASKS, DEST.
"""
import datetime as dt
import glob
import json
import os
import re

RUNS = os.environ["RUNS"]
DRIVE = os.environ["DRIVE_OUT"]
TASKS = os.environ["TASKS"]
DEST = os.environ["DEST"]
os.makedirs(DEST, exist_ok=True)


def read_json(path, default=None):
    try:
        with open(path) as f:
            return json.load(f)
    except (OSError, ValueError):
        return default


def ts(text):
    return dt.datetime.fromisoformat(text.replace("Z", "+00:00")).timestamp()


def sse_events(path):
    events = []
    try:
        with open(path, errors="replace") as f:
            for line in f:
                if line.startswith("data:"):
                    try:
                        events.append(json.loads(line[5:].strip()))
                    except ValueError:
                        pass
    except OSError:
        pass
    return events


def failed_step(grade, attempt_grade):
    """The first of the five steps of README 2.2 that failed, or '' when the patch passed."""
    g = grade or {}
    if g.get("passed") is True or (attempt_grade or {}).get("passed") is True:
        return ""
    if not g:
        return "unknown"
    if "submission" not in g:
        return "1 patch: " + str(g.get("reason", ""))[:80]
    if not (g.get("submission") or {}).get("passed"):
        return "2 existing and own tests"
    if not (g.get("hidden") or {}).get("passed"):
        return "3 hidden tests"
    if not (g.get("regression") or {}).get("passed"):
        return "4 existing tests again"
    if not (g.get("regression_coverage") or {}).get("passed", True):
        return "5 own tests fail before the change"
    return "unknown"


records = []
req_path = os.path.join(DRIVE, "metrics", "requests.jsonl")
if os.path.exists(req_path):
    with open(req_path) as f:
        for line in f:
            try:
                records.append(json.loads(line))
            except ValueError:
                pass
records.sort(key=lambda r: r.get("time", 0))
used = set()

cases = []
with open(os.path.join(DRIVE, "cases.tsv")) as f:
    header = f.readline().rstrip("\n").split("\t")
    for line in f:
        cases.append(dict(zip(header, line.rstrip("\n").split("\t"))))

session_cols = ["id", "kind", "description_bytes", "run", "ended", "stop_reason", "passed", "failed_step", "kept",
                "run_s", "preparation_s", "session_s", "grading_s", "calls", "tool_calls", "prompt_tokens",
                "generated_tokens", "largest_prompt", "server_new_prompt_tokens", "server_reused_tokens",
                "reading_s", "generating_s", "model_wait_s", "other_model_s", "tools_and_rest_s",
                "calls_matched", "calls_read_in_full", "foreign_requests"]
call_cols = ["id", "call", "sent_at", "wall_ms", "prompt_tokens", "reused", "new_prompt_tokens", "prompt_ms",
             "generated_tokens", "decode_ms", "first_token_s", "stop", "tool_calls", "matched"]
sessions, calls_out = [], []

for case in cases:
    cid, run = case["id"], case.get("run", "")
    if not run:
        continue
    rdir = os.path.join(RUNS, run)
    adir = os.path.join(rdir, cid)
    attempt = read_json(os.path.join(adir, "attempt.json"), {})
    grade = read_json(os.path.join(adir, "grade.json"), {})
    spec = read_json(os.path.join(TASKS, cid, "case.json"), {})
    ticket = os.path.join(TASKS, cid, "ticket.md")
    # the factory's kept list of this run (a task run twice keeps each run's list in its own folder)
    kept = next((k for k in (read_json(p, {}) for p in glob.glob(os.path.join(DRIVE, "cases", cid + "*", "kept.json")))
                 if (k.get("ok") or {}).get("run") == run), {})
    kept_ids = [k.get("case") for k in ((kept.get("ok") or {}).get("kept") or [])]

    # phases from the run's events
    first = running = grading = last = None
    with open(os.path.join(rdir, "events.jsonl")) as f:
        for line in f:
            e = json.loads(line)
            t = ts(e["at"])
            first = t if first is None else first
            last = t
            phase = (e.get("case_phase") or {}).get("phase")
            if phase == "running" and running is None:
                running = t
            if phase == "grading" and grading is None:
                grading = t
    run_json = read_json(os.path.join(rdir, "run.json"), {})
    for key in ("finished_at", "completed_at", "ended_at"):
        if run_json.get(key):
            last = max(last or 0, ts(run_json[key]))
    start = ts(case["started"]) if case.get("started") else first
    end = ts(case["ended"]) if case.get("ended") else last

    # model calls
    steps = sorted(glob.glob(os.path.join(adir, "usage-*.json")))
    rows = []
    for usage_path in steps:
        n = re.search(r"usage-(\d+)\.json$", usage_path).group(1)
        usage = read_json(usage_path, {})
        req = os.path.join(adir, f"request-{n}.json")
        resp = os.path.join(adir, f"response-{n}.sse")
        sent = os.stat(req).st_mtime if os.path.exists(req) else None
        got = os.stat(resp).st_mtime if os.path.exists(resp) else None
        events = sse_events(resp)
        stop = next((e.get("delta", {}).get("stop_reason") for e in events if e.get("type") == "message_delta"), "")
        tools = sum(1 for e in events if e.get("type") == "content_block_start"
                    and (e.get("content_block") or {}).get("type") == "tool_use")
        rows.append({"id": cid, "call": int(n), "sent": sent, "got": got, "prompt_tokens": usage.get("input_tokens"),
                     "generated_tokens": usage.get("output_tokens"), "stop": stop, "tool_calls": tools})
    # the server's records: in the session's window, in order, equal token counts
    window = [r for r in records if r["id"] not in used and start - 5 <= r.get("time", 0) <= (end or 1e12) + 5]
    for row in rows:
        match = next((r for r in window if r["id"] not in used and r.get("prompt_tokens") == row["prompt_tokens"]
                      and r.get("output_tokens") == row["generated_tokens"]
                      and (row["sent"] is None or r.get("time", 0) >= row["sent"] - 5)), None)
        if match:
            used.add(match["id"])
        row["record"] = match
    foreign = [r for r in window if r["id"] not in used and running and grading
               and running <= r.get("time", 0) <= grading]

    def num(v):
        return v if isinstance(v, (int, float)) else 0

    full_rereads, prev = 0, None
    for row in rows:
        rec = row["record"] or {}
        reused = rec.get("reused")
        if prev is not None and isinstance(reused, int) and reused < 0.5 * num(prev["prompt_tokens"]):
            full_rereads += 1
        prev = row
        calls_out.append({
            "id": cid, "call": row["call"],
            "sent_at": dt.datetime.fromtimestamp(row["sent"], dt.timezone.utc).strftime("%H:%M:%S") if row["sent"] else "",
            "wall_ms": round((row["got"] - row["sent"]) * 1000) if row["sent"] and row["got"] else "",
            "prompt_tokens": row["prompt_tokens"], "reused": reused if reused is not None else "",
            "new_prompt_tokens": (row["prompt_tokens"] - reused) if isinstance(reused, int) else "",
            "prompt_ms": rec.get("prompt_ms", ""), "generated_tokens": row["generated_tokens"],
            "decode_ms": rec.get("decode_ms", ""), "first_token_s": rec.get("first_engine_token_s", ""),
            "stop": row["stop"], "tool_calls": row["tool_calls"], "matched": "yes" if row["record"] else "no"})

    pi_tools = 0
    try:
        with open(os.path.join(adir, "pi-events.jsonl")) as f:
            pi_tools = sum(1 for line in f if '"type":"tool_execution_start"' in line)
    except OSError:
        pass
    matched = [r["record"] for r in rows if r["record"]]
    reading = sum(num(r.get("prompt_ms")) for r in matched) / 1000
    generating = sum(num(r.get("decode_ms")) for r in matched) / 1000
    waiting = sum((r["got"] - r["sent"]) for r in rows if r["sent"] and r["got"])
    session_s = (grading - running) if running and grading else None
    sessions.append({
        "id": cid, "kind": spec.get("task_kind", ""),
        "description_bytes": os.path.getsize(ticket) if os.path.exists(ticket) else "",
        "run": run, "ended": attempt.get("status", ""), "stop_reason": attempt.get("stop_reason", ""),
        "passed": "yes" if (attempt.get("grade") or {}).get("passed") is True else "no",
        "failed_step": failed_step(grade, attempt.get("grade")) if attempt.get("status") == "completed" else "",
        "kept": "yes" if cid in kept_ids else "no",
        "run_s": round(end - start, 1) if start and end else "",
        "preparation_s": round(running - start, 1) if running and start else "",
        "session_s": round(session_s, 1) if session_s is not None else "",
        "grading_s": round(end - grading, 1) if grading and end else "",
        "calls": len(rows), "tool_calls": pi_tools,
        "prompt_tokens": sum(num(r["prompt_tokens"]) for r in rows),
        "generated_tokens": sum(num(r["generated_tokens"]) for r in rows),
        "largest_prompt": max([num(r["prompt_tokens"]) for r in rows] or [0]),
        "server_new_prompt_tokens": sum(num(r.get("prompt_tokens")) - num(r.get("reused")) for r in matched),
        "server_reused_tokens": sum(num(r.get("reused")) for r in matched),
        "reading_s": round(reading, 1), "generating_s": round(generating, 1),
        "model_wait_s": round(waiting, 1), "other_model_s": round(waiting - reading - generating, 1),
        "tools_and_rest_s": round(session_s - waiting, 1) if session_s is not None else "",
        "calls_matched": f"{len(matched)}/{len(rows)}", "calls_read_in_full": full_rereads,
        "foreign_requests": len(foreign)})


def write(path, cols, rows):
    with open(path, "w") as f:
        f.write("\t".join(cols) + "\n")
        for r in rows:
            f.write("\t".join(str(r.get(c, "")) for c in cols) + "\n")


write(os.path.join(DEST, "sessions.tsv"), session_cols, sessions)
write(os.path.join(DEST, "calls.tsv"), call_cols, calls_out)


def total(key, rows=sessions):
    return round(sum(r[key] for r in rows if isinstance(r[key], (int, float))), 1)


starts = [ts(c["started"]) for c in cases if c.get("started")]
ends = [ts(c["ended"]) for c in cases if c.get("ended")]
wall = (max(ends) - min(starts)) if starts and ends else None
kept_n = sum(1 for s in sessions if s["kept"] == "yes")
totals = {
    "sessions": len(sessions), "kept": kept_n,
    "passed": sum(1 for s in sessions if s["passed"] == "yes"),
    "completed": sum(1 for s in sessions if s["ended"] == "completed"),
    "job_wall_s": round(wall, 1) if wall else None,
    "kept_per_hour": round(kept_n / (wall / 3600), 3) if wall else None,
    "run_s": total("run_s"), "preparation_s": total("preparation_s"), "session_s": total("session_s"),
    "grading_s": total("grading_s"), "reading_s": total("reading_s"), "generating_s": total("generating_s"),
    "model_wait_s": total("model_wait_s"), "other_model_s": total("other_model_s"),
    "tools_and_rest_s": total("tools_and_rest_s"), "calls": total("calls"), "tool_calls": total("tool_calls"),
    "prompt_tokens": total("prompt_tokens"), "generated_tokens": total("generated_tokens"),
    "server_new_prompt_tokens": total("server_new_prompt_tokens"),
    "server_reused_tokens": total("server_reused_tokens"), "calls_read_in_full": total("calls_read_in_full"),
    "foreign_requests": total("foreign_requests"),
    "unmatched_calls": sum(1 for c in calls_out if c["matched"] == "no"),
}
for kind in ("bug_fix", "feature"):
    rows = [s for s in sessions if s["kind"] == kind]
    totals[kind] = {"sessions": len(rows), "kept": sum(1 for s in rows if s["kept"] == "yes"),
                    "session_s": total("session_s", rows), "generated_tokens": total("generated_tokens", rows),
                    "calls": total("calls", rows)}
with open(os.path.join(DEST, "totals.json"), "w") as f:
    json.dump(totals, f, indent=1, sort_keys=True)
print(json.dumps(totals, sort_keys=True))
