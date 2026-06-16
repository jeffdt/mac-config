"""Parse unified-diff text into a list of line dicts for templating."""
import re

HUNK_RE = re.compile(r'^@@ -(\d+)(?:,\d+)? \+(\d+)(?:,\d+)? @@')
FILE_RE = re.compile(r'^\+\+\+ b/(.+)$')
SKIP_PREFIXES = ('diff --git', '--- ', '+++ ', 'index ', 'new file mode', 'deleted file mode', '\\ No newline')


def parse_diff(diff_text: str) -> list[dict]:
    """Return [{kind, text, old_line, new_line, file}, ...] for the diff body.

    ``file`` is the new-side path (from the most recent ``+++ b/<path>`` header),
    so consumers can resolve a line to the file it belongs to even when a single
    diff spans multiple files.
    """
    lines = []
    old_n = new_n = None
    cur_file = None

    for raw in diff_text.splitlines():
        fm = FILE_RE.match(raw)
        if fm:
            cur_file = fm.group(1)
            continue
        if any(raw.startswith(p) for p in SKIP_PREFIXES):
            continue

        m = HUNK_RE.match(raw)
        if m:
            old_n = int(m.group(1))
            new_n = int(m.group(2))
            lines.append({"kind": "hunk", "text": raw, "old_line": None, "new_line": None, "file": cur_file})
            continue

        if old_n is None:
            # Stray line before any hunk — skip.
            continue

        if raw.startswith('+'):
            lines.append({"kind": "add", "text": raw[1:], "old_line": None, "new_line": new_n, "file": cur_file})
            new_n += 1
        elif raw.startswith('-'):
            lines.append({"kind": "rem", "text": raw[1:], "old_line": old_n, "new_line": None, "file": cur_file})
            old_n += 1
        else:
            text = raw[1:] if raw.startswith(' ') else raw
            lines.append({"kind": "context", "text": text, "old_line": old_n, "new_line": new_n, "file": cur_file})
            old_n += 1
            new_n += 1

    return lines
