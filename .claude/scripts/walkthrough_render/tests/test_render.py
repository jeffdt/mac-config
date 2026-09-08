import subprocess
from pathlib import Path

FIXTURE = Path(__file__).parent.parent / "fixtures" / "example.json"
SCRIPT = Path(__file__).parent.parent / "render.py"


def _render(tmp_path):
    subprocess.run(["python3", str(SCRIPT), str(FIXTURE), str(tmp_path)], check=True)


def test_renders_overview_and_per_chunk_files(tmp_path):
    _render(tmp_path)
    assert (tmp_path / "overview.html").exists()
    assert (tmp_path / "chunk-01.html").exists()
    chunk_files = sorted(tmp_path.glob("chunk-*.html"))
    assert len(chunk_files) == 6  # 6 chunks in the fixture


def test_overview_contains_pr_title(tmp_path):
    _render(tmp_path)
    html = (tmp_path / "overview.html").read_text()
    assert "Add forms list tool to the LLM assistant" in html


def test_chunk_contains_diff_lines_and_findings(tmp_path):
    _render(tmp_path)
    chunk2 = (tmp_path / "chunk-02.html").read_text()
    assert "_resolve_limit" in chunk2  # comes from the diff
    assert 'data-finding="f2"' in chunk2  # the unresolved-thread finding anchors at L229
    assert "Unresolved thread" in chunk2  # the summary text


def test_recommended_findings_open_by_default(tmp_path):
    _render(tmp_path)
    chunk2 = (tmp_path / "chunk-02.html").read_text()
    # finding #4 is recommend_fix=True → opens with the `open` attribute
    f4_idx = chunk2.find('id="f4"')
    assert f4_idx != -1
    # Check the surrounding context for the `open` attribute on this details element
    surrounding = chunk2[max(0, f4_idx - 200):f4_idx + 50]
    assert " open" in surrounding


def test_non_recommended_findings_closed_by_default(tmp_path):
    _render(tmp_path)
    chunk2 = (tmp_path / "chunk-02.html").read_text()
    # finding #1 is recommend_fix=False → no `open` attribute on its details
    f1_idx = chunk2.find('id="f1"')
    assert f1_idx != -1
    surrounding = chunk2[max(0, f1_idx - 200):f1_idx + 50]
    # The details tag opens just before id="f1"; verify it doesn't have ` open`
    details_open = surrounding.rfind('<details')
    details_substr = surrounding[details_open:]
    assert ' open' not in details_substr[:details_substr.find('>')]


def test_overview_lists_all_chunks_in_reading_order(tmp_path):
    _render(tmp_path)
    html = (tmp_path / "overview.html").read_text()
    # Titles appear in document order — using HTML-safe substrings since `&` gets autoescaped to `&amp;`
    titles = ["Schema &amp; DTOs", "The forms list tool", "Tool registration", "Tests", "Stub service", "Config"]
    positions = [html.find(t) for t in titles]
    assert all(p > 0 for p in positions), positions
    assert positions == sorted(positions), positions


def test_hotspots_include_recommended_and_unresolved_threads(tmp_path):
    _render(tmp_path)
    html = (tmp_path / "overview.html").read_text()
    # #3 + #4 + #5 are recommend_fix; #2 is unresolved thread (without recommend)
    # All should appear in hotspots section
    for ref in ['href="chunk-02.html#f3"', 'href="chunk-02.html#f4"',
                'href="chunk-01.html#f5"', 'href="chunk-02.html#f2"']:
        assert ref in html, f"hotspot link missing: {ref}"
