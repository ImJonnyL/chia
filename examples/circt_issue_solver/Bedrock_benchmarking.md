# CIRCT benchmarking with OpenCode and AWS Bedrock

This guide summarizes the benchmark changes and the tested authentication steps.
The existing assess → reproduce → fix → verify/regression → writeup pipeline,
MCP tools, and prompt files are preserved. See [BENCHMARK.md](BENCHMARK.md) for
additional accounting details and an example verdict.

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
| `BENCHMARK.md` | Document configuration, accounting provenance, and limitations. |
| `chia/models/opencode.py` (repository root) | Extend the existing export accounting to preserve reported zeroes and return timestamps, elapsed time, and AWS region. |
| `chia/models/tests/test_opencode.py` (repository root) | Add mocked multi-turn accounting and Bedrock metadata tests. |
| `docs/case-studies/circt-issue-solving.rst` (repository root) | Document the frozen-corpus benchmark. |
| `Bedrock_benchmarking.md` | Provide this practical setup and run guide. |

No GitHub Actions workflows or Dockerfiles were changed for this adaptation.
The implementation was validated with 75 offline tests, excluding live tests.

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
its AWS login cache. The container must be able to read that cache and profile.
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

## 4. Test OpenCode inside the container

The following model invocation incurs usage charges. It succeeded during
troubleshooting with the `default` login profile and returned `PONG`.

```bash
docker exec \
  -e AWS_PROFILE=default \
  -e AWS_CONFIG_FILE=/home/ray/.aws/config \
  -e AWS_LOGIN_CACHE_DIRECTORY=/home/ray/.aws/login/cache \
  circt_issue_solver_opencode_llm_ubuntu-1 \
  opencode run --format json \
  --model amazon-bedrock/us.moonshotai.kimi-k3 \
  'Reply with exactly PONG. Do not use tools.'
```

Use the actual container name from `docker ps` if yours differs. Expect a text
event containing `PONG`, followed by `step_finish` with usage counters. A lone
`step_start` event is not proof of a completed request; the successful tests took
tens of seconds before returning text.

`us.moonshotai.kimi-k3` is the inference-profile ID that worked in this setup.
Direct invocation of `moonshotai.kimi-k3` was rejected as unsupported for
on-demand throughput. The loop's OpenCode default remains
`amazon-bedrock/moonshotai.kimi-k2.5`; the commands here override it explicitly.

The explicit `docker exec -e` settings affect only this test process. They do
not update the running Ray workers. Refreshing the host login and setting these
paths made the test succeed; which change resolved the earlier failure was not
isolated. Automatic refresh over a long run remains unverified with the
read-only mount.

## 5. Run an assess-only local issue

This makes paid model calls. To preserve an existing result before rerunning:

```bash
if [ -d issue_logs/issue_10571 ]; then
  cp -a issue_logs/issue_10571 \
    "issue_logs/issue_10571_backup_$(date +%Y%m%d_%H%M%S)"
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
cat issue_logs/issue_10571/llm_assess.md
python -m json.tool issue_logs/issue_10571/verdict.json
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
with open("issue_logs/issue_10571/verdict.json") as file:
    verdict = json.load(file)
print(verdict["circt_commit"])
assert verdict["circt_commit"].startswith("5dc7f103")
PY
```

## 6. Inspect token and cost accounting

```bash
python - <<'PY'
import json
with open("issue_logs/issue_10571/verdict.json") as file:
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

## Where results live

Results are persisted on the head under `issue_logs/issue_<N>/`: `verdict.json`,
phase transcripts, the copied input, and any generated diff, writeup,
verification logs, and reproduction files. Full attempts also enter `issues.db`;
assess-only does not mark an attempt there.

Rerunning an issue overwrites corresponding files in its output directory;
it does not clear unrelated older files. The supplied `issuestouse/` corpus is
never overwritten. Back up an output directory before rerunning when prior
measurements must be retained.
