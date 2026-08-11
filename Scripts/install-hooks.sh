#!/bin/bash
# Installs the Odometer beacon hook into ~/.claude/settings.json.
# Existing settings and unrelated hooks are preserved.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET_DIR="$HOME/.claude/odometer"
SETTINGS="$HOME/.claude/settings.json"

mkdir -p "$TARGET_DIR"
cp "$ROOT/Scripts/odometer-hook.py" "$TARGET_DIR/hook.py"
chmod +x "$TARGET_DIR/hook.py"

python3 - "$SETTINGS" "$TARGET_DIR/hook.py" <<'PY'
import json, os, sys

settings_path, hook_path = sys.argv[1], sys.argv[2]

settings = {}
if os.path.exists(settings_path):
    try:
        with open(settings_path, encoding="utf-8") as handle:
            settings = json.load(handle)
    except Exception as error:
        sys.exit(
            f"error: {settings_path} is not valid JSON ({error}).\n"
            "Fix or move the file, then re-run install-hooks.sh. Nothing was changed."
        )
    if not isinstance(settings, dict):
        sys.exit(f"error: {settings_path} does not contain a JSON object. Nothing was changed.")

MARKER = "odometer/hook.py"
wanted = {
    "Notification": f'python3 "{hook_path}" set',
    "UserPromptSubmit": f'python3 "{hook_path}" clear',
    "PostToolUse": f'python3 "{hook_path}" clear',
}

hooks = settings.setdefault("hooks", {})
for event, command in wanted.items():
    groups = [
        group for group in hooks.get(event, [])
        if not any(MARKER in entry.get("command", "") for entry in group.get("hooks", []))
    ]
    groups.append({"hooks": [{"type": "command", "command": command}]})
    hooks[event] = groups

# Only ever back up the pre-install state. Writing this unconditionally meant a
# second run overwrote the clean backup with an already-hooked copy, so the
# safety net destroyed itself exactly when it was needed.
backup = settings_path + ".odometer-backup"
if os.path.exists(settings_path) and not os.path.exists(backup):
    with open(settings_path, encoding="utf-8") as src, open(backup, "w", encoding="utf-8") as dst:
        dst.write(src.read())

os.makedirs(os.path.dirname(settings_path), exist_ok=True)
tmp = settings_path + ".tmp"
with open(tmp, "w", encoding="utf-8") as handle:
    json.dump(settings, handle, indent=2, ensure_ascii=False)
    handle.write("\n")
os.replace(tmp, settings_path)

print(f"Hooks installed in {settings_path}")
if os.path.exists(backup):
    print(f"Previous settings backed up to {backup}")
PY
