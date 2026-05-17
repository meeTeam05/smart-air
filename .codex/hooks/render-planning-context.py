#!/usr/bin/env python3
from __future__ import annotations

import argparse
import os
from pathlib import Path


def resolve_plan_dir(root: Path) -> Path | None:
    planning_root = root / ".planning"
    active_file = planning_root / ".active_plan"
    if active_file.exists():
        plan_id = active_file.read_text(encoding="utf-8").strip()
        if plan_id:
            candidate = planning_root / plan_id
            if candidate.is_dir():
                return candidate
    if planning_root.is_dir():
        candidates = [p for p in planning_root.iterdir() if p.is_dir() and (p / "task_plan.md").exists()]
        if candidates:
            candidates.sort(key=lambda p: p.stat().st_mtime, reverse=True)
            return candidates[0]
    return None


def is_session_attached(root: Path) -> bool:
    sessions_dir = root / ".planning" / "sessions"
    if not sessions_dir.exists():
        return True
    session_id = os.environ.get("PWF_SESSION_ID", "").strip()
    if not session_id:
        return False
    return (sessions_dir / f"{session_id}.attached").exists()


def read_lines(path: Path) -> list[str]:
    try:
        return path.read_text(encoding="utf-8").splitlines()
    except OSError:
        return []


def render_session_start(plan_dir: Path) -> str:
    lines: list[str] = ["[planning-with-files] Existing planning context found."]
    task_plan = plan_dir / "task_plan.md"
    findings = plan_dir / "findings.md"
    progress = plan_dir / "progress.md"

    if task_plan.exists():
        lines.append(f"[planning-with-files] task_plan preview: {task_plan}")
        lines.extend(read_lines(task_plan)[:20])
    if progress.exists():
        lines.append(f"[planning-with-files] progress preview: {progress}")
        lines.extend(read_lines(progress)[:12])
    if findings.exists():
        lines.append(f"[planning-with-files] findings available: {findings}")
    return "\n".join(lines).strip()


def render_user_prompt(plan_dir: Path) -> str:
    plan_file = plan_dir / "task_plan.md"
    progress_file = plan_dir / "progress.md"
    if not plan_file.exists():
        return ""

    lines: list[str] = [
        "[planning-with-files] ACTIVE PLAN - current state:",
        *read_lines(plan_file)[:50],
        "",
        "=== recent progress ===",
        *read_lines(progress_file)[-20:],
        "",
        "[planning-with-files] Read findings.md for research context. Continue from the current phase.",
    ]
    return "\n".join(lines).strip()


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--mode", choices=("session-start", "user-prompt"), required=True)
    parser.add_argument("root", nargs="?", default=".")
    args = parser.parse_args()

    root = Path(args.root).resolve()
    plan_dir = resolve_plan_dir(root)
    if not plan_dir:
        return 0

    if args.mode == "session-start":
        text = render_session_start(plan_dir)
    else:
        if not is_session_attached(root):
            return 0
        text = render_user_prompt(plan_dir)

    if text:
        print(text)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
