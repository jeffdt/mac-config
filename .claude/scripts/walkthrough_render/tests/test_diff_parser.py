from walkthrough_render.diff_parser import parse_diff

def test_parses_hunk_header():
    lines = parse_diff("@@ -10,2 +10,3 @@ class X\n     pass\n")
    assert lines[0] == {"kind": "hunk", "text": "@@ -10,2 +10,3 @@ class X", "old_line": None, "new_line": None, "file": None}


def test_tracks_file_from_header():
    diff = "diff --git a/foo.py b/foo.py\n--- a/foo.py\n+++ b/foo.py\n@@ -1,1 +1,2 @@\n keep\n+added\n"
    lines = parse_diff(diff)
    assert all(l["file"] == "foo.py" for l in lines)

def test_tracks_line_numbers_through_context_add_rem():
    diff = "@@ -10,3 +10,4 @@\n unchanged\n-removed\n+added_one\n+added_two\n unchanged_after\n"
    lines = parse_diff(diff)
    kinds = [(l["kind"], l["old_line"], l["new_line"]) for l in lines if l["kind"] != "hunk"]
    assert kinds == [
        ("context", 10, 10),
        ("rem",     11, None),
        ("add",     None, 11),
        ("add",     None, 12),
        ("context", 12, 13),
    ]

def test_handles_multiple_hunks():
    diff = "@@ -1,1 +1,1 @@\n line1\n@@ -10,1 +10,1 @@\n line10\n"
    lines = parse_diff(diff)
    assert sum(1 for l in lines if l["kind"] == "hunk") == 2

def test_ignores_diff_file_headers():
    """Lines starting with 'diff --git', '---', '+++', 'index' are skipped."""
    diff = "diff --git a/f b/f\n--- a/f\n+++ b/f\n@@ -1,1 +1,1 @@\n line\n"
    lines = parse_diff(diff)
    assert lines[0]["kind"] == "hunk"
    assert len(lines) == 2
