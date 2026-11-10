#!/usr/bin/env python3
"""counts.py: the counts of one bench run, from the bench's own evidence (standard library only).

    python3 -I counts.py --data DATA --run RUN_ID --out DIR [--label NAME] [--proxy proxy.jsonl]

DATA is the bench's data folder, or any folder that holds a copy of the run as DATA/runs/RUN_ID (copied out of the
bench's container with: docker exec <bench container> tar -C /data/runs -cf - RUN_ID).
Reads DATA/runs/RUN_ID: run.json (the cases in order, each attempt's outcome) and per case attempt.json,
usage-NNNN.json (the server's prompt and completion tokens of each model call) and response-NNNN.sse (its last event
carries llama-server's counters prompt_n = prompt tokens processed anew, cache_n = prompt tokens taken from the
cache, predicted_n). Only token counts and outcomes are read: no time field is read or written.

Writes into DIR:
  series.tsv    one row: passed, failed, errors, attempts stopped at the generation budget and at the window,
                generated tokens, model calls, tokens and calls per passed case
  attempts.tsv  one row per case: status, passed, model calls, generated tokens, stop reason, peak prompt tokens,
                prompt tokens processed anew (sum and largest single call), prompt tokens from the cache
  calls.tsv     one row per model call: prompt tokens, of them new and cached, generated tokens, finish reason
With --proxy (the logging proxy's file for the same run) it also checks that the proxy saw the same calls in the
same order (generation requests only) and writes the result to proxy_check.txt.

"Stopped at the generation budget" is the bench's stop reason token_budget (the attempt's generated tokens reached
settings.max_tokens); "stopped at the window" is context_budget (the next call would not fit window_tokens).
"""
import argparse
import csv
import json
import sys
from pathlib import Path


def last_counters(sse_path):
    """llama-server's counters and the finish reason from a saved event stream."""
    timings, finish = {}, None
    try:
        with open(sse_path, encoding="utf-8", errors="replace") as f:
            for line in f:
                if not line.startswith("data:") or ('"timings"' not in line and '"finish_reason"' not in line):
                    continue
                try:
                    event = json.loads(line[5:])
                except ValueError:
                    continue
                if isinstance(event.get("timings"), dict):
                    timings = event["timings"]
                for choice in event.get("choices") or []:
                    if choice.get("finish_reason"):
                        finish = choice["finish_reason"]
    except OSError:
        pass
    return timings, finish


def read_json(path, default=None):
    try:
        return json.loads(Path(path).read_text())
    except (OSError, ValueError):
        return default


def write_tsv(path, header, rows):
    with open(path, "w", newline="") as f:
        w = csv.writer(f, delimiter="\t", lineterminator="\n")
        w.writerow(header)
        w.writerows(rows)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--data", required=True, type=Path, help="the controller's data folder")
    ap.add_argument("--run", required=True, help="the run id")
    ap.add_argument("--out", required=True, type=Path)
    ap.add_argument("--proxy", type=Path, help="the proxy's proxy.jsonl for this run")
    ap.add_argument("--label", default="", help="a name for the series column (file and seed)")
    a = ap.parse_args()
    root = a.data / "runs" / a.run
    run = read_json(root / "run.json")
    if not run:
        sys.exit(f"no run.json in {root}")
    settings = run.get("settings") or {}
    budget = settings.get("max_tokens")
    a.out.mkdir(parents=True, exist_ok=True)

    attempt_rows, call_rows, all_calls = [], [], []
    passed = failed = errors = at_budget = at_window = tokens = calls = 0
    passed_tokens = passed_calls = 0
    for case in run.get("cases") or []:
        att = read_json(root / case / "attempt.json") or (run.get("attempts") or {}).get(case) or {}
        status = att.get("status")
        if status == "running":  # an attempt in progress keeps its counts in agent-progress.json
            att = {**att, **(read_json(root / case / "agent-progress.json") or {}), "status": status}
        ok = (att.get("grade") or {}).get("passed") if status == "completed" else None
        peak = new_sum = new_max = cached_sum = 0
        n = 0
        for usage_path in sorted((root / case).glob("usage-*.json")):
            step = usage_path.stem.split("-", 1)[1]
            usage = read_json(usage_path) or {}
            timings, finish = last_counters(root / case / f"response-{step}.sse")
            prompt = usage.get("input_tokens")
            new, cached = timings.get("prompt_n"), timings.get("cache_n")
            peak = max(peak, prompt or 0)
            new_sum += new or 0
            new_max = max(new_max, new or 0)
            cached_sum += cached or 0
            n += 1
            row = [case, step, prompt, new, cached, usage.get("output_tokens"), finish]
            call_rows.append(row)
            all_calls.append(dict(case=case, step=step, prompt=prompt, new=new, out=usage.get("output_tokens")))
        gen = att.get("generated_tokens") or 0
        stop = att.get("stop_reason")
        passed += ok is True
        failed += ok is False
        errors += status not in ("completed",)
        at_budget += stop == "token_budget"
        at_window += stop == "context_budget"
        tokens += gen
        calls += att.get("calls") or 0
        if ok is True:
            passed_tokens += gen
            passed_calls += att.get("calls") or 0
        attempt_rows.append([case, status, {True: 1, False: 0}.get(ok, ""), att.get("calls"), gen, stop or "",
                             int(budget is not None and gen >= budget), peak, new_sum, new_max, cached_sum, n,
                             (att.get("error") or "")[:200].replace("\t", " ").replace("\n", " ")])

    write_tsv(a.out / "attempts.tsv",
              ["case", "status", "passed", "model_calls", "generated_tokens", "stop_reason", "generated_at_budget",
               "peak_prompt_tokens", "new_prompt_tokens_sum", "new_prompt_tokens_largest_call", "cached_prompt_tokens_sum",
               "calls_with_usage", "error"], attempt_rows)
    write_tsv(a.out / "calls.tsv",
              ["case", "call", "prompt_tokens", "new_prompt_tokens", "cached_prompt_tokens", "generated_tokens",
               "finish_reason"], call_rows)
    per = lambda x: f"{x / passed:.1f}" if passed else ""
    write_tsv(a.out / "series.tsv",
              ["series", "run_id", "seed", "status", "cases", "passed", "failed", "errors", "stopped_at_generation_budget",
               "stopped_at_window", "generated_tokens", "model_calls", "tokens_per_passed_case", "calls_per_passed_case",
               "window_tokens", "response_tokens", "max_tokens", "reasoning_effort", "release_id"],
              [[a.label, run.get("id"), settings.get("seed"), run.get("status"), len(run.get("cases") or []), passed,
                failed, errors, at_budget, at_window, tokens, calls, per(passed_tokens), per(passed_calls),
                settings.get("window_tokens"), settings.get("response_tokens"), budget,
                settings.get("reasoning_effort"), run.get("release_id")]])
    print(f"{a.label or a.run}: {run.get('status')}, {passed} passed, {failed} failed, {errors} not completed, "
          f"{at_budget} stopped at the generation budget, {at_window} at the window, {tokens} generated tokens, "
          f"{calls} model calls")

    if a.proxy:
        rows = []
        with open(a.proxy) as f:
            for line in f:
                try:
                    r = json.loads(line)
                except ValueError:
                    continue
                if r.get("path", "").split("?")[0].endswith("/chat/completions"):
                    rows.append(r)
        same = sum(1 for c, r in zip(all_calls, rows)
                   if (r.get("usage") or {}).get("prompt_tokens") == c["prompt"]
                   and (r.get("usage") or {}).get("completion_tokens") == c["out"])
        text = (f"bench calls with usage: {len(all_calls)}\nproxy generation requests: {len(rows)}\n"
                f"same prompt and completion tokens at the same position: {same}\n"
                f"proxy requests with an error: {sum(1 for r in rows if r.get('upstream_error') or r.get('client_gone'))}\n")
        (a.out / "proxy_check.txt").write_text(text)
        print(text, end="")


if __name__ == "__main__":
    main()
