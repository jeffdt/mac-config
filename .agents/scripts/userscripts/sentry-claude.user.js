// ==UserScript==
// @name         Sentry → Claude
// @namespace    jeffdt
// @version      0.2
// @description  Adds a Triage button to Sentry issue pages that fires hammerspoon://sentry-claude
// @match        https://*.sentry.io/issues/*
// @grant        none
// @run-at       document-idle
// ==/UserScript==

// Source of truth lives in this repo. Paste into Tampermonkey to install/update.
// Pairs with ~/.hammerspoon/sentry_claude.lua which handles the deep link.

(function () {
  'use strict';

  const TAG = '[sentry-claude]';
  const PATH_RE = /^\/issues\/\d+/;

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
        gap: 6px;
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
    return `hammerspoon://sentry-claude?${params.toString()}`;
  };

  // Try anchors in priority order. Sentry's React UI changes class names
  // frequently, so prefer data-test-id attributes (Sentry uses hyphenated form)
  // and fall back to structural selectors. Each strategy logs which one matched
  // so DOM changes are easy to diagnose from the console.
  function findAnchor() {
    const strategies = [
      () => document.querySelector('[data-test-id="group-actions"]'),
      () => document.querySelector('[data-test-id="issue-actions"]'),
      () => document.querySelector('[data-test-id="header-actions"]'),
      () => document.querySelector('[aria-label="Issue Actions"]'),
      // Action bar typically contains a "Resolve" button — climb to its row.
      () => {
        const resolve = [...document.querySelectorAll('button, a')]
          .find((el) => el.textContent.trim() === 'Resolve');
        return resolve?.closest('div[class*="Actions"], div[class*="Header"], div');
      },
      // Last resort: parent of the issue title heading.
      () => document.querySelector('header h1')?.parentElement,
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
    if (document.getElementById('jeffdt-sentry-claude-buttons')) return;
    if (!PATH_RE.test(location.pathname)) return;

    const host = findAnchor();
    if (!host) return;

    ensureStyle();

    const wrap = document.createElement('span');
    wrap.id = 'jeffdt-sentry-claude-buttons';
    wrap.style.cssText = 'margin:0 8px;display:inline-flex;gap:6px;align-items:center;';

    for (const [emoji, text, mode] of [
      ['🚑', 'Triage', 'triage'],
    ]) {
      const a = document.createElement('a');
      a.className = BTN_CLASS;
      a.href = link(mode);
      a.title = `${emoji} ${text} via Claude (mode=${mode})`;
      // Separate spans so the button's flex `gap` applies between emoji and
      // text — a single space character renders too tight next to an emoji.
      const eSpan = document.createElement('span');
      eSpan.textContent = emoji;
      const tSpan = document.createElement('span');
      tSpan.textContent = text;
      a.append(eSpan, tSpan);
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
