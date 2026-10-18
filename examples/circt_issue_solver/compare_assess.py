"""Compare structured assess-only verdicts with an explicit reference label."""
from __future__ import annotations

import argparse
import json
from pathlib import Path

import yaml

CATEGORIES = ("clear", "not_a_bug", "unclear")


def assessment_value(directory: Path, runner: dict) -> str:
    """Read the structured classification, rejecting failed or empty calls."""
    try:
        verdict = json.loads((directory / "verdict.json").read_text())
        phase = verdict.get("llm_phases", {}).get("assess", {})
        if (runner.get("status") != "completed" or runner.get("return_code") != 0
                or verdict.get("status") not in CATEGORIES
                or not (directory / "llm_assess.md").read_text().strip()
                or phase.get("success") is False):
            return "assessment_error"
        # Older verdicts omit success: require evidence of a returned session.
        if phase.get("success") is not True and not phase.get("session_id"):
            return "assessment_error"
        return verdict["status"]
    except (OSError, ValueError, AttributeError, TypeError):
        return "assessment_error"


def compare(run_dir: Path, issue: int, expected: str) -> list[dict]:
    """Print each model's result and save only exact matches as models YAML."""
    root = run_dir / f"issue_{issue}"
    if not root.is_dir():
        raise ValueError(f"Missing issue results directory: {root}")
    passing = []
    print(f"{'Model':24} {'Expected':12} {'Actual':18} Match")
    print("-" * 64)
    # Accept the new stage-first layout and historical nested-stage results.
    directories = set(root.glob("*/assess"))
    directories.update(p for p in root.iterdir() if p.is_dir()
                       and not (p / "assess").is_dir() and not (p / "full").is_dir())
    for directory in sorted(directories):
        try:
            runner = json.loads((directory / "runner.json").read_text())
            if not isinstance(runner, dict):
                runner = {}
        except (OSError, ValueError):
            runner = {}
        valid = (runner.get("issue_number") == issue and runner.get("stage") == "assess"
                 and isinstance(runner.get("model_name"), str)
                 and isinstance(runner.get("model"), str))
        actual = assessment_value(directory, runner) if valid else "assessment_error"
        name = runner["model_name"] if valid else (
            directory.parent.name if directory.name == "assess" else directory.name)
        match = actual == expected
        print(f"{name:24} {expected:12} {actual:18} {'yes' if match else 'no'}")
        if match:
            passing.append({"name": name, "model": runner["model"]})
    (run_dir / "passing_models.yaml").write_text(yaml.safe_dump({"models": passing}, sort_keys=False))
    return passing


def main() -> None:
    """Compare without launching full solver attempts."""
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--run-dir", required=True, type=Path)
    ap.add_argument("--issue", required=True, type=int)
    ap.add_argument("--expected", required=True, choices=CATEGORIES)
    args = ap.parse_args()
    try:
        compare(args.run_dir, args.issue, args.expected)
    except (OSError, ValueError) as exc:
        ap.error(str(exc))


if __name__ == "__main__":
    main()
