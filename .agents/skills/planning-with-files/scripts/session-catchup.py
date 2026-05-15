#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path
import sys


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


def emit_snippet(label: str, path: Path, limit: int) -> None:
    print(f"[planning-with-files] {label}: {path}")
    try:
        lines = path.read_text(encoding="utf-8").splitlines()
    except OSError:
        return
    for line in lines[:limit]:
        print(line)


def main() -> int:
    root = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else Path.cwd()
    plan_dir = resolve_plan_dir(root)
    if not plan_dir:
        return 0

    print("[planning-with-files] Existing planning context found.")
    task_plan = plan_dir / "task_plan.md"
    findings = plan_dir / "findings.md"
    progress = plan_dir / "progress.md"

    if task_plan.exists():
        emit_snippet("task_plan preview", task_plan, 20)
    if progress.exists():
        emit_snippet("progress preview", progress, 12)
    if findings.exists():
        print(f"[planning-with-files] findings available: {findings}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
