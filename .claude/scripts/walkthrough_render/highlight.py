"""Syntax-highlight diff lines with Pygments.

Highlights each side of the diff (new = context+add, old = context+rem) as a
whole blob so multi-line constructs (docstrings, multi-line strings) tokenize
correctly, then maps the resulting per-line HTML back onto each diff line.

Token classes are emitted with a ``tok-`` prefix so they never collide with the
template's own short utility classes (``.s``, ``.c``, etc.).
"""
import html as _html
from os.path import basename

from pygments.lexers import get_lexer_for_filename
from pygments.util import ClassNotFound
from pygments.token import STANDARD_TYPES


def _css_class(ttype):
    """Map a Pygments token type to its standard short class, walking parents."""
    t = ttype
    while t not in STANDARD_TYPES:
        t = t.parent
    return STANDARD_TYPES[t]


def _highlight_to_lines(code, lexer):
    """Tokenize ``code`` into a list of HTML strings, one per source line.

    Spans are closed at newlines and reopened on the next line so a multi-line
    token never produces unbalanced markup when split across diff rows.
    """
    lines = [[]]
    for ttype, value in lexer.get_tokens(code):
        cls = _css_class(ttype)
        parts = value.split('\n')
        for i, part in enumerate(parts):
            if i > 0:
                lines.append([])
            if part:
                esc = _html.escape(part)
                lines[-1].append(f'<span class="tok-{cls}">{esc}</span>' if cls else esc)
    return [''.join(frag) for frag in lines]


def _lexer_for(files):
    """Pick a lexer from the chunk's primary file; None if undeterminable."""
    for f in files or []:
        try:
            return get_lexer_for_filename(basename(f), stripnl=False, stripall=False)
        except ClassNotFound:
            continue
    return None


def highlight_chunk(chunk):
    """Attach an ``html`` field to each diff line. No-op on unknown languages."""
    lexer = _lexer_for(chunk.get("files"))
    if lexer is None:
        return

    diff_lines = chunk["diff_lines"]
    new_src = [ln["text"] for ln in diff_lines if ln["kind"] in ("add", "context")]
    old_src = [ln["text"] for ln in diff_lines if ln["kind"] in ("rem", "context")]
    new_html = _highlight_to_lines('\n'.join(new_src), lexer) if new_src else []
    old_html = _highlight_to_lines('\n'.join(old_src), lexer) if old_src else []

    ni = oi = 0
    for ln in diff_lines:
        kind = ln["kind"]
        if kind == "add":
            ln["html"] = new_html[ni] if ni < len(new_html) else None
            ni += 1
        elif kind == "context":
            ln["html"] = new_html[ni] if ni < len(new_html) else None
            ni += 1
            oi += 1
        elif kind == "rem":
            ln["html"] = old_html[oi] if oi < len(old_html) else None
            oi += 1
        else:
            ln["html"] = None

    chunk["highlighted"] = True
