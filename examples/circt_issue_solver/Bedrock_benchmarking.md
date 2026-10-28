# CIRCT benchmarking with OpenCode and AWS Bedrock

For OpenRouter through the same OpenCode agent, follow
[OpenRouter_benchmarking.md](OpenRouter_benchmarking.md). That guide uses a
separate cluster and model selection; the AWS instructions below remain Bedrock-specific.

This guide summarizes the benchmark changes and the tested authentication steps.
The existing assess → reproduce → fix → verify/regression → writeup pipeline,
MCP tools, and prompt files are preserved. See [BENCHMARK.md](BENCHMARK.md) for
additional accounting details and an example verdict. For multi-model runs,
complete setup steps 1–3, list models and run the preflight in step 4,
then follow step 8. Single-model runs in steps 5–7 are optional diagnostics.

## Files changed and why

Paths below are relative to `examples/circt_issue_solver/` unless noted.

| File | Purpose |
| --- | --- |
| `circt_issue_loop.py` | Select frozen local issues instead of querying GitHub, remove Vertex requirements, and persist benchmark accounting, including assess-only results. |
| `local_issues.py` | Read only `issue_<N>/issue.md` and select batch issues in numeric order. |
| `issue_task.py` | Reset and verify CIRCT before building, use OpenCode's built-in Bedrock provider, and capture phase metadata and failure windows. |
| `circt_util.py` | Resolve and verify local commit `5dc7f103`, without fetching or falling back to HEAD. |
| `cluster_opencode_bedrock.yaml` | Configure two OpenCode and two CIRCT workers on one host, with AWS configuration mounted read-only and no Google credentials or container SSH agent. |
| `fix_issues_submit.sh` | Remove GitHub-token and Vertex environment requirements. |
| `tests/test_benchmark.py` | Test input isolation, startup ordering, CLI selection, and accounting propagation offline. |
| `benchmark_models.py` | Run assess/full jobs with bounded subprocess concurrency and isolated model/stage outputs. |
| `compare_assess.py` | Compare structured classifications against an explicit reference and write passing models. |
| `models.yaml` | Editable model selection with human-readable names and full OpenCode IDs. |
| `tests/test_model_harness.py` | Offline tests for model selection, command construction, comparison and failure handling. |
| `BENCHMARK.md` | Document configuration, accounting provenance, and limitations. |
| `chia/models/opencode.py` (repository root) | Extend the existing export accounting to preserve reported zeroes and return timestamps, elapsed time, and AWS region. |
| `chia/models/tests/test_opencode.py` (repository root) | Add mocked multi-turn accounting and Bedrock metadata tests. |
| `docs/case-studies/circt-issue-solving.rst` (repository root) | Document the frozen-corpus benchmark. |
| `Bedrock_benchmarking.md` | Provide this practical setup and run guide. |

No GitHub Actions workflows or Dockerfiles were changed for this adaptation.
The harness and relevant solver/accounting tests passed 101 offline tests,
excluding nine live tests. See BENCHMARK.md for the test-environment workaround.

The export parser, token/cache/reasoning/cost accumulation, returned session IDs,
and per-phase `llm_usage` already existed. Added accounting includes session-ID
propagation, issue/phase/model/backend metadata, timestamps, region, aggregate
usage, verified CIRCT commit, and assess-only persistence. Unavailable metrics
remain unavailable rather than becoming zero.

## 1. Authenticate using AWS login

On the host:

```bash
export AWS_PROFILE=default
export AWS_REGION=us-east-1
export AWS_DEFAULT_REGION="$AWS_REGION"
export AWS_SDK_LOAD_CONFIG=1

aws login --profile default --remote
```

Open the URL printed by the CLI, complete browser authentication, and enter the
authorization code in the terminal. Do not include authorization codes in logs
or documentation. Confirm the identity:

```bash
aws sts get-caller-identity --profile default
```

This uses `aws login`, not `aws sso login`. The host stores login credentials in
its AWS login cache. The container must be able to read the profile and read/write
the login cache to refresh temporary credentials. The cluster mounts `.aws`
read-only, with a separate writable mount for `.aws/login/cache` only.
OpenCode's bundled login provider saves refreshed tokens there; a read-only
cache can work initially and then fail when refresh is needed. Recreate the
workers after changing mount options; restarting a container does not change
its mounts.
The temporary exported profile used during diagnosis is not needed for the
successful login test below and does not refresh automatically.

## 2. Start the CHIA cluster

Prerequisites: the existing `circtissues` environment with this checkout
installed, Docker, AWS CLI, and working SSH authentication to the head host.

```bash
conda activate circtissues
cd /home/ubuntu/chia/examples/circt_issue_solver
export CHIA_HEAD="$(hostname)"

ssh ubuntu@"$CHIA_HEAD" 'hostname'
chia up cluster_opencode_bedrock.yaml
```

Use your host's SSH username if it differs from `ubuntu`. CHIA uses host SSH even
when all workers are on the same machine. No SSH agent is required inside the
containers. Skip `chia up` if this cluster is already running.

The YAML forwards the AWS profile and region at container creation; changing
host exports later does not change running worker environments. It mounts
`${HOME}/.aws` at `/home/ray/.aws` read-only.

## 3. Check the CIRCT revision is available

```bash
for c in $(docker ps --format '{{.Names}}' \
  --filter "name=circt_issue_solver_worker_${USER}"); do
  docker exec "$c" git -c safe.directory=/workspace/circt \
    -C /workspace/circt rev-parse --verify '5dc7f103^{commit}'
done
```

Every worker must already have this commit locally. Before its first task, HEAD
may still be the image's baked revision. The task resets/cleans the source,
verifies HEAD, and then builds incrementally. The build directory is retained.
Assess-only skips building because it assesses source rather than reproducing
or fixing the issue. No revision is fetched automatically.

## 4. List models before choosing a benchmark set

From the activated environment in the example directory, identify the running
OpenCode containers and select one by its actual name:

```bash
docker ps --format '{{.Names}}' \
  --filter "name=circt_issue_solver_opencode_llm_${USER}"

# Replace this example if your container has a different name.
export OPENCODE_CONTAINER=circt_issue_solver_opencode_llm_ubuntu-1

docker exec "$OPENCODE_CONTAINER" opencode --version
docker exec "$OPENCODE_CONTAINER" opencode models amazon-bedrock
```

These commands make no model generation calls. OpenCode prints model IDs in
`provider/model` form; copy the complete ID into `models.yaml`. To refresh its
catalog if needed:

```bash
docker exec "$OPENCODE_CONTAINER" opencode models amazon-bedrock --refresh
```

`--refresh` updates the catalog cache from models.dev; it does not verify that
your AWS account can invoke each model. See the
[OpenCode CLI model-list documentation](https://opencode.ai/docs/cli/#models).

On the host, list Bedrock inference profiles in your selected region:

```bash
aws bedrock list-inference-profiles \
  --profile "$AWS_PROFILE" --region "$AWS_REGION" \
  --query 'inferenceProfileSummaries[].{Name:inferenceProfileName,ID:inferenceProfileId,Status:status,Type:type}' \
  --output table --no-cli-pager
```

For an optional broader list of foundation models that produce text:

```bash
aws bedrock list-foundation-models \
  --profile "$AWS_PROFILE" --region "$AWS_REGION" \
  --by-output-modality TEXT \
  --query 'modelSummaries[].{Provider:providerName,Name:modelName,ID:modelId,Streaming:responseStreamingSupported,Inference:inferenceTypesSupported}' \
  --output table --no-cli-pager
```

Both are listing APIs, not generation calls. The AWS lists and the OpenCode
catalog are discovery aids; listing permissions do not prove invocation
permissions, model access, or compatibility with the solver's tool use.
If a listing command is denied, it does not establish that generation is denied.
See AWS's [inference-profile listing](https://docs.aws.amazon.com/cli/latest/reference/bedrock/list-inference-profiles.html)
and [foundation-model listing](https://docs.aws.amazon.com/cli/latest/reference/bedrock/list-foundation-models.html).

Choose text/chat models compatible with tools. Prefer the actual supported
inference-profile ID when direct on-demand invocation is unsupported. Keep its
prefix exactly as listed (`us.`, `eu.`, `global.`, etc.); do not invent a prefix.
For example, the previously working ID in this setup was
`amazon-bedrock/us.moonshotai.kimi-k3`. Foundation-model IDs and
inference-profile IDs are different; adding `amazon-bedrock/` supplies the
OpenCode provider prefix, not a conversion between them.

### Preflight before a benchmark batch

After the cluster is running, do these checks before launching the batch,
particularly after a login expires. The PONG tests and isolated assessment
below make paid calls; the login and identity check do not generate responses.
Run from the activated `circtissues` environment in this example directory.

First refresh the host login and check it:

```bash
export AWS_PROFILE=default
export AWS_REGION=us-east-1
export AWS_DEFAULT_REGION="$AWS_REGION"
export AWS_SDK_LOAD_CONFIG=1

aws login --profile default --remote
aws sts get-caller-identity --profile default
```

Next require `PONG` and a `step_finish` event from both OpenCode containers:

```bash
for worker in \
  circt_issue_solver_opencode_llm_ubuntu-0 \
  circt_issue_solver_opencode_llm_ubuntu-1
do
  echo "$worker"
  docker exec \
    -e AWS_PROFILE=default \
    -e AWS_CONFIG_FILE=/home/ray/.aws/config \
    -e AWS_LOGIN_CACHE_DIRECTORY=/home/ray/.aws/login/cache \
    "$worker" \
    opencode run --format json \
    --model amazon-bedrock/moonshotai.kimi-k2.5 \
    'Reply with exactly PONG. Do not use tools.'
done
```

Use the actual container names from `docker ps` if yours differ. A lone
`step_start` is not success. These `docker exec -e` settings affect only the
test processes, not the running CHIA workers. Therefore, also check the actual
CHIA assess-only path, using a fresh directory to preserve earlier results:

```bash
mkdir -p benchmark_results/assess/preflight
PREFLIGHT_DIR=$(mktemp -d "$PWD/benchmark_results/assess/preflight/check.XXXXXX")
echo "Preflight results: $PREFLIGHT_DIR"

./fix_issues_submit.sh \
  --backend opencode \
  --model amazon-bedrock/moonshotai.kimi-k2.5 \
  --issues-dir "$PWD/issuestouse" \
  --output-dir "$PREFLIGHT_DIR" \
  --assess-only 10571

python -m json.tool "$PREFLIGHT_DIR/verdict.json"
```

Before starting step 8, confirm `llm_phases.assess.success` is `true`,
`llm_phases.assess.session_id` is nonempty, and `llm_assess.md` contains a real
assessment. Its classification may be `clear`, `unclear` or `not_a_bug`; this
check is about successful execution. Ray's "Job succeeded" message or a
`clear` status alone is insufficient because a failed empty response can fall
through to `clear` in the existing solver.

If credentials still fail in the CHIA assessment despite both PONG tests
succeeding, stop here: the worker environment needs checking. The explicit AWS
paths may need adding to `cluster_opencode_bedrock.yaml` and the workers
recreating; the preflight commands do not apply that configuration change.
A successful preflight verifies Kimi K2.5 at that moment, not every model or
credential refresh throughout a long run.

## 5. Run an assess-only local issue

This makes paid model calls. To preserve an existing result before rerunning:

```bash
if [ -d benchmark_results/assess/manual/issue_10571 ]; then
  cp -a benchmark_results/assess/manual/issue_10571 \
    "benchmark_results/assess/manual/issue_10571_backup_$(date +%Y%m%d_%H%M%S)"
fi

./fix_issues_submit.sh \
  --backend opencode \
  --model amazon-bedrock/us.moonshotai.kimi-k3 \
  --issues-dir "$PWD/issuestouse" \
  --assess-only 10571
```

Only `issuestouse/issue_10571/issue.md` is supplied as corpus input. Historical
assessments, patches, verdicts, and reproductions alongside it are not read.
Inspect the output:

```bash
cat benchmark_results/assess/manual/issue_10571/llm_assess.md
python -m json.tool benchmark_results/assess/manual/issue_10571/verdict.json
```

Require a real assessment transcript. A known failure-handling bug can label an
empty response `clear` after OpenCode exhausts retries; that is not a successful
assessment. Null session/usage fields together with an empty transcript warrant
checking the worker errors. This guide does not fix that bug.

If the loop fails credentials while the direct container test succeeds, compare
the Ray worker environment with the explicit settings in step 4. Those settings
may need adding to the cluster YAML and the workers recreating; they have not
been added by this documentation change.

The verdict's `circt_commit` records the actual full HEAD SHA. Check it:

```bash
python - <<'PY'
import json
with open("benchmark_results/assess/manual/issue_10571/verdict.json") as file:
    verdict = json.load(file)
print(verdict["circt_commit"])
assert verdict["circt_commit"].startswith("5dc7f103")
PY
```

## 6. Inspect token and cost accounting

```bash
python - <<'PY'
import json
with open("benchmark_results/assess/manual/issue_10571/verdict.json") as file:
    verdict = json.load(file)
fields = ("model", "backend", "circt_commit", "llm_usage", "llm_usage_total",
          "llm_phases", "cost_provenance")
print(json.dumps({key: verdict.get(key) for key in fields}, indent=2))
PY
```

`llm_usage` contains raw per-phase reported metrics; `llm_usage_total` sums only
reported values. Null means unavailable, not zero usage or zero cost.
`llm_phases` carries issue/phase/model/session/timestamp/region metadata for AWS
log reconciliation. `cost_usd` is OpenCode's session calculation, not an AWS
invoice amount. Failed retry sessions may require separate AWS-side accounting.

## 7. Run one full local issue or a batch

Once assess-only succeeds, run the full pipeline (paid model calls):

```bash
./fix_issues_submit.sh \
  --backend opencode \
  --model amazon-bedrock/us.moonshotai.kimi-k3 \
  --issues-dir "$PWD/issuestouse" \
  --issue 10571
```

For a deterministic batch instead:

```bash
./fix_issues_submit.sh \
  --backend opencode \
  --model amazon-bedrock/us.moonshotai.kimi-k3 \
  --issues-dir "$PWD/issuestouse" \
  --max-issues 5
```

Batch execution skips issue numbers already attempted in SQLite. An explicit
`--issue` runs the requested issue regardless of that table.

## 8. Select models and run the multi-model benchmark

From `/home/ubuntu/chia/examples/circt_issue_solver`, edit the existing selection:

```bash
nano models.yaml
```

The current selection contains five models that passed PONG on both workers:
Kimi K3, GLM 4.7, GLM 5, Nemotron 3 Super, and Kimi K2.5.
The three failing entries are retained as comments in `models.yaml`:
DeepSeek V3.2 was routed by OpenCode to an invalid `us.deepseek.v3.2` ID;
GLM 5.3 and Grok 4.7 returned account-access denials. DeepSeek R1 is a different
model and is not a replacement for V3.2. PONG verifies basic inference access,
not assessment tool use. Foundation-model availability checks and catalog
listings do not substitute for a successful call to the selected runtime ID.

Add chosen IDs from step 4 using this format:

```yaml
models:
  - name: kimi-k3
    model: amazon-bedrock/us.moonshotai.kimi-k3
```

Each entry needs a unique readable `name` and a complete `model` ID. Add 5–10
entries for your benchmark once their runtime access has been verified.
Names become sanitized directories; duplicate sanitized names are rejected.
Validate the selection offline before launching paid calls:

```bash
python - <<'PYMODELS'
from pathlib import Path
from benchmark_models import load_models
for entry in load_models(Path("models.yaml")):
    print(entry["name"], "->", entry["model"])
PYMODELS
```

Complete the step 4 preflight before launching Stage 1. Stage 1 makes paid
assess-only calls, with two concurrent submissions:

```bash
python benchmark_models.py assess \
  --issue 10571 \
  --models models.yaml \
  --run-name issue10571_v1 \
  --max-parallel 2
```

If the batch exits nonzero, inspect failed models' `runner.json`, `stdout.log`
and `stderr.log`; other queued models still run. There are no wrapper retries.
Existing output directories are protected: use a new run name for another
measurement rather than rerunning into the same assess directory.

Next, supply Claude's reference classification explicitly. This comparison is
offline; it does not call Claude or any other model:

```bash
python compare_assess.py \
  --run-dir benchmark_results/assess/issue10571_v1 \
  --issue 10571 \
  --expected clear

cat benchmark_results/assess/issue10571_v1/passing_models.yaml
```

Use `clear`, `not_a_bug` or `unclear` according to the reference assessment.
The comparison reads the structured verdict and rejects failed/empty assessments
as `assessment_error`, including failed calls that the core solver labels clear.
Review the printed table and passing list before launching Stage 2. If no models
match, the passing list is empty and full benchmarking will refuse to start.

Stage 2 makes paid full-flow calls for only the matching models:

```bash
python benchmark_models.py full \
  --issue 10571 \
  --models benchmark_results/assess/issue10571_v1/passing_models.yaml \
  --run-name issue10571_v1 \
  --max-parallel 1
```

Full flow includes its normal assess step again. Keep concurrency at one
initially. Neither stage adds CHIA workers; extra jobs wait for existing capacity.
Full attempts still enter the shared head-local SQLite database; its WAL/busy
timeout queues writers, but higher concurrency can hit capacity or lock limits.
Assess-only never records an attempt. Keep the SQLite database on local storage.

Results for each model are isolated under:

```text
benchmark_results/assess/issue10571_v1/issue_10571/<model-name>/
benchmark_results/full/issue10571_v1/issue_10571/<model-name>/
```

Each stage retains the solver's `verdict.json` and phase artifacts, plus
`runner.json`, `stdout.log` and `stderr.log`. LLM usage/cost remains authoritative
in `verdict.json`. Only frozen `issuestouse/issue_10571/issue.md` is corpus input;
old corpus solutions and other artifacts are never supplied to the model.

## Where single-model results live

Direct runs are persisted on the head under
`benchmark_results/assess/manual/issue_<N>/` for assess-only or
`benchmark_results/full/manual/issue_<N>/` for full cycles: `verdict.json`,
phase transcripts, the copied input, and any generated diff, writeup,
verification logs, and reproduction files. Full attempts also enter `issues.db`;
assess-only does not mark an attempt there.

Rerunning an issue overwrites corresponding files in its output directory;
it does not clear unrelated older files. The supplied `issuestouse/` corpus is
never overwritten. Back up an output directory before rerunning when prior
measurements must be retained.

Existing benchmark runs have been moved under `benchmark_results/assess/`;
PONG logs are under `assess/preflight/`. Historical `issue_logs/` files remain
in place. Explicit `--output-dir` overrides the automatic layout. Stored
commands in old `runner.json` files retain their original paths as history.
