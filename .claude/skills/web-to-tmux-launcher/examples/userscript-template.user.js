// ==UserScript==
// @name         <<TODO: human-readable name, e.g. "Sentry → Claude">>
// @namespace    jeffdt
// @version      0.1
// @description  <<TODO: one-line description>>
// @match        <<TODO: URL pattern, e.g. https://*.sentry.io/issues/*>>
// @grant        none
// @run-at       document-idle
// ==/UserScript==

// NOTE: The Tentacle Chrome extension supersedes per-site Tampermonkey userscripts
// for new launchers. The extension injects buttons on supported sites and emits
// hammerspoon://tentacle?site=<s>&url=<u>&mode=<m> — no per-site userscript needed.
//
// This template is kept as a reference for the button-injection pattern and CSS
// constants. Use it only if you need to inject on a site the Tentacle extension
// does not yet support, or if you need a one-off standalone button outside the
// tentacle URL contract.
//
// For all other cases: add a SITE_PARSERS + DISPATCH entry in tentacle.lua instead
// (see examples/handler-template.lua).
//
// Source of truth lives in ~/.claude/scripts/userscripts/<<TODO: filename>>.
// Paste into Tampermonkey separately to install/update.
// The URL this emits must match hammerspoon://tentacle?site=<s>&url=<u>&mode=<m>
// to be handled by tentacle.lua.

(function () {
  'use strict';

  const TAG = '[<<TODO: short-tag>>]';

  // Claude orange (Anthropic terracotta) — theme-agnostic and brand-distinctive,
  // marks these as "Claude buttons" on whatever site the userscript injects into.
  // Don't change the colors per-launcher; consistency across sites is the point.
  const STYLE_ID = 'jeffdt-claude-buttons-style';
  const BTN_CLASS = 'jeffdt-claude-btn';
  function ensureStyle() {
    if (document.getElementById(STYLE_ID)) return;
    const s = document.createElement('style');
    s.id = STYLE_ID;
    s.textContent = `
      .${BTN_CLASS} {
        display: inline-flex;
        align-items: center;
        gap: 4px;
        padding: 5px 12px;
        background: #CC785C;
        color: #FFFFFF !important;
        border: 1px solid rgba(0, 0, 0, 0.15);
        border-radius: 6px;
        font-size: 12px;
        font-weight: 500;
        line-height: 20px;
        text-decoration: none !important;
        transition: background 0.15s ease;
      }
      .${BTN_CLASS}:hover {
        background: #B86A4F;
      }
    `;
    document.head.appendChild(s);
  }

  // <<TODO: regex matching the page path, with capture groups for the
  // identifier(s) you need on the hammerspoon side. Example for GitHub PRs:
  //   /^\/[^/]+\/[^/]+\/pull\/\d+/  (no captures — handler parses params.url)
  // For Sentry issues:
  //   /^\/organizations\/[^/]+\/issues\/(\d+)/
  // Tune to suit. The handler can either parse the full URL or take explicit
  // fields — keep both options open by passing url= in the query string.>>
  const PATH_RE = /<<TODO>>/;

  const link = (mode) => {
    const params = new URLSearchParams({
      url: location.origin + location.pathname,
      mode,
    });
    return `hammerspoon://tentacle?site=<<TODO: site-key>>&${params.toString()}`;
  };

  // Try anchors in priority order. New site UIs evolve frequently — keep a
  // fallback chain so the button still injects after redesigns. Each strategy
  // logs which selector matched so DOM changes are easy to diagnose.
  function findAnchor() {
    const strategies = [
      // <<TODO: list selectors in priority order. Right-click the target
      // location on the live page → Inspect → find a stable parent (data-testid
      // is best, then specific class, then structural fallback). Examples:
      // () => document.querySelector('[data-testid="issue-actions"]'),
      // () => document.querySelector('.IssueDetailsHeader-actions'),
      // () => document.querySelector('main h1')?.parentElement,
      >>
    ];
    for (const fn of strategies) {
      try {
        const el = fn();
        if (el) {
          console.log(TAG, 'anchor found via strategy', strategies.indexOf(fn), el);
          return el;
        }
      } catch (e) {
        console.warn(TAG, 'strategy threw:', e);
      }
    }
    console.warn(TAG, 'no anchor matched any strategy');
    return null;
  }

  function inject() {
    if (document.getElementById('jeffdt-<<TODO: short-id>>-buttons')) return;
    if (!PATH_RE.test(location.pathname)) return;

    const host = findAnchor();
    if (!host) return;

    ensureStyle();

    const wrap = document.createElement('span');
    wrap.id = 'jeffdt-<<TODO: short-id>>-buttons';
    wrap.style.cssText = 'margin-left:8px;display:inline-flex;gap:6px;align-items:center;';

    // <<TODO: list the modes you want as buttons. Each becomes a clickable
    // pill. Pick an emoji per mode that stays distinctive when the tab title
    // gets truncated. Example for Sentry:
    //   ['🐛 Debug',    'debug'],
    //   ['🩺 Triage',   'triage'],
    >>
    for (const [label, mode] of [
      ['<<TODO: Mode 1 label with emoji>>', '<<TODO: mode-1>>'],
      ['<<TODO: Mode 2 label with emoji>>', '<<TODO: mode-2>>'],
    ]) {
      const a = document.createElement('a');
      a.className = BTN_CLASS;
      a.textContent = label;
      a.href = link(mode);
      a.title = `${label} via Claude (mode=${mode})`;
      wrap.appendChild(a);
    }
    host.appendChild(wrap);
    console.log(TAG, 'injected buttons');
  }

  // SPA navigation re-injection — most modern sites swap content without a
  // full page load, so the anchor disappears and reappears. Re-running on
  // every DOM mutation is overkill but cheap, and the early-exit on existing
  // buttons makes it idempotent.
  inject();
  new MutationObserver(inject).observe(document.body, {
    childList: true,
    subtree: true,
  });
})();
