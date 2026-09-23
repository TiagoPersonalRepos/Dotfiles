#!/usr/bin/env python3

# NOTE: Genereted by claude

"""Claude Code status line: tokens used this calendar month + plan limits + session cost.

Reads the JSON Claude Code pipes on stdin, and totals token usage for the current
month from the local transcripts in ~/.claude/projects (this machine only).
Per-file results are cached, so only files that changed are re-read.
"""
import datetime
import glob
import json
import os
import sys

CONFIG_DIR = os.environ.get("CLAUDE_CONFIG_DIR", os.path.expanduser("~/.claude"))
CACHE_PATH = os.path.join(CONFIG_DIR, "statusline-month-cache.json")

def human(n):
    for unit, size in (("B", 1e9), ("M", 1e6), ("k", 1e3)):
        if n >= size:
            return f"{n / size:.1f}{unit}"
    return str(int(n))


def scan_file(path, month_key):
    totals = {"in": 0, "out": 0, "cache_w": 0, "cache_r": 0}
    seen = set()
    with open(path, encoding="utf-8", errors="replace") as fh:
        for line in fh:
            if '"usage"' not in line:
                continue
            try:
                obj = json.loads(line)
            except ValueError:
                continue
            msg = obj.get("message")
            if not isinstance(msg, dict) or not isinstance(msg.get("usage"), dict):
                continue
            ts = obj.get("timestamp")
            if not ts:
                continue
            try:
                local = datetime.datetime.fromisoformat(ts.replace("Z", "+00:00")).astimezone()
            except ValueError:
                continue
            if local.strftime("%Y-%m") != month_key:
                continue
            key = (msg.get("id"), obj.get("requestId"))
            if key[0]:
                if key in seen:  # streamed responses repeat the same usage block
                    continue
                seen.add(key)
            u = msg["usage"]
            totals["in"] += u.get("input_tokens") or 0
            totals["out"] += u.get("output_tokens") or 0
            totals["cache_w"] += u.get("cache_creation_input_tokens") or 0
            totals["cache_r"] += u.get("cache_read_input_tokens") or 0
    return totals


def month_totals():
    now = datetime.datetime.now().astimezone()
    month_key = now.strftime("%Y-%m")
    month_start = now.replace(day=1, hour=0, minute=0, second=0, microsecond=0).timestamp()

    try:
        with open(CACHE_PATH, encoding="utf-8") as fh:
            cache = json.load(fh)
        if cache.get("month") != month_key:
            cache = {"month": month_key, "files": {}}
    except (OSError, ValueError):
        cache = {"month": month_key, "files": {}}

    files = {}
    for path in glob.glob(os.path.join(CONFIG_DIR, "projects", "**", "*.jsonl"), recursive=True):
        try:
            st = os.stat(path)
        except OSError:
            continue
        if st.st_mtime < month_start:
            continue
        old = cache["files"].get(path)
        if old and old["mtime"] == st.st_mtime and old["size"] == st.st_size:
            files[path] = old
        else:
            try:
                files[path] = {"mtime": st.st_mtime, "size": st.st_size, "t": scan_file(path, month_key)}
            except OSError:
                continue

    cache["files"] = files
    try:
        tmp = CACHE_PATH + ".tmp"
        with open(tmp, "w", encoding="utf-8") as fh:
            json.dump(cache, fh)
        os.replace(tmp, CACHE_PATH)
    except OSError:
        pass

    total = {"in": 0, "out": 0, "cache_w": 0, "cache_r": 0}
    for entry in files.values():
        for k in total:
            total[k] += entry["t"].get(k, 0)
    return now.strftime("%m/%y"), total


def main():
    try:
        data = json.load(sys.stdin)
        # info_path = os.path.join(CONFIG_DIR, "info.json")
        # if not os.path.exists(info_path) :

        #     with open(info_path, "a") as file :
        #         file.write(json.dumps(data))

    except ValueError:
        data = {}

    parts = []

    try:
        month_name, t = month_totals()
        all_tokens = t["in"] + t["out"] + t["cache_w"] + t["cache_r"]
        parts.append(
            f"{month_name}: {human(all_tokens)} tokens "
            f"(in: {human(t['in'])}, out: {human(t['out'])}, cached: {human(t['cache_w'] + t['cache_r'])})"
        )
    except Exception:
        parts.append("month: n/a")

    # Plan limits (Pro/Max, when Claude Code provides them)
    rl = data.get("rate_limits") or {}
    limits = []
    for label, key in (("5h", "five_hour"), ("7d", "seven_day"), ("spend", "spend_limit")):
        pct = (rl.get(key) or {}).get("used_percentage")
        if pct is not None:
            limits.append(f"{label} {pct:.0f}%")
    if limits:
        parts.append("limits " + ", ".join(limits))

    cost = (data.get("cost") or {}).get("total_cost_usd")
    if cost is not None:
        parts.append(f"session ${cost:.2f}")

    print(" | ".join(parts))


if __name__ == "__main__":
    main()