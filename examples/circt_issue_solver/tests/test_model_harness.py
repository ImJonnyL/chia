"""Offline harness tests: all solver subprocesses are mocked."""
import importlib
import json
from pathlib import Path
from types import SimpleNamespace
import threading
import time

import pytest
import yaml

FLOW_DIR = Path(__file__).resolve().parents[1]


@pytest.fixture
def harness(monkeypatch):
    monkeypatch.syspath_prepend(str(FLOW_DIR))
    return importlib.import_module("benchmark_models")


def assessment(directory, status="clear", success=True, text="DECISION: CLEAR"):
    directory.mkdir(parents=True, exist_ok=True)
    runner = {"issue_number": 7, "model_name": directory.parent.name if directory.name == "assess" else directory.name,
              "model": "amazon-bedrock/test", "stage": "assess",
              "status": "completed", "return_code": 0}
    (directory / "runner.json").write_text(json.dumps(runner))
    (directory / "verdict.json").write_text(json.dumps({
        "status": status, "llm_phases": {"assess": {"success": success}}}))
    (directory / "llm_assess.md").write_text(text)
    return runner


def test_models_and_commands(harness, tmp_path):
    models = harness.load_models(FLOW_DIR / "models.yaml")
    assert models[0]["name"] == "kimi-k3"
    source = tmp_path / "models.yaml"
    source.write_text(yaml.safe_dump({"models": [
        {"name": "First / model", "model": "amazon-bedrock/one"},
        {"name": "Second", "model": "amazon-bedrock/two"}]}))
    models = harness.load_models(source)
    targets = [tmp_path / harness.directory_name(m["name"]) / "assess" for m in models]
    assert targets[0] != targets[1] and targets[0].parent.name == "First-model"
    for stage, flag in (("assess", "--assess-only"), ("full", "--issue")):
        cmd = harness.build_command(stage, 7, models[0], tmp_path / "corpus", targets[0])
        assert cmd[-2:] == [flag, "7"]
        assert cmd[cmd.index("--model") + 1] == "amazon-bedrock/one"
        assert cmd[cmd.index("--output-dir") + 1] == str(targets[0])
    source.write_text("models:\n- name: a/b\n  model: amazon-bedrock/one\n- name: a-b\n  model: amazon-bedrock/two\n")
    with pytest.raises(ValueError, match="Duplicate"):
        harness.load_models(source)


@pytest.mark.parametrize("contents", ["[]", "models: nope", "models: [{}]", "models: [{name: '...', model: amazon-bedrock/x}]", "models: [{name: x, model: other/x}]"])
def test_invalid_models(harness, tmp_path, contents):
    source = tmp_path / "models.yaml"
    source.write_text(contents)
    with pytest.raises(ValueError):
        harness.load_models(source)


@pytest.mark.parametrize("case", ["clear", "unclear", "not_a_bug", "empty", "failed", "missing", "malformed", "nonzero", "no_session"])
def test_structured_comparison(harness, tmp_path, case):
    from compare_assess import assessment_value
    folder = tmp_path / "m/assess"
    runner = assessment(folder, status=case if case in ("clear", "unclear", "not_a_bug") else "clear")
    if case == "empty":
        (folder / "llm_assess.md").write_text("")
    elif case == "failed":
        assessment(folder, success=False)
    elif case == "missing":
        (folder / "verdict.json").unlink()
    elif case == "malformed":
        (folder / "verdict.json").write_text("[]")
    elif case == "nonzero":
        runner["return_code"] = 1
    elif case == "no_session":
        assessment(folder, success=None)
    expected = case if case in ("clear", "unclear", "not_a_bug") else "assessment_error"
    assert assessment_value(folder, runner) == expected


@pytest.mark.parametrize("suffix", ["/assess", ""])
def test_passing_yaml(harness, tmp_path, capsys, suffix):
    from compare_assess import compare
    assessment(tmp_path / ("issue_7/good" + suffix))
    assessment(tmp_path / ("issue_7/wrong" + suffix), status="unclear")
    assessment(tmp_path / ("issue_7/failed" + suffix), text="")
    passing = compare(tmp_path, 7, "clear")
    assert passing == [{"name": "good", "model": "amazon-bedrock/test"}]
    assert yaml.safe_load((tmp_path / "passing_models.yaml").read_text())["models"] == passing
    assert "assessment_error" in capsys.readouterr().out


@pytest.mark.parametrize("stage", ["assess", "full"])
def test_bounded_batch_continues_and_protects_results(harness, tmp_path, monkeypatch, stage):
    corpus = tmp_path / "corpus/issue_7"
    corpus.mkdir(parents=True)
    (corpus / "issue.md").write_text("# Issue #7: Frozen\n\nbody\n")
    models = tmp_path / "models.yaml"
    models.write_text(yaml.safe_dump({"models": [
        {"name": f"m{i}", "model": f"amazon-bedrock/{i}"} for i in range(5)]}))
    lock = threading.Lock()
    active = peak = calls = 0

    def fake_run(command, **kwargs):
        nonlocal active, peak, calls
        assert kwargs["env"]["NO_WAIT"] == "0"
        with lock:
            active += 1
            peak = max(peak, active)
            calls += 1
        try:
            time.sleep(0.02)
            target = Path(command[command.index("--output-dir") + 1])
            kwargs["stdout"].write("mock stdout")
            kwargs["stderr"].write("mock stderr")
            if target.name == "m0":
                raise OSError("mock launch failure")
            # Do not replace the real runner metadata.
            (target / "verdict.json").write_text(json.dumps({"status": "clear", "llm_phases": {"assess": {"success": True}}}))
            (target / "llm_assess.md").write_text("DECISION: CLEAR")
            return SimpleNamespace(returncode=0)
        finally:
            with lock:
                active -= 1

    monkeypatch.setattr(harness.subprocess, "run", fake_run)
    monkeypatch.setenv("NO_WAIT", "1")
    argv = ["benchmark", stage, "--issue", "7", "--models", str(models),
            "--run-name", "test", "--issues-dir", str(corpus.parent),
            "--results-dir", str(tmp_path / "results"), "--max-parallel", "2"]
    monkeypatch.setattr("sys.argv", argv)
    assert harness.main() == 1
    assert calls == 5 and peak == 2
    root = tmp_path / "results" / stage / "test/issue_7"
    for i in range(5):
        target = root / f"m{i}"
        runner = json.loads((target / "runner.json").read_text())
        assert runner["status"] == ("failed" if i == 0 else "completed")
        assert runner["elapsed_seconds"] >= 0 and runner["finish_timestamp"] >= runner["start_timestamp"]
        assert (target / "stdout.log").read_text() == "mock stdout"
        assert (target / "stderr.log").read_text() == "mock stderr"
    with pytest.raises(SystemExit):
        harness.main()
    assert calls == 5


@pytest.mark.parametrize("stage,return_code,verdict", [
    ("full", 0, {"status": "fixed"}),
    ("full", 1, {"status": "fixed"}),
    ("full", 0, {"status": "error"}),
    ("full", 0, None),
    ("assess", 0, {"status": "clear"}),
])
def test_runner_outcomes(harness, tmp_path, monkeypatch, stage, return_code, verdict):
    target = tmp_path / "output"
    target.mkdir()
    def run(command, **kwargs):
        if verdict is not None:
            (target / "verdict.json").write_text(json.dumps(verdict))
        return SimpleNamespace(returncode=return_code)
    monkeypatch.setattr(harness.subprocess, "run", run)
    runner = harness.run_model(stage, 7, {"name": "test", "model": "amazon-bedrock/test"},
                               tmp_path / "corpus", target)
    assert runner["return_code"] == return_code
    expected = "completed" if stage == "full" and return_code == 0 and verdict == {"status": "fixed"} else "failed"
    assert runner["status"] == expected
    assert "llm_usage" not in runner
