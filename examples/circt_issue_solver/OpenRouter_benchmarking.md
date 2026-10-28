# OpenRouter benchmarks through OpenCode

Use this guide for OpenRouter; use [Bedrock_benchmarking.md](Bedrock_benchmarking.md)
for AWS login, regions, and inference profiles. Both use `--backend opencode`,
the same CIRCT tools, frozen corpus, and assessment harness. OpenRouter uses
`openrouter/<author>/<model>` IDs; Bedrock uses `amazon-bedrock/<runtime-id>`.
Do not mix provider selections in a batch unless workers have both credentials.

## 1. Prepare the account and credential file

Create an API key in [OpenRouter's key settings](https://openrouter.ai/settings/keys)
and ensure the account has credits and permission to use your chosen model.
Use a spending limit appropriate to the experiment. Never put the key in YAML,
Git, command arguments, or chat. No AWS login or GitHub token is needed for the
frozen local corpus.

From a Bash terminal on the single CHIA host:

```bash
conda activate circtissues
cd /home/ubuntu/chia/examples/circt_issue_solver
export CHIA_HEAD="$(hostname)"
export OPENROUTER_ENV_FILE="$HOME/.config/chia/openrouter.env"

# First-time creation only. Enter the key at the hidden prompt.
# Do not run with shell tracing (set -x) enabled.
mkdir -p "$(dirname "$OPENROUTER_ENV_FILE")"
if [ -e "$OPENROUTER_ENV_FILE" ]; then
  echo 'Credential file exists; keep it or rotate it separately.'
else
  (
    set +x
    umask 077
    read -rsp 'OpenRouter API key: ' openrouter_key
    printf '\n'
    test -n "$openrouter_key" || exit 1
    printf 'OPENROUTER_API_KEY=%s\n' "$openrouter_key" > "$OPENROUTER_ENV_FILE"
    unset openrouter_key
  )
fi
```

Keep this file readable only by you. The YAML passes its **path**, rather than
its contents, to Docker's `--env-file`. Only the LLM containers receive the key;
it is absent from the YAML and submitted model arguments. Docker administrators
can inspect container environment variables. The absolute file path must exist
on `CHIA_HEAD` (this configuration is for one host).

## 2. Start the OpenRouter workers

Finish or stop existing jobs before switching providers. Only one CHIA cluster
should run on this host at a time. If Bedrock is running, stop it first:

```bash
chia down cluster_opencode_bedrock.yaml
```

Start OpenRouter:

```bash
test -r "$OPENROUTER_ENV_FILE" || exit 1
chia up cluster_opencode_openrouter.yaml
```

This reuses `chia-opencode` and `chia-circt`; there is no new Python dependency,
Dockerfile, or custom provider package. OpenCode supplies its built-in OpenRouter
provider. First use may download its SDK package and public model catalog, so
workers need outbound HTTPS to OpenRouter and package/catalog services.
Existing containers retain their environment: after key rotation, stop jobs,
run `chia down cluster_opencode_openrouter.yaml`, and start it again.

## 3. Check the catalog, then make two small calls

Select the model once for this terminal. GLM 5.3 is only an example; replace the
value with any supported OpenRouter author/model ID:

```bash
export OPENROUTER_MODEL=openrouter/z-ai/glm-5.3
```

All commands below use that variable. OpenRouter lists GLM 5.3
as [`z-ai/glm-5.3`](https://openrouter.ai/z-ai/glm-5.3), so its OpenCode ID is
`openrouter/z-ai/glm-5.3`. A catalog entry does not prove account access or tool
compatibility. Check the actual worker version and catalog:

```bash
worker="circt_issue_solver_openrouter_llm_${USER}-0"
docker exec "$worker" opencode --version
docker exec "$worker" opencode models openrouter
```

Use `docker ps --format '{{.Names}}'` to check worker names if they differ.
If the model is missing, stop here and investigate the catalog/OpenCode version;
do not silently substitute another model.

These next commands make **paid calls** on both workers:

```bash
OPENROUTER_TEST_CONFIG=$(python - <<'PYCONFIG'
import json, os
model = os.environ["OPENROUTER_MODEL"]
print(json.dumps({"model": model, "small_model": model}))
PYCONFIG
)
for index in 0 1; do
  worker="circt_issue_solver_openrouter_llm_${USER}-${index}"
  docker exec "$worker" sh -c 'test -n "$OPENROUTER_API_KEY"' || break
  docker exec -e "OPENCODE_CONFIG_CONTENT=$OPENROUTER_TEST_CONFIG" \
    "$worker" opencode run --format json \
    --title 'CHIA connectivity check' --model "$OPENROUTER_MODEL" \
    'Reply with exactly PONG. Do not use tools.' || break
done
```

Require `PONG`, a `step_finish` event, and no errors from **both** workers.
Never print the environment or credential file to diagnose authentication.
A lone `step_start` or exit status zero is insufficient.

## 4. Run one assessment through CHIA

For a single model, pass `--model "$OPENROUTER_MODEL"` directly as below.
Alternatively, `--models models_openrouter.yaml` loads a reusable multi-model
selection. Edit each entry's `name` and `model` to select other models; that file
is an example, not a hardcoded runtime requirement. These two options are
mutually exclusive. Validate a YAML selection without calling a model:

```bash
python - <<'PY'
from pathlib import Path
from benchmark_models import load_models
print(load_models(Path('models_openrouter.yaml')))
PY
```

Then make a paid assessment using a fresh run name:

```bash
python benchmark_models.py assess \
  --issue 10571 --model "$OPENROUTER_MODEL" \
  --run-name openrouter_smoke_v1 --max-parallel 1
```

With `--model`, output names are derived from the full selected ID (slashes
and punctuation become hyphens). For the GLM example, inspect
`benchmark_results/assess/openrouter_smoke_v1/issue_10571/openrouter-z-ai-glm-5-3/`.
With `--models`, directories instead use the YAML `name`, as in older runs.
`runner.json` must say `completed`, `llm_phases.assess.success` in `verdict.json`
must be true, the session ID must be nonempty, and `llm_assess.md` must contain a
real assessment. Inspect the transcript for tool calls when assessing tool use;
a PONG response tests inference only. Classifications `clear`, `unclear`, and
`not_a_bug` can all represent successful assessments. The harness rejects empty
or failed assessments even when the underlying solver labels them `clear`.
Costs in `verdict.json` are OpenCode-reported estimates; reconcile billing with
OpenRouter's activity dashboard. CHIA supplies a fixed session title so
OpenCode need not call a model to generate one. The selected model is also
explicitly applied to `small_model` and every built-in agent (including title,
summary, and compaction), plus the primary CHIA agent. Inherited inline model
settings are replaced with CHIA's generated config. These rules apply to every
explicitly selected model, not only GLM or OpenRouter. Calls without an explicit
model retain OpenCode's configured defaults.

Other required background calls can still incur charges, and exported session
usage may omit background costs. Check OpenRouter activity for billing. Older
runs left the title model unset and OpenCode selected Nano Banana 2.1, causing
additional charges. The PONG command above also supplies a fixed title and
sets its model from the same variable. Changing a YAML file alone does not
change that terminal variable; keep the selected value consistent.

## 5. Assess all 16 frozen issues

After the smoke assessment passes, this makes paid assessments for each frozen
issue, sequentially, without starting reproduction/fix/build phases. It uses
explicit issue IDs so historical SQLite attempts do not skip any issue.
Choose a new run name each time; existing outputs are protected.

```bash
(
  set -euo pipefail
  run_name=openrouter_all16_v1
  mapfile -t issue_ids < <(python - <<'PY'
from pathlib import Path
from local_issues import select_issues
for issue in select_issues(Path('issuestouse'), 1000, []):
    print(issue.number)
PY
  )
  test "${#issue_ids[@]}" -eq 16
  test ! -e "benchmark_results/assess/$run_name"
  for issue in "${issue_ids[@]}"; do
    python benchmark_models.py assess \
      --issue "$issue" --model "$OPENROUTER_MODEL" \
      --run-name "$run_name" --max-parallel 1
  done
)
```

The loop stops at the first failed assessment; inspect its logs before continuing.
Review all verdicts and transcripts. Each issue has an isolated directory under
`benchmark_results/assess/<run-name>/issue_<N>/<sanitized-model-id>/`.
This is an assessment batch, not 16 full solving attempts.

For a larger test of one issue, use `benchmark_models.py full` with the same
`--issue`, `--model "$OPENROUTER_MODEL"`, a fresh `--run-name`, and `--max-parallel 1` after reviewing
the assessment. This incurs model calls and CIRCT builds, and records a full
attempt in SQLite. It can stop early if the assessment declines the issue.

## Provider reference

| Setting | OpenRouter | AWS Bedrock |
|---|---|---|
| Cluster | `cluster_opencode_openrouter.yaml` | `cluster_opencode_bedrock.yaml` |
| Model selection | `models_openrouter.yaml` | `models.yaml` |
| Authentication | `OPENROUTER_API_KEY` via Docker env-file | AWS profile/login cache |
| ID format | `openrouter/z-ai/glm-5.3` | `amazon-bedrock/us.moonshotai.kimi-k3` |
| Billing | OpenRouter account | AWS account |

See [OpenCode provider setup](https://opencode.ai/docs/providers/#openrouter).
The direct CHIA `OpenRouterLLM` connector is separate and is not used by this flow.
