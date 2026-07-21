#!/usr/bin/env python3
"""Render PR walkthrough JSON into HTML files.

Usage: render.py <input.json> <output_dir>
"""
import json
import sys
from pathlib import Path

from jinja2 import Environment, FileSystemLoader, select_autoescape

from diff_parser import parse_diff
from anchors import resolve_anchors

try:
    from highlight import highlight_chunk
except Exception:  # pragma: no cover - highlighting is a progressive enhancement
    highlight_chunk = None

HERE = Path(__file__).parent
TEMPLATES = HERE / "templates"


def anchor_for_line(new_line, findings):
    """Return the line-anchored finding whose anchor includes new_line, or None."""
    if new_line is None:
        return None
    for f in findings:
        if f.get("anchor") and new_line in f["anchor"]["lines"]:
            return f
    return None


def compute_derived(data):
    """Add fields the templates need that aren't in the raw JSON contract.

    Returns a sidecar dict mapping ``f{id}`` -> resolved ``{file, line}``.
    """
    for chunk in data["chunks"]:
        chunk["diff_lines"] = parse_diff(chunk.get("diff", ""))
        if highlight_chunk is not None:
            try:
                highlight_chunk(chunk)
            except Exception:
                pass  # fall back to plain escaped text in the template

    # Resolve content-based anchors to real line numbers before splitting findings,
    # since resolution may demote an unresolvable anchor to cross-cutting (None).
    sidecar, warnings = resolve_anchors(data)
    for w in warnings:
        print(f"warning: {w}", file=sys.stderr)

    for chunk in data["chunks"]:
        line_anchored = [f for f in chunk["findings"] if f.get("anchor")]
        cross_cutting = [f for f in chunk["findings"] if not f.get("anchor")]
        line_anchored.sort(key=lambda f: f["anchor"]["lines"][0])
        chunk["line_anchored_findings"] = line_anchored
        chunk["cross_cutting_findings"] = cross_cutting

    all_findings = [f for c in data["chunks"] for f in c["findings"]]
    data["totals"] = {
        "concerns":    sum(1 for f in all_findings if f["type"] == "concern"),
        "suggestions": sum(1 for f in all_findings if f["type"] == "suggestion"),
        "strengths":   sum(len(c["strengths"]) for c in data["chunks"]),
        "recommended": sum(1 for f in all_findings if f.get("recommend_fix")),
    }

    hotspots = []
    for c in data["chunks"]:
        for f in c["findings"]:
            if f.get("recommend_fix"):
                hotspots.append({**f, "chunk_id": c["id"]})
    for c in data["chunks"]:
        for f in c["findings"]:
            if f.get("thread") and f["thread"]["status"] == "unresolved" and not f.get("recommend_fix"):
                hotspots.append({**f, "chunk_id": c["id"]})
    data["hotspots"] = hotspots

    return sidecar


def main():
    if len(sys.argv) != 3:
        print(__doc__, file=sys.stderr)
        sys.exit(2)

    input_path = Path(sys.argv[1])
    output_dir = Path(sys.argv[2])
    output_dir.mkdir(parents=True, exist_ok=True)

    data = json.loads(input_path.read_text())
    sidecar = compute_derived(data)
    (output_dir / "anchors.json").write_text(json.dumps(sidecar, indent=2))

    env = Environment(
        loader=FileSystemLoader(str(TEMPLATES)),
        autoescape=select_autoescape(['html', 'j2']),
    )
    env.globals["anchor_for_line"] = anchor_for_line

    overview_tmpl = env.get_template("overview.html.j2")
    (output_dir / "overview.html").write_text(overview_tmpl.render(**data))

    chunk_tmpl = env.get_template("chunk.html.j2")
    for chunk in data["chunks"]:
        out = output_dir / f"chunk-{chunk['id']:02d}.html"
        out.write_text(chunk_tmpl.render(chunk=chunk, **data))

    print(f"Rendered {len(data['chunks']) + 1} files to {output_dir}", file=sys.stderr)


if __name__ == "__main__":
    main()
