"""Bounded subprocess wrapper for the existing frozen CIRCT solver."""
from __future__ import annotations

import argparse
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import re
import subprocess
import time

import yaml

FLOW_DIR = Path(__file__).resolve().parent


def directory_name(name: str) -> str:
    """Sanitize a model name into one nonempty directory component."""
    value = re.sub(r"[^A-Za-z0-9_-]+", "-", name).strip("-_")
    if not value:
        raise ValueError(f"Model name has no usable directory characters: {name!r}")
    return value


def load_models(path: Path) -> list[dict]:
    """Load model names and Bedrock/OpenCode IDs, rejecting directory collisions."""
    data = yaml.safe_load(path.read_text())
    if not isinstance(data, dict) or not isinstance(data.get("models"), list):
        raise ValueError("Models YAML must contain a 'models' list")
    models, seen = [], set()
    for entry in data["models"]:
        if not isinstance(entry, dict) or any(
                not isinstance(entry.get(k), str) or not entry[k].strip()
                for k in ("name", "model")):
            raise ValueError("Each model requires nonempty string 'name' and 'model'")
        if not entry["model"].startswith("amazon-bedrock/") or entry["model"] == "amazon-bedrock/":
            raise ValueError("Model IDs must use the amazon-bedrock/ OpenCode provider")
        folder = directory_name(entry["name"])
        if folder.casefold() in seen:
            raise ValueError(f"Duplicate sanitized model directory: {folder}")
        seen.add(folder.casefold())
        models.append({k: entry[k] for k in ("name", "model")})
    return models


def build_command(stage: str, issue: int, model: dict, issues_dir: Path,
                  output_dir: Path) -> list[str]:
    """Construct the existing assess-only or normal full-flow invocation."""
    return [str(FLOW_DIR / "fix_issues_submit.sh"), "--backend", "opencode",
            "--model", model["model"], "--issues-dir", str(issues_dir),
            "--output-dir", str(output_dir),
            "--assess-only" if stage == "assess" else "--issue", str(issue)]


def run_model(stage: str, issue: int, model: dict, issues_dir: Path,
              output_dir: Path) -> dict:
    """Run once with captured logs and metadata; never retry a failed model."""
    command = build_command(stage, issue, model, issues_dir, output_dir)
    metadata = {"issue_number": issue, "model_name": model["name"],
                "model": model["model"], "stage": stage, "command": command,
                "start_timestamp": datetime.now(timezone.utc).isoformat(),
                "status": "running", "return_code": None}
    runner = output_dir / "runner.json"
    runner.write_text(json.dumps(metadata, indent=2))
    tick = time.monotonic()
    try:
        with (output_dir / "stdout.log").open("w") as stdout, \
                (output_dir / "stderr.log").open("w") as stderr:
            # Submission must wait for actual completion, even if the caller's
            # shell normally uses detached jobs.
            env = dict(os.environ, NO_WAIT="0")
            result = subprocess.run(command, cwd=FLOW_DIR, env=env,
                                    stdout=stdout, stderr=stderr, check=False)
        metadata["return_code"] = result.returncode
        metadata["status"] = "completed" if result.returncode == 0 else "failed"
        verdict = json.loads((output_dir / "verdict.json").read_text())
        if not isinstance(verdict, dict) or verdict.get("status") in (None, "error"):
            metadata["status"] = "failed"
        if stage == "assess":
            from compare_assess import assessment_value
            if assessment_value(output_dir, metadata) == "assessment_error":
                metadata["status"] = "failed"
    except Exception as exc:
        metadata.update(status="failed", error=str(exc))
    finally:
        metadata.update(finish_timestamp=datetime.now(timezone.utc).isoformat(),
                        elapsed_seconds=time.monotonic() - tick)
        runner.write_text(json.dumps(metadata, indent=2))
    return metadata


def main() -> int:
    """Validate the whole batch before launching a bounded set of solver jobs."""
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("stage", choices=("assess", "full"))
    ap.add_argument("--issue", required=True, type=int)
    ap.add_argument("--models", required=True, type=Path)
    ap.add_argument("--run-name", required=True)
    ap.add_argument("--max-parallel", type=int)
    ap.add_argument("--issues-dir", type=Path, default=FLOW_DIR / "issuestouse")
    ap.add_argument("--results-dir", type=Path, default=FLOW_DIR / "benchmark_results",
                    help="results root; runs are grouped under assess/ or full/")
    args = ap.parse_args()
    parallel = args.max_parallel if args.max_parallel is not None else (2 if args.stage == "assess" else 1)
    if args.issue <= 0 or parallel <= 0:
        ap.error("--issue and --max-parallel must be positive")
    if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_-]*", args.run_name):
        ap.error("--run-name must use letters, digits, underscores or hyphens")
    try:
        models = load_models(args.models)
        if not models:
            ap.error("No models selected; nothing to run")
        corpus = args.issues_dir.resolve()
        # Reuse the frozen loader's validation, without reading old artifacts.
        from local_issues import load_issue
        load_issue(corpus, args.issue)
        root = args.results_dir.resolve() / args.stage / args.run_name / f"issue_{args.issue}"
        if root == corpus or root in corpus.parents or corpus in root.parents:
            raise ValueError("Corpus and benchmark output must not overlap")
        targets = [root / directory_name(m["name"]) for m in models]
        for target in targets:
            if target.exists() or target.is_symlink():
                raise ValueError(f"Output already exists: {target}; choose a new run name")
        for target in targets:
            target.mkdir(parents=True, exist_ok=False)
    except (OSError, ValueError, yaml.YAMLError) as exc:
        ap.error(str(exc))
    failed = False
    with ThreadPoolExecutor(max_workers=parallel) as executor:
        jobs = [executor.submit(run_model, args.stage, args.issue, model, corpus, target)
                for model, target in zip(models, targets)]
        for job in as_completed(jobs):
            result = job.result()
            print(f"{result['model_name']}: {result['status']}", flush=True)
            failed |= result["status"] != "completed"
    return int(failed)


if __name__ == "__main__":
    raise SystemExit(main())
