# Frozen CIRCT benchmark with OpenCode and Bedrock

The driver reads only `issuestouse/issue_<N>/issue.md` (or `--issues-dir`),
verbatim. It never imports GitHub triage or requires `GITHUB_TOKEN`.
Batch candidates are ordered numerically, limited by `--max-issues`, and skip
numbers in the existing SQLite attempted-issue table. Explicit `--issue` and
`--assess-only` run the requested number regardless of that table.
Reference artifacts beside `issue.md` are never read or uploaded. Results go
to the separate `benchmark_results/full/manual/issue_<N>/`. Corpus issue paths cannot be symlinks,
and the corpus and output roots must not overlap.

The assess → reproduce → fix → verify/regression → writeup pipeline, MCP tools,
and prompt files are unchanged. `--replay-regression` remains a diagnostic for
artifacts from a previous full run (or legacy `issue_logs` via `--output-dir`), not a fresh benchmark run; never use it for
benchmark measurements. The default backend is still Claude; select
`--backend opencode` explicitly. Its default model is
`amazon-bedrock/moonshotai.kimi-k2.5`; `--model amazon-bedrock/<model-id>` overrides it.

Each CIRCT worker trusts its source checkout, resolves `5dc7f103` locally,
resets/cleans it, verifies `git rev-parse HEAD` against the resolved commit,
and only then builds. A missing revision stops the run with an error; there is
no fetch or fallback. The ignored incremental build directory survives. A
warm sentinel cannot skip the incremental build after a fresh reset.
Assess-only reads pinned source and skips building, as before; it now saves its
transcript and accounting in `benchmark_results/assess/manual` without updating the attempted DB.
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
python -c 'import json; v=json.load(open("benchmark_results/assess/manual/issue_10571/verdict.json")); print(v["circt_commit"]); assert v["circt_commit"].startswith("5dc7f103")'

# 6. Inspect the raw metrics, aggregate, and reconciliation metadata.
python -c 'import json; v=json.load(open("benchmark_results/assess/manual/issue_10571/verdict.json")); print(json.dumps({k:v.get(k) for k in ("model", "backend", "circt_commit", "llm_usage", "llm_usage_total", "llm_phases", "cost_provenance")}, indent=2))'

# 7. Run one full local issue. This replaces that issue's assess-only verdict.
./fix_issues_submit.sh --backend opencode --model amazon-bedrock/moonshotai.kimi-k2.5 --issues-dir "$PWD/issuestouse" --issue 10571
```

Offline validation from the repository root (explicitly exclude all live tests):

```bash
python -m pytest chia/models/tests/test_opencode.py examples/circt_issue_solver/tests/test_benchmark.py -k 'not live' -q
python examples/circt_issue_solver/circt_issue_loop.py --help
bash -n examples/circt_issue_solver/fix_issues_submit.sh
```

## Multi-model harness

Run from `examples/circt_issue_solver` in the existing activated environment.
Edit `models.yaml` to include the desired 5–10 Bedrock models, each with a unique
human-readable `name` and complete `amazon-bedrock/...` OpenCode model ID. The
example includes only the previously tested Kimi ID; it does not guess which
other models your account can invoke. PyYAML is already a CHIA dependency.

```bash
# Stage 1 (paid calls): bounded assess-only submissions, default concurrency 2.
python benchmark_models.py assess \
  --issue 10571 --models models.yaml --run-name issue10571_v1 --max-parallel 2

# Offline checkpoint: supply Claude's reference classification explicitly.
python compare_assess.py \
  --run-dir benchmark_results/assess/issue10571_v1 --issue 10571 --expected clear

# Stage 2 (paid calls): explicitly run only matching models, default concurrency 1.
python benchmark_models.py full \
  --issue 10571 --models benchmark_results/assess/issue10571_v1/passing_models.yaml \
  --run-name issue10571_v1 --max-parallel 1
```

Both stages use the existing `fix_issues_submit.sh` and frozen `issuestouse`
corpus, configurable with `--issues-dir`. Full flow performs its own assessment
again. No phase is skipped; prompts, pinned CIRCT commit `5dc7f103`, provider,
accounting, reset/build behavior and existing internal retries are unchanged.
The wrapper adds no retries, starts no workers, and performs no GitHub queries.

Outputs are under
`benchmark_results/<assess|full>/<run-name>/issue_<N>/<sanitized-model-name>/`.
Each directory retains the solver's original artifacts and accounting, plus
`runner.json`, `stdout.log` and `stderr.log`. Runner metadata contains the
argument-vector command, issue/model/stage, UTC start/finish timestamps, elapsed
seconds, subprocess return code and status; it does not calculate LLM usage or
cost. `--results-dir` overrides the benchmark results root. Defaults resolve
relative to the scripts, so changing the invocation working directory does not
change the default corpus/results locations.

Existing model/stage targets cause an error before any jobs are launched,
including successful earlier runs. Use a new run name for another measurement;
there is no deletion, overwrite or hidden resume. Sanitized directory collisions
are rejected. A failed model is retained and the remaining queue continues; the
batch exits nonzero if any model fails. The wrapper forces `NO_WAIT=0`, because
detached submission cannot measure completion. A zero subprocess exit without a
valid solver verdict is also failed, covering caught driver exceptions.

Assessment comparison reads `verdict.json`'s structured `status`, with exact
labels `clear`, `not_a_bug`, `unclear`. It checks runner completion, return code,
and nonempty `llm_assess.md` without extracting a classification from prose.
Missing/malformed artifacts or unsuccessful phases become `assessment_error`.
The driver now also persists the existing phase `success` flag in `llm_phases`;
this detects failed OpenCode calls even if the solver's unchanged fallback
classification says `clear`. Older results without the flag require a session ID
as evidence of a returned session. A successful but unparseable decision footer
still follows the core solver's existing fallback semantics. Comparison writes
`passing_models.yaml` (possibly an empty list), and never starts full flow.

The solver supports an exact single-issue `--output-dir PATH` override and
persists the existing phase success flag. Without the override, direct assess
output goes to `benchmark_results/assess/manual/issue_<N>/` and full output to
`benchmark_results/full/manual/issue_<N>/`. The corpus/output non-overlap check also
applies to the override. Unlike the harness, direct solver invocations retain
their existing overwrite behavior.

Concurrency is bounded by `--max-parallel` and actual existing CHIA resources;
extra subprocesses wait rather than adding workers. Full attempts still use the
head-local `issues.db`, and explicit `--issue` bypasses attempted-issue filtering.
Assess-only never records an attempt. SQLiteNode already uses WAL, a 30-second
busy timeout and `BEGIN IMMEDIATE` writes, so writers queue on a local filesystem.
Keep full concurrency at one initially; higher concurrency can exhaust worker
capacity or the database busy timeout. Do not put the WAL database on NFS.

Offline tests mock all solver subprocesses and model calls:

```bash
python -m pytest examples/circt_issue_solver/tests chia/models/tests/test_opencode.py -k 'not live' -q
python -m compileall -q examples/circt_issue_solver
bash -n examples/circt_issue_solver/fix_issues_submit.sh
```

Run the validation commands above from the repository root.

In this checkout's offline validation environment, optional profiler discovery
attempted to auto-start Ray during decorated local function calls. Validation
used `RAY_ENABLE_AUTO_CONNECT=0` and a temporary pytest fixture outside the
repository that mocked `chia.trace.profiler.get_collector` to return `None`.
Solver/provider calls remained covered by the existing mocked tests; no runtime
profiler changes or paid calls were made. Pytest was installed under `/tmp` only
because the existing conda environments did not include it.

Assessment and full-cycle outputs now have separate top-level folders under
`benchmark_results`. Historical `issue_logs` reference artifacts were left in
place; use an explicit `--output-dir` to replay one of those older artifacts.
