#!/usr/bin/env python3
"""metrics_log.py: record the model server's own per-request timings while a teacher run goes on.

The server (Strata) keeps its last 12 requests and running totals on GET /metrics; its streamed answers on
/v1/messages carry no timings, so the factory records none. This reads /metrics every INTERVAL seconds and appends:
  OUT/requests.jsonl  each request the server lists, once (by its id), with the time it was first seen
  OUT/live.tsv        one line per read: the server's state, its queue, the request in progress, and its totals
  OUT/latest.json     the last read's totals and live state (written whole, then renamed)
It asks the model nothing: /metrics is the server's status page. It stops when OUT/logger.stop exists.
Environment: MODEL_URL (the server, without /v1), KEY_FILE (a file holding the server's key; never printed),
OUT, INTERVAL (10).
"""
import json
import os
import time
import urllib.request

url = os.environ["MODEL_URL"].rstrip("/") + "/metrics"
with open(os.environ["KEY_FILE"]) as f:
    key = f.read().strip()
out = os.environ["OUT"]
interval = float(os.environ.get("INTERVAL", "10"))
os.makedirs(out, exist_ok=True)
req_path = os.path.join(out, "requests.jsonl")
live_path = os.path.join(out, "live.tsv")
stop_path = os.path.join(out, "logger.stop")

seen = set()
if os.path.exists(req_path):
    with open(req_path) as f:
        for line in f:
            try:
                seen.add(json.loads(line)["id"])
            except (ValueError, KeyError):
                pass

cols = ["read_at", "server_time", "state", "queued", "phase", "prompt_tokens", "prompt_read", "generated",
        "requests", "prompt_tokens_total", "reused_total", "output_tokens_total", "prompt_ms_total",
        "decode_ms_total", "new_records", "error"]
if not os.path.exists(live_path):
    with open(live_path, "w") as f:
        f.write("\t".join(cols) + "\n")


def fetch():
    request = urllib.request.Request(url, headers={"Authorization": "Bearer " + key})
    with urllib.request.urlopen(request, timeout=30) as response:
        return json.load(response)


while not os.path.exists(stop_path):
    now = time.time()
    row = {c: "" for c in cols}
    row["read_at"] = f"{now:.3f}"
    try:
        data = fetch()
        new = [r for r in reversed(data.get("requests") or []) if r.get("id") not in seen]
        with open(req_path, "a") as f:
            for r in new:
                seen.add(r["id"])
                f.write(json.dumps(dict(r, seen_at=round(now, 3)), sort_keys=True) + "\n")
        live = data.get("live") or {}
        totals = data.get("totals") or {}
        row.update(server_time=data.get("time", ""), state=live.get("state"), queued=live.get("queued"),
                   phase=live.get("phase"), prompt_tokens=live.get("prompt_tokens"),
                   prompt_read=live.get("prompt_read"), generated=live.get("generated"),
                   requests=totals.get("requests"), prompt_tokens_total=totals.get("prompt_tokens"),
                   reused_total=totals.get("reused"), output_tokens_total=totals.get("output_tokens"),
                   prompt_ms_total=totals.get("prompt_ms"), decode_ms_total=totals.get("decode_ms"),
                   new_records=len(new))
        tmp = os.path.join(out, "latest.json.tmp")
        with open(tmp, "w") as f:
            json.dump({"read_at": now, "live": live, "totals": totals}, f, sort_keys=True)
        os.replace(tmp, os.path.join(out, "latest.json"))
    except Exception as error:  # a failed read is recorded, never fatal
        row["error"] = type(error).__name__ + ": " + str(error)[:200].replace("\t", " ").replace("\n", " ")
    with open(live_path, "a") as f:
        f.write("\t".join("" if row[c] is None else str(row[c]) for c in cols) + "\n")
    time.sleep(interval)
