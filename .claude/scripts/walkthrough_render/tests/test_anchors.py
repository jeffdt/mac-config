from walkthrough_render.anchors import resolve_anchors
from walkthrough_render.diff_parser import parse_diff

DIFF = (
    "diff --git a/pkg/foo.py b/pkg/foo.py\n"
    "--- a/pkg/foo.py\n"
    "+++ b/pkg/foo.py\n"
    "@@ -1,2 +1,4 @@\n"
    " import os\n"
    "+def coerce(value):\n"
    "+    return int(value)\n"
    " EOF\n"
)


def _chunk(findings):
    c = {"id": 1, "findings": findings}
    c["diff_lines"] = parse_diff(DIFF)
    return {"chunks": [c]}


def test_snippet_resolves_to_new_line():
    data = _chunk([{"id": 1, "anchor": {"file": "foo.py", "snippet": "return int(value)"}}])
    sidecar, warnings = resolve_anchors(data)
    assert data["chunks"][0]["findings"][0]["anchor"]["lines"] == [3]
    assert sidecar["f1"] == {"file": "foo.py", "line": 3}
    assert warnings == []


def test_unfound_snippet_demotes_to_file_wide():
    data = _chunk([{"id": 2, "anchor": {"file": "foo.py", "snippet": "no_such_code()"}}])
    sidecar, warnings = resolve_anchors(data)
    assert data["chunks"][0]["findings"][0]["anchor"] is None
    assert "f2" not in sidecar
    assert len(warnings) == 1


def test_legacy_lines_out_of_range_dropped():
    data = _chunk([{"id": 3, "anchor": {"file": "foo.py", "lines": [999]}}])
    sidecar, warnings = resolve_anchors(data)
    assert data["chunks"][0]["findings"][0]["anchor"] is None
    assert len(warnings) == 1


def test_legacy_lines_in_range_kept():
    data = _chunk([{"id": 4, "anchor": {"file": "foo.py", "lines": [2, 999]}}])
    sidecar, warnings = resolve_anchors(data)
    assert data["chunks"][0]["findings"][0]["anchor"]["lines"] == [2]
    assert sidecar["f4"]["line"] == 2


def test_null_anchor_ignored():
    data = _chunk([{"id": 5, "anchor": None}])
    sidecar, warnings = resolve_anchors(data)
    assert sidecar == {}
    assert warnings == []
