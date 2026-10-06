"""Frozen issue corpus input. Never read sibling reference artifacts."""
from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
import re
from typing import Iterable


@dataclass(frozen=True)
class LocalIssue:
    """Issue metadata plus the unmodified frozen Markdown."""

    number: int
    title: str
    url: str | None
    markdown: str

    def to_markdown(self) -> str:
        """Return the original issue text without re-rendering."""
        return self.markdown


def load_issue(issues_dir: Path, number: int) -> LocalIssue:
    """Read only issue_<number>/issue.md; reject symlinks and mismatched headings."""
    if number <= 0:
        raise ValueError("issue number must be positive")
    directory = Path(issues_dir) / f"issue_{number}"
    path = directory / "issue.md"
    if directory.is_symlink() or path.is_symlink():
        raise ValueError(f"corpus issue paths must not be symlinks: {path}")
    markdown = path.read_text(encoding="utf-8")
    heading = re.search(r"^# Issue #(\d+):\s*(.*)$", markdown, re.MULTILINE)
    if heading and int(heading[1]) != number:
        raise ValueError(f"issue heading does not match directory: {path}")
    url = re.search(r"^- URL:\s*(.+)$", markdown, re.MULTILINE)
    return LocalIssue(number, heading[2].strip() if heading else f"Issue #{number}",
                      url[1].strip() if url else None, markdown)


def select_issues(issues_dir: Path, max_issues: int, already: Iterable[int]) -> list[LocalIssue]:
    """Select unattempted local issues in numeric order, without GitHub triage."""
    if max_issues < 0:
        raise ValueError("max_issues must be nonnegative")
    excluded = set(already)
    numbers = sorted(int(p.name[6:]) for p in Path(issues_dir).iterdir()
                     if re.fullmatch(r"issue_[0-9]+", p.name) and p.is_dir()
                     and not p.is_symlink() and (p / "issue.md").is_file())
    selected = [n for n in numbers if n not in excluded][:max_issues]
    return [load_issue(issues_dir, n) for n in selected]
