# Frozen CIRCT benchmark with OpenCode and Bedrock

The driver reads only `issuestouse/issue_<N>/issue.md` (or `--issues-dir`),
verbatim. It never imports GitHub triage or requires `GITHUB_TOKEN`.
Batch candidates are ordered numerically, limited by `--max-issues`, and skip
numbers in the existing SQLite attempted-issue table. Explicit `--issue` and
`--assess-only` run the requested number regardless of that table.
Reference artifacts beside `issue.md` are never read or uploaded. Results go
to the separate `issue_logs/issue_<N>/`. Corpus issue paths cannot be symlinks,
and the corpus and output roots must not overlap.

The assess → reproduce → fix → verify/regression → writeup pipeline, MCP tools,
and prompt files are unchanged. `--replay-regression` remains a diagnostic for
artifacts produced in `issue_logs`, not a fresh benchmark run; never use it for
benchmark measurements. The default backend is still Claude; select
`--backend opencode` explicitly. Its default model is
`amazon-bedrock/moonshotai.kimi-k2.5`; `--model amazon-bedrock/<model-id>` overrides it.

Each CIRCT worker trusts its source checkout, resolves `5dc7f103` locally,
resets/cleans it, verifies `git rev-parse HEAD` against the resolved commit,
and only then builds. A missing revision stops the run with an error; there is
no fetch or fallback. The ignored incremental build directory survives. A
warm sentinel cannot skip the incremental build after a fresh reset.
Assess-only reads pinned source and skips building, as before; it now saves its
transcript and accounting in `issue_logs` without updating the attempted DB.
The full SHA from HEAD is persisted as `circt_commit`, including early returns.

## Accounting

Already present: `opencode export`, summed assistant-message input/output,
reasoning and cache counters, cost and turn count, `OpenCodeQueryResult.usage`
and `.session_id`, and per-phase `llm_usage` persistence.

Added: preserving explicitly reported zeroes while omitting unavailable fields;
worker-side UTC timestamps, elapsed time, and AWS region; propagation of session
ID and issue/phase/model/backend metadata into `llm_phases`; issue identity and
verified commit in every returned result; and `llm_usage_total` in `verdict.json`.
The aggregate sums only reported OpenCode phase values. An entirely unavailable
metric is `null`, not zero. A sum can be partial when a turn or phase omits a
metric. Raw per-phase `llm_usage` is the source of truth.

`cost_usd` is retained for compatibility. It is **OpenCode's reported session
cost calculation, not an AWS invoice amount**. No local pricing table or second
price calculation is added. OpenCode's own export may report zero when its model
catalog has no price; CHIA preserves what it reports.

Reconciliation uses issue, phase, full model ID, session ID, UTC start/end,
and the LLM worker's AWS region. No clean `requestMetadata` setting was found in
the installed OpenCode v2.0.16 build (no such symbol) or the documented
OpenCode/AI SDK Bedrock options. No provider fork, wrapper, or unverified tagging
option is added. Recheck support when changing image/OpenCode versions:
[OpenCode Bedrock provider](https://opencode.ai/docs/providers/#amazon-bedrock),
[AI SDK Bedrock options](https://ai-sdk.dev/providers/ai-sdk-providers/amazon-bedrock).

Failed pipeline phases retain their CHIA time window and earlier phase usage;
metrics/session IDs are unavailable if the backend raises before returning them.
The existing OpenCode retry/error behavior is unchanged: returned usage describes
the exported session returned by the backend, not discarded failed retry sessions.
Use AWS invocation logs to reconcile retries, failed calls, and billing. The
worker-side time window surrounds run/export; worker clocks should be synchronized.
Record image digests and `opencode --version` externally for repeat experiments
(the requested YAML deliberately uses `latest`).

A synthetic assess-only accounting excerpt (the full SHA below is illustrative):

```json
{
  "issue_number": 10571,
  "model": "amazon-bedrock/moonshotai.kimi-k2.5",
  "backend": "opencode",
  "circt_commit": "5dc7f103aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  "llm_usage": {
    "assess": {
      "input_tokens": 13, "output_tokens": 3, "reasoning_tokens": 1,
      "cache_read": 4, "cache_write": 0, "cost_usd": 0.03, "num_turns": 2
    }
  },
  "llm_phases": {
    "assess": {
      "issue_number": 10571, "phase": "assess",
      "model": "amazon-bedrock/moonshotai.kimi-k2.5", "backend": "opencode",
      "session_id": "ses_benchmark", "aws_region": "us-west-2",
      "start_timestamp": "2026-10-05T23:00:00+00:00",
      "end_timestamp": "2026-10-05T23:00:10+00:00", "elapsed_seconds": 10
    }
  },
  "llm_usage_total": {
    "input_tokens": 13, "output_tokens": 3, "reasoning_tokens": 1,
    "cache_read": 4, "cache_write": 0, "cost_usd": 0.03, "num_turns": 2
  },
  "cost_provenance": "cost_usd is OpenCode-reported session cost, not an AWS invoice amount"
}
```

## Setup and commands

Use the existing `circtissues` conda environment with this checkout installed.
The host must have Docker, AWS CLI, and CHIA's normal host SSH access configured.
No SSH agent is required inside either worker image. The selected AWS profile
must be readable by the LLM container UID, with model invocation permissions and
access to the chosen model in the selected region. Configure Bedrock model
invocation logging separately in AWS if reconciliation is required.
The CIRCT image must already contain `5dc7f103` and an SDK/build configuration
compatible with it. No real image build or model invocation was validated by the
offline tests. Existing LLVM/MLIR SDK and lit-gate exclusions remain unchanged;
`circt-verilog` is not one of the source-built target tools.

From the repository root:

```bash
conda activate circtissues
cd /home/ubuntu/chia/examples/circt_issue_solver

# 1. Select and authenticate/check AWS (SSO login only for an SSO profile).
export AWS_PROFILE=your-profile
export AWS_REGION=us-east-1
export AWS_DEFAULT_REGION="$AWS_REGION"
export AWS_SDK_LOAD_CONFIG=1
aws sso login --profile "$AWS_PROFILE"
aws sts get-caller-identity --profile "$AWS_PROFILE"

# 2. Bring up the cluster.
export CHIA_HEAD="$(hostname)"
chia up cluster_opencode_bedrock.yaml

# 3. Check both OpenCode containers; model listing makes no generation call.
for container in $(docker ps --format '{{.Names}}' --filter "name=circt_issue_solver_opencode_llm_${USER}"); do
  docker exec "$container" opencode --version
  docker exec "$container" opencode models amazon-bedrock
 done

# 4. Check the requested commit exists in every CIRCT container.
# Before the first task HEAD may still be the image's baked revision.
for container in $(docker ps --format '{{.Names}}' --filter "name=circt_issue_solver_worker_${USER}"); do
  docker exec "$container" git -c safe.directory=/workspace/circt -C /workspace/circt rev-parse --verify '5dc7f103^{commit}'
 done

# 5. Assess-only: this and the full run below make paid model calls.
./fix_issues_submit.sh --backend opencode --model amazon-bedrock/moonshotai.kimi-k2.5 --issues-dir "$PWD/issuestouse" --assess-only 10571

# Check the worker task left the checkout at the requested revision.
# Idle workers not assigned a task may still be at their baked HEAD.
for container in $(docker ps --format '{{.Names}}' --filter "name=circt_issue_solver_worker_${USER}"); do
  docker exec "$container" git -c safe.directory=/workspace/circt -C /workspace/circt rev-parse HEAD
 done
python -c 'import json; v=json.load(open("issue_logs/issue_10571/verdict.json")); print(v["circt_commit"]); assert v["circt_commit"].startswith("5dc7f103")'

# 6. Inspect the raw metrics, aggregate, and reconciliation metadata.
python -c 'import json; v=json.load(open("issue_logs/issue_10571/verdict.json")); print(json.dumps({k:v.get(k) for k in ("model", "backend", "circt_commit", "llm_usage", "llm_usage_total", "llm_phases", "cost_provenance")}, indent=2))'

# 7. Run one full local issue. This replaces that issue's assess-only verdict.
./fix_issues_submit.sh --backend opencode --model amazon-bedrock/moonshotai.kimi-k2.5 --issues-dir "$PWD/issuestouse" --issue 10571
```

Offline validation from the repository root (explicitly exclude all live tests):

```bash
python -m pytest chia/models/tests/test_opencode.py examples/circt_issue_solver/tests/test_benchmark.py -k 'not live' -q
python examples/circt_issue_solver/circt_issue_loop.py --help
bash -n examples/circt_issue_solver/fix_issues_submit.sh
```
