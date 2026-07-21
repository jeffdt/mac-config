#!/bin/bash
PR_NUM=$(gh pr view --json number -q .number 2>/dev/null)
cat .claude/local/temper-manifests/pr-${PR_NUM}.md 2>/dev/null || echo "No manifest — first temper run"
