#!/usr/bin/env bash
set -u
# Activate conda environment circtissues before running this script.
cd /home/ubuntu/chia/examples/circt_issue_solver
export CHIA_HEAD="$(hostname)"
export NO_WAIT=0
RERUN_DIR="$PWD/benchmark_results/assess/execution_error_reruns_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$RERUN_DIR"
echo "Results: $RERUN_DIR"
./fix_issues_submit.sh --backend opencode \
  --model amazon-bedrock/zai.glm-5 \
  --issues-dir "$PWD/issuestouse" \
  --output-dir "$RERUN_DIR/glm-5/issue_4354" --assess-only 4354
./fix_issues_submit.sh --backend opencode \
  --model amazon-bedrock/nvidia.nemotron-super-3-120b \
  --issues-dir "$PWD/issuestouse" \
  --output-dir "$RERUN_DIR/nemotron-3-super/issue_10571" --assess-only 10571
