#!/usr/bin/env bash
# Submit the circt_issue_solver flow as a job via `chia job submit` so its driver
# logs appear in the Ray dashboard (Jobs view) and via `chia job logs <id>`.
#
# Why this vs. `python circt_issue_loop.py`: running the driver directly also
# registers a Ray job, but as a DRIVER-type job whose stdout/stderr the job
# server does NOT capture. Only `chia job submit` (SUBMISSION) jobs get
# retrievable, dashboard-visible logs.
#
# Run on the host head in the activated environment. Uses the local corpus;
# no GitHub token is required. AWS credentials belong to the LLM containers.
# NO_WAIT=1 detaches; override CIRCT_SOLVER_PY / CIRCT_SOLVER_CHIA as needed.
set -euo pipefail

ADDR="${RAY_JOB_ADDR:-http://localhost:8265}"
FLOW_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PYBIN="${CIRCT_SOLVER_PY:-python}"
CHIABIN="${CIRCT_SOLVER_CHIA:-chia}"

WAIT_FLAG=()
[ "${NO_WAIT:-0}" = "1" ] && WAIT_FLAG=(--no-wait)

exec "$CHIABIN" job submit \
  --address "$ADDR" \
  "${WAIT_FLAG[@]}" \
  -- "$PYBIN" "$FLOW_DIR/circt_issue_loop.py" "$@"
