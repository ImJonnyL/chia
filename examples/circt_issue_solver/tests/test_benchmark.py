"""Offline benchmark transport, startup, and accounting integration tests."""
import importlib
import json
from pathlib import Path
from types import SimpleNamespace

import pytest

FLOW_DIR = Path(__file__).resolve().parents[1]


@pytest.fixture
def flow(monkeypatch):
    monkeypatch.syspath_prepend(str(FLOW_DIR))
    return importlib.import_module("circt_issue_loop")


def test_corpus_reads_only_issue_markdown(flow, tmp_path, monkeypatch):
    from local_issues import load_issue, select_issues
    corpus = tmp_path / "corpus"
    for n in (10, 2, 3):
        folder = corpus / f"issue_{n}"
        folder.mkdir(parents=True)
        (folder / "issue.md").write_text(f"# Issue #{n}: Frozen title\n- URL: https://example.org/{n}\n\nbody\n")
        (folder / "llm_fix.md").write_text("REFERENCE ANSWER MUST NOT BE READ")
        (folder / "verdict.json").write_text("REFERENCE VERDICT MUST NOT BE READ")
    original = Path.read_text
    read_paths = []

    def read_issue_only(path, *args, **kwargs):
        assert path.name == "issue.md"
        read_paths.append(path)
        return original(path, *args, **kwargs)

    monkeypatch.setattr(Path, "read_text", read_issue_only)
    issue = load_issue(corpus, 10)
    assert issue.title == "Frozen title" and issue.url == "https://example.org/10"
    assert issue.to_markdown() == original(corpus / "issue_10/issue.md")
    assert [i.number for i in select_issues(corpus, 1, {2})] == [3]
    assert len(read_paths) == 2  # no reads even for unselected candidates
    supplied = load_issue(FLOW_DIR / "issuestouse", 10571)
    assert supplied.number == 10571 and supplied.to_markdown()


def test_git_reset_checks_local_revision_and_head_before_build(flow, monkeypatch):
    import circt_util
    monkeypatch.setattr(circt_util.os.path, "isdir", lambda _: True)
    commands = []
    commit = "5dc7f103" + "a" * 32

    def git(cmd, **kwargs):
        commands.append(cmd)
        return SimpleNamespace(returncode=0, stdout=commit + "\n" if "rev-parse" in cmd else "", stderr="")

    monkeypatch.setattr(circt_util.subprocess, "run", git)
    result = circt_util.circt_git_reset("5dc7f103")
    assert result["success"] and result["circt_commit"] == commit
    assert [c[5:] for c in commands] == [
        ["rev-parse", "--verify", "5dc7f103^{commit}"],
        ["reset", "--hard", "5dc7f103"], ["clean", "-fd"], ["rev-parse", "HEAD"]]
    commands.clear()
    monkeypatch.setattr(circt_util.subprocess, "run", lambda *a, **kw:
                        SimpleNamespace(returncode=128, stdout="", stderr="missing local revision"))
    result = circt_util.circt_git_reset("5dc7f103")
    assert not result["success"] and "missing local revision" in result["log"]


@pytest.mark.parametrize("assess_only", [True, False])
def test_export_phase_and_verdict_accounting(flow, monkeypatch, tmp_path, assess_only):
    import ray
    import circt_util
    import issue_task
    from chia.base.tools.BashTool import BashTool
    from chia.chipyard.circt import BuildTool, LitTool
    from chia.models.opencode import OpenCodeLLM
    from chia.models.tests.test_opencode import _install_fake_subprocess, _step_start
    from local_issues import load_issue

    monkeypatch.delenv("GOOGLE_CLOUD_PROJECT", raising=False)
    monkeypatch.setenv("AWS_REGION", "us-west-2")
    monkeypatch.setattr(ray, "get_runtime_context", lambda: SimpleNamespace(get_node_id=lambda: "a" * 56))
    monkeypatch.setattr(issue_task, "get", lambda x: x)
    capture = {"calls": []}
    export = {"messages": [
        {"info": {"role": "assistant", "tokens": {"input": 10, "output": 2,
             "reasoning": 1, "cache": {"read": 4, "write": 0}}, "cost": 0.01},
         "parts": [{"type": "text", "text": "DECISION: CLEAR"}]},
        {"info": {"role": "assistant", "tokens": {"input": 3, "output": 1}, "cost": 0.02},
         "parts": [{"type": "text", "text": "DECISION: CLEAR"}]},
    ]}
    _install_fake_subprocess(monkeypatch, run_stdout=_step_start("ses_benchmark"),
                             export_obj=export, capture=capture)
    monkeypatch.setattr(OpenCodeLLM.prompt, "options", lambda **kw: SimpleNamespace(
        chia_remote=lambda llm, prompt, tools: llm.prompt(prompt, tools)))
    class Tool:
        def __init__(self, name, **kw):
            self.name, self.hostname, self.port = name, "mock-host", 8000
        def stop(self):
            pass
    for cls, module in ((BashTool, "chia.base.tools.BashTool"),
                        (BuildTool, "chia.chipyard.circt"), (LitTool, "chia.chipyard.circt")):
        monkeypatch.setattr(importlib.import_module(module), cls.__name__, Tool)
    events = []
    commit = "5dc7f103" + "a" * 32
    monkeypatch.setattr(circt_util, "circt_trust_source", lambda:
                        events.append("trust") or {"success": True})
    monkeypatch.setattr(circt_util, "circt_git_reset", lambda ref:
                        events.append("reset:" + ref) or {"success": True, "circt_commit": commit})
    monkeypatch.setattr(circt_util, "circt_warm_build", lambda *a, **kw:
                        events.append("warm") or {"success": True, "warmed": False})
    monkeypatch.setattr(circt_util, "circt_ninja_build", lambda *a, **kw:
                        events.append("build") or {"success": True, "log_tail": "mock build"})
    script_results = iter([1, 0, 0])
    monkeypatch.setattr(circt_util, "circt_run_script", lambda *a:
                        {"exit_code": next(script_results), "log_tail": "mock repro"})
    monkeypatch.setattr(circt_util, "circt_capture_diff", lambda *a:
                        {"diff": "mock diff", "added": 1, "removed": 0})
    monkeypatch.setattr(circt_util, "circt_lit_gate_paths", lambda: ["test/Mock"])
    lit_calls = iter([False, False, True])  # gate, focused failure log, repaired gate
    monkeypatch.setattr(circt_util, "circt_run_lit", lambda *a, **kw:
                        {"success": (ok := next(lit_calls)), "passed": int(ok),
                         "failed": int(not ok), "failures": [] if ok else ["CIRCT :: Mock/test.mlir"],
                         "log_tail": "mock lit"})
    cfg = dict(flow.CFG, backend="opencode", model="amazon-bedrock/moonshotai.kimi-k2.5",
               repro_dir=str(tmp_path / "generated"), repro_path=str(tmp_path / "generated/repro.sh"))
    issue = load_issue(FLOW_DIR / "issuestouse", 10571)
    res = issue_task.run_issue_remote(issue.to_markdown(), issue.number, cfg, assess_only=assess_only)
    assert res["circt_commit"] == commit
    assert events[:2] == ["trust", "reset:5dc7f103"]
    assert events[2:4] == ([] if assess_only else ["warm", "build"])
    phases = ["assess"] if assess_only else ["assess", "repro", "fix", "regression", "writeup"]
    assert list(res["logs"]) == phases
    for phase in phases:
        blob = res["logs"][phase]
        assert blob["session_id"] == "ses_benchmark"
        assert blob["issue_number"] == 10571 and blob["phase"] == phase
        assert blob["aws_region"] == "us-west-2"
        assert blob["start_timestamp"] <= blob["end_timestamp"]
        assert blob["usage"] == {"input_tokens": 13, "output_tokens": 3, "reasoning_tokens": 1,
                                 "cache_read": 4, "cache_write": 0, "cost_usd": 0.03, "num_turns": 2}
    for call in capture["calls"]:
        if call["sub"] == "run":
            perms = call["config"]["permission"]
            assert perms["*"] == "deny" and "provider" not in call["config"]
            assert all(k == "*" or k.startswith(("bash_", "build_", "lit_")) for k in perms)
    monkeypatch.setattr(flow, "ARTIFACT_DIR", tmp_path / "outputs")
    recorded = []
    monkeypatch.setattr(flow.db, "record", lambda *args: recorded.append(args))
    flow._persist(issue, res, record_db=not assess_only)
    verdict = json.loads((tmp_path / "outputs/issue_10571/verdict.json").read_text())
    assert verdict["llm_usage"] == {p: res["logs"][p]["usage"] for p in phases}
    assert verdict["llm_usage_total"] == {k: v * len(phases) for k, v in res["logs"]["assess"]["usage"].items()}
    assert verdict["llm_phases"]["assess"]["session_id"] == "ses_benchmark"
    assert verdict["model"] == cfg["model"] and verdict["backend"] == "opencode"
    assert verdict["circt_commit"] == commit and bool(recorded) == (not assess_only)


def test_persist_missing_usage(flow, monkeypatch, tmp_path):
    from local_issues import LocalIssue
    monkeypatch.setattr(flow, "ARTIFACT_DIR", tmp_path)
    result = {"backend": "opencode", "logs": {
        "assess": {"backend": "opencode", "usage": {"input_tokens": 0}},
        "repro": {"backend": "opencode", "usage": None}}}
    flow._persist(LocalIssue(1, "mock", None, "frozen"), result, record_db=False)
    verdict = json.loads((tmp_path / "issue_1/verdict.json").read_text())
    assert verdict["llm_usage_total"]["input_tokens"] == 0
    assert verdict["llm_usage_total"]["cost_usd"] is None
    assert verdict["llm_usage"]["assess"] == {"input_tokens": 0}


@pytest.mark.parametrize("mode", ["--issue", "--assess-only", "batch"])
def test_cli_uses_local_corpus_without_github_or_vertex(flow, monkeypatch, tmp_path, mode):
    import sys
    monkeypatch.delenv("GITHUB_TOKEN", raising=False)
    monkeypatch.delenv("GOOGLE_CLOUD_PROJECT", raising=False)
    monkeypatch.setattr(flow.ray, "init", lambda **kw: None)
    monkeypatch.setattr(flow.db, "init_db", lambda *a: None)
    monkeypatch.setattr(flow.db, "close_db", lambda: None)
    monkeypatch.setattr(flow.db, "attempted_numbers", lambda: set())
    received = []
    def remote(markdown, number, cfg, **kwargs):
        received.append((markdown, number, cfg, kwargs))
        return {"status": "mock", "logs": {}}
    monkeypatch.setattr(flow.run_issue_remote, "chia_remote", remote)
    monkeypatch.setattr(flow, "get", lambda res: res)
    monkeypatch.setattr(flow, "chia_wait", lambda pending, **kw: (pending, []))
    monkeypatch.setattr(flow, "_persist", lambda *a, **kw: None)
    args = ["driver", "--backend", "opencode", "--model", "amazon-bedrock/mock"]
    corpus = tmp_path / "corpus"
    folder = corpus / "issue_10571"
    folder.mkdir(parents=True)
    markdown = "# Issue #10571: Frozen\n\nunchanged body\n"
    (folder / "issue.md").write_text(markdown)
    (folder / "llm_fix.md").write_text("DO NOT READ")
    args += ["--issues-dir", str(corpus)]
    args += [mode, "10571"] if mode != "batch" else ["--max-issues", "1"]
    monkeypatch.setattr(sys, "argv", args)
    flow.main()
    assert len(received) == 1 and received[0][:2] == (markdown, 10571)
    assert received[0][2]["model"] == "amazon-bedrock/mock"
    assert "vertex" not in received[0][2]
    assert "triage" not in sys.modules


def test_worker_missing_commit_stops_before_build_or_llm(flow, monkeypatch):
    import ray
    import circt_util
    import issue_task
    monkeypatch.setattr(ray, "get_runtime_context", lambda: SimpleNamespace(get_node_id=lambda: "a" * 56))
    monkeypatch.setattr(circt_util, "circt_trust_source", lambda: {"success": True})
    monkeypatch.setattr(circt_util, "circt_git_reset", lambda ref:
                        {"success": False, "log": "missing revision " + ref})
    monkeypatch.setattr(circt_util, "circt_warm_build", lambda *a, **kw: pytest.fail("must not build"))
    result = issue_task.run_issue_remote("frozen", 1, flow.CFG)
    assert result["status"] == "error" and "5dc7f103" in result["notes"]
    assert result["circt_commit"] is None and result["logs"] == {}


def test_failed_phase_still_persists_accounting_window(flow, monkeypatch, tmp_path):
    import ray
    import circt_util
    import issue_task
    from chia.models.opencode import OpenCodeLLM
    from local_issues import LocalIssue
    monkeypatch.setattr(ray, "get_runtime_context", lambda: SimpleNamespace(get_node_id=lambda: "a" * 56))
    monkeypatch.setattr(circt_util, "circt_trust_source", lambda: {"success": True})
    monkeypatch.setattr(circt_util, "circt_git_reset", lambda ref:
                        {"success": True, "circt_commit": "5dc7f103" + "a" * 32})
    class Tool:
        def __init__(self, name, **kw):
            self.name = name
        def stop(self):
            pass
    monkeypatch.setattr(importlib.import_module("chia.base.tools.BashTool"), "BashTool", Tool)
    def fail(*args, **kwargs):
        raise RuntimeError("mock provider failure")
    monkeypatch.setattr(OpenCodeLLM.prompt, "options", lambda **kw: SimpleNamespace(chia_remote=fail))
    res = issue_task.run_issue_remote("frozen", 1, dict(flow.CFG, backend="opencode"), assess_only=True)
    assert res["status"] == "error"
    log = res["logs"]["assess"]
    assert log["start_timestamp"] <= log["end_timestamp"]
    assert log["usage"] is None and log["session_id"] is None
    monkeypatch.setattr(flow, "ARTIFACT_DIR", tmp_path)
    flow._persist(LocalIssue(1, "mock", None, "frozen"), res, record_db=False)
    verdict = json.loads((tmp_path / "issue_1/verdict.json").read_text())
    assert verdict["llm_phases"]["assess"]["end_timestamp"] == log["end_timestamp"]
    assert verdict["llm_usage_total"]["cost_usd"] is None
