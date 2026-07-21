"""Resolve content-based finding anchors to concrete new-side line numbers.

Findings reference the code they describe by a verbatim ``snippet`` rather than a
hand-counted line number (LLMs miscount lines in long diffs). This module finds
the new-side diff line containing that snippet and stamps the resolved line back
onto ``anchor['lines']`` so the templates and the inline-comment poster both work
off a number the renderer computed, not one the model guessed.

Legacy anchors that still carry ``lines`` are accepted but validated against the
diff: any line not actually present on the new side is dropped.
"""


def _basename(path):
    return path.rsplit('/', 1)[-1] if path else path


def _resolve_snippet(snippet, anchor_file, new_side):
    """Return the new_line of the first new-side line containing snippet, or None."""
    snip = (snippet or "").strip()
    if not snip:
        return None
    base = _basename(anchor_file)
    in_file = [l for l in new_side if base and l["file"] and l["file"].endswith(base)]
    for pool in (in_file, new_side):
        for l in pool:
            if snip in l["text"]:
                return l["new_line"]
    return None


def resolve_anchors(data):
    """Resolve every finding anchor in place. Returns (sidecar, warnings).

    sidecar maps ``f{id}`` -> ``{file, line}`` for resolved anchors so Phase 3 can
    post inline comments without recounting. warnings lists anchors that could not
    be resolved (the finding is demoted to cross-cutting).
    """
    sidecar = {}
    warnings = []
    for chunk in data["chunks"]:
        new_side = [l for l in chunk["diff_lines"] if l["kind"] in ("add", "context")]
        valid_new = {l["new_line"] for l in new_side}
        for f in chunk["findings"]:
            a = f.get("anchor")
            if not a:
                continue

            if a.get("snippet"):
                line = _resolve_snippet(a["snippet"], a.get("file"), new_side)
                if line is None:
                    warnings.append(f"chunk {chunk['id']} f{f['id']}: snippet not found in diff: {a['snippet']!r}")
                    f["anchor"] = None
                    continue
                a["lines"] = [line]
            elif a.get("lines"):
                kept = [n for n in a["lines"] if n in valid_new]
                if not kept:
                    warnings.append(f"chunk {chunk['id']} f{f['id']}: anchor lines {a['lines']} absent from diff")
                    f["anchor"] = None
                    continue
                a["lines"] = kept
                line = kept[0]
            else:
                f["anchor"] = None
                continue

            sidecar[f"f{f['id']}"] = {"file": a.get("file"), "line": line}
    return sidecar, warnings
