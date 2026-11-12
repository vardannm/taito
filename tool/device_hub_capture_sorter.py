#!/usr/bin/env python3
"""Sort new Device Hub captures; run via a local five-second LaunchAgent."""

import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import time


ROUTES = {
    "iPhone 18 Pro": "iPhone 18 Pro",
    "iPad Pro 13-inch (M5)": "iPad 13 m5",
    "iPhone Duo": "iPhone duo",
}


def destination_folder(name):
    if Path(name).suffix.lower() not in {".png", ".jpg", ".jpeg", ".mp4", ".mov", ".m4v"}:
        return None
    for device, folder in ROUTES.items():
        if any(re.match(rf"^{re.escape(prefix + ' ' + device)} \d", name)
               for prefix in ("Screenshot", "Screen Recording")):
            return folder
    return None


def write_state(path, state):
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(".tmp")
    temporary.write_text(json.dumps(state))
    temporary.replace(path)


def sort_captures(desktop, state_path, initialize=False):
    captures = {
        p.name: p for p in desktop.iterdir()
        if not p.is_symlink() and p.is_file() and destination_folder(p.name)
    }
    if initialize or not state_path.exists():
        write_state(state_path, {"ignored": list(captures), "pending": {}})
        return
    state = json.loads(state_path.read_text())
    ignored = set(state["ignored"])
    pending = state["pending"]
    for name in list(pending):
        if name not in captures:
            del pending[name]
    for name, source in captures.items():
        if name in ignored:
            continue
        stat = source.stat()
        signature = [stat.st_ino, stat.st_size, stat.st_mtime_ns]
        previous = pending.get(name)
        if previous is None or previous["signature"] != signature:
            pending[name] = {"signature": signature, "since": time.time()}
            continue
        if stat.st_size == 0 or time.time() - previous["since"] < 5:
            continue
        # Never move a video while Device Hub or another process has it open.
        opened = subprocess.run(
            ["/usr/sbin/lsof", "-t", "--", str(source)],
            capture_output=True, timeout=5, check=False,
        )
        if opened.returncode != 1:
            continue
        if source.is_symlink() or source.stat().st_mtime_ns != stat.st_mtime_ns:
            continue
        folder = desktop / destination_folder(name)
        folder.mkdir(exist_ok=True)
        target = folder / name
        number = 2
        while True:
            try:
                # Both directories are on Desktop. Hard-link then unlink gives
                # no-overwrite moves, preserves metadata, and avoids copying video.
                os.link(source, target)
                break
            except FileExistsError:
                target = folder / f"{source.stem} ({number}){source.suffix}"
                number += 1
        source.unlink()
        del pending[name]
        print(f"Saved {target}", flush=True)
    write_state(state_path, state)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--desktop", type=Path, default=Path.home() / "Desktop")
    parser.add_argument("--state", type=Path, required=True)
    parser.add_argument("--initialize", action="store_true")
    parser.add_argument("--watch", action="store_true")
    args = parser.parse_args()
    sort_captures(args.desktop, args.state, args.initialize)
    while args.watch:
        time.sleep(5)
        try:
            sort_captures(args.desktop, args.state)
        except (OSError, subprocess.TimeoutExpired) as error:
            print(f"Capture sorter will retry: {error}", file=sys.stderr, flush=True)
