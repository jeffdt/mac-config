// ==UserScript==
// @name         GitHub PR → Claude
// @namespace    jeffdt
// @version      0.3
// @description  Adds Review/Walkthrough buttons to GitHub PR pages that fire hammerspoon://pr-claude
// @match        https://github.com/*/*/pull/*
// @grant        none
// @run-at       document-idle
// ==/UserScript==

// Source of truth lives in this repo. Paste into Tampermonkey to install/update.
// Pairs with ~/.hammerspoon/pr_claude.lua which handles the deep link.

(function () {
  'use strict';

  const TAG = '[pr-claude]';
  const PR_RE = /^\/[^/]+\/[^/]+\/pull\/\d+/;

  // Claude orange (Anthropic terracotta). Theme-agnostic — pops in both
  // light and dark modes without trying to mirror the host site's tokens,
  // and visually marks these as "Claude buttons" regardless of which site
  // they're injected on.
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

  const link = (mode) => {
    const params = new URLSearchParams({
      url: location.origin + location.pathname,
      mode,
    });
    return `hammerspoon://pr-claude?${params.toString()}`;
  };

  // Try anchors in priority order. New GitHub UI first (post-2024 Primer redesign),
  // old UI as fallback, last resort: anything containing the PR title H1.
  function findAnchor() {
    const strategies = [
      // New UI: action area near "Ready to merge" / "Code" buttons.
      () => document.querySelector('[data-testid="pr-header-actions"]'),
      () => document.querySelector('[data-component="PH_Actions"]'),
      () => document.querySelector('.PageHeader-actions'),
      // The "Code" dropdown button's parent row tends to be a flex container.
      () => {
        const codeBtn = [...document.querySelectorAll('button, summary, a')]
          .find((el) => el.textContent.trim() === 'Code');
        return codeBtn?.closest('div[class*="HeaderActions"], div[class*="Header"], div');
      },
      // Old UI (pre-2024).
      () => document.querySelector('.gh-header-actions'),
      () => document.querySelector('.gh-header-meta'),
      // Last resort: parent of the PR title H1.
      () => document.querySelector('h1.gh-header-title')?.parentElement,
      () => document.querySelector('main h1')?.parentElement,
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
    if (document.getElementById('jeffdt-claude-buttons')) return;
    if (!PR_RE.test(location.pathname)) return;

    const host = findAnchor();
    if (!host) return;

    ensureStyle();

    const wrap = document.createElement('span');
    wrap.id = 'jeffdt-claude-buttons';
    wrap.style.cssText = 'margin-left:8px;display:inline-flex;gap:6px;align-items:center;';

    for (const [label, mode] of [
      ['🤖 Review', 'review'],
      ['🚶 Walkthrough', 'walkthrough'],
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

  inject();
  new MutationObserver(inject).observe(document.body, {
    childList: true,
    subtree: true,
  });
})();
