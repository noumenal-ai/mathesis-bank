#!/usr/bin/env python3
"""What `merged.yml` says when a record's pull request is merged, and to whom.

    python3 ci/test_merged_comment.py

The workflow's script is read out of the workflow file and run here, so this tests the code that
runs and not a copy of it. Its `gh` call sits behind `if __name__ == "__main__"`, which is true
when the workflow pipes it to `python3 -` and false here.

The ones that matter:

* `no_github_account_is_mentioned_by_handle`. A depositor who signed in with Google has a Stet
  handle and no GitHub account. Mentioning the handle would notify whichever stranger owns that
  name on GitHub.
* `an_old_marker_still_mentions_its_login`. A marker written before handles and GitHub accounts
  could differ has no `github` key, and its `login` was the GitHub login.
"""

from __future__ import annotations

import io
import sys
import textwrap
from contextlib import redirect_stdout
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
WORKFLOW = ROOT / ".github" / "workflows" / "merged.yml"

PASSES: list[str] = []
FAILURES: list[str] = []


def check(name: str, ok: bool, detail: str = "") -> None:
    (PASSES if ok else FAILURES).append(name if ok else f"{name}: {detail}")
    print(f"  {'PASS' if ok else 'FAIL'}  {name}" + (f"  ({detail})" if detail and not ok else ""))


def the_script() -> str:
    """The heredoc the workflow pipes to python3, as python3 receives it."""
    lines = WORKFLOW.read_text().splitlines()
    start = next(i for i, l in enumerate(lines) if l.strip() == "python3 - <<'PY'")
    end = next(i for i in range(start + 1, len(lines)) if lines[i].strip() == "PY")
    return textwrap.dedent("\n".join(lines[start + 1:end])) + "\n"


ns: dict = {"__name__": "merged"}
try:
    with redirect_stdout(io.StringIO()):
        exec(compile(the_script(), str(WORKFLOW), "exec"), ns)
except SystemExit:
    # A script that acts at import rather than under the main guard exits here, and an exit
    # status of 0 from inside this file would read as every check passing.
    pass
comment_for = ns.get("comment_for")
if comment_for is None:
    print("  FAIL  the_workflow_defines_comment_for  (the script has no comment_for, or ran instead of defining it)")
    sys.exit(1)


def say(body: str):
    with redirect_stdout(io.StringIO()):
        return comment_for(body)


def marker(**f) -> str:
    fields = {"deposit": "9", "claim": "MTH.C-2026-6504", "argument": "MTH.R-2026-6504", **f}
    return "Adds one record.\n\n<!-- stet-record " + " ".join(f"{k}={v}" for k, v in fields.items()) + " -->\n"


c = say(marker(login="ada", github="ada-lovelace"))
check("a_connected_account_is_mentioned", c is not None and c.startswith("@ada-lovelace "), repr(c)[:80])
check("the_handle_is_not_mentioned_beside_it", c is not None and "@ada " not in c, repr(c)[:80])

c = say(marker(login="grace", github=""))
check("no_github_account_is_mentioned_by_handle", c is not None and "@" not in c, repr(c)[:80])
check("it_still_says_what_was_published",
      c is not None and "https://stet.world/a/MTH.C-2026-6504/" in c, repr(c)[:80])

c = say(marker(login="adhishrayas"))
check("an_old_marker_still_mentions_its_login", c is not None and c.startswith("@adhishrayas "), repr(c)[:80])

check("a_pull_request_with_no_marker_gets_nothing", say("Opened by hand.") is None)
check("an_empty_body_gets_nothing", say(None) is None)
check("a_marker_with_no_claim_gets_nothing", say(marker(claim="", login="ada", github="ada")) is None)
check("an_old_marker_with_no_login_gets_nothing", say(marker()) is None)

print()
print(f"{len(PASSES)} passed, {len(FAILURES)} failed")
sys.exit(1 if FAILURES else 0)
