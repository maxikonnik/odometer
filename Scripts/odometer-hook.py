#!/usr/bin/env python3
"""Writes or clears an Odometer attention beacon.

Claude Code passes the hook payload on stdin. Invoked as:
    python3 hook.py set     # Notification  -> create the beacon
    python3 hook.py clear   # UserPromptSubmit / PostToolUse -> remove it
"""
import datetime
import json
import os
import sys


def main() -> int:
    if len(sys.argv) < 2 or sys.argv[1] not in ("set", "clear"):
        return 0
    action = sys.argv[1]

    try:
        payload = json.load(sys.stdin)
    except Exception:
        return 0

    session_id = payload.get("session_id")
    if not session_id or "/" in session_id or session_id in (".", ".."):
        return 0

    directory = os.path.join(os.path.expanduser("~"), ".claude", "odometer", "attention")
    path = os.path.join(directory, session_id + ".json")

    if action == "clear":
        try:
            os.remove(path)
        except OSError:
            pass
        return 0

    try:
        os.makedirs(directory, exist_ok=True)
        created = (
            datetime.datetime.now(datetime.timezone.utc)
            .replace(microsecond=0)
            .isoformat()
            .replace("+00:00", "Z")
        )
        beacon = {
            "sessionId": session_id,
            "cwd": payload.get("cwd", ""),
            "termProgram": os.environ.get("TERM_PROGRAM"),
            "createdAt": created,
        }
        tmp = path + ".tmp"
        with open(tmp, "w", encoding="utf-8") as handle:
            json.dump(beacon, handle)
        os.replace(tmp, path)
    except Exception:
        pass
    return 0


if __name__ == "__main__":
    sys.exit(main())
