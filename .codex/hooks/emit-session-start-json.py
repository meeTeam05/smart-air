#!/usr/bin/env python3
from __future__ import annotations

import json
import sys


def main() -> int:
    text = sys.stdin.read().strip()
    if not text:
        return 0

    json.dump(
        {
            "hookSpecificOutput": {
                "hookEventName": "SessionStart",
                "additionalContext": text,
            }
        },
        sys.stdout,
        ensure_ascii=False,
    )
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
