from __future__ import annotations

import json
import re
import sys
from pathlib import Path
from datetime import datetime


def read_text(path: Path) -> str:
    if not path.exists():
        return ""
    return path.read_text(encoding="utf-8", errors="replace")


def count_terms(text: str, terms: list[str]) -> dict[str, int]:
    lower = text.lower()
    return {term: lower.count(term.lower()) for term in terms}


def extract_action_summary(actions_path: Path) -> list[str]:
    if not actions_path.exists():
        return []
    data = json.loads(read_text(actions_path))
    rows = []
    for event in data.get("events", []):
        result = event.get("executionResult", "")
        target = event.get("target", {})
        details = target.get("targetDetails", {})
        label = details.get("contentDescription") or details.get("text") or details.get("className") or "launch"
        rows.append(f"- {event.get('sequence', 'launch')}: {target.get('type', 'LAUNCH')} `{label}` в†’ {result}")
    return rows


def main() -> int:
    artifacts = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("firebase_testlab_artifacts")
    report = artifacts / "firebase_testlab_report.md"

    logcat = read_text(artifacts / "logcat")
    actions = extract_action_summary(artifacts / "actions.json")

    terms = [
        "FATAL EXCEPTION",
        "AndroidRuntime",
        "E/flutter",
        "FlutterError",
        "Dart Error",
        "ANR",
        "am_crash",
        "Exception",
        "SSL",
        "HTTP",
        "timeout",
    ]
    counts = count_terms(logcat, terms)

    app_displayed = "Displayed com.nursultankoshoev.mobilechat/.MainActivity" in logcat
    app_fully_drawn = "Fully drawn com.nursultankoshoev.mobilechat/.MainActivity" in logcat
    has_crash = counts["FATAL EXCEPTION"] > 0 or counts["E/flutter"] > 0 or counts["FlutterError"] > 0 or counts["am_crash"] > 0

    lines = [
        "# Firebase Test Lab Report",
        "",
        f"Generated: {datetime.utcnow().isoformat()}Z",
        "",
        "## Summary",
        "",
        f"- App displayed: `{app_displayed}`",
        f"- App fully drawn: `{app_fully_drawn}`",
        f"- Crash detected: `{has_crash}`",
        "",
        "## Error counters",
        "",
    ]

    for term, count in counts.items():
        lines.append(f"- `{term}`: {count}")

    lines += [
        "",
        "## Robo / test actions",
        "",
    ]

    lines += actions or ["No actions.json found."]

    lines += [
        "",
        "## Recommendation",
        "",
    ]

    if has_crash:
        lines.append("Crash-like signals were found. Inspect `logcat` around the matching lines.")
    else:
        lines.append("No direct app crash signal was found in `logcat`. Review screenshots/video for UX issues.")

    report.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(report)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
