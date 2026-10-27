---
name: wizcli-sast-scan
description: This skill should be used when you need Wiz SAST findings for code that is not on the default branch yet, such as a PR's "Below Threshold" findings, or when the Wiz MCP connector returns nothing or NOT_FOUND for a PR scan. Triggers include "Wiz SAST findings for this PR", "what did Wiz flag", "Wiz SAST Scanner neutral", "wizcli", "scan this branch with Wiz", or a Wiz scan comment whose file paths are truncated. Runs wizcli locally, SAST only, with nothing published to the Wiz portal.
---

# Local Wiz SAST scan with wizcli

Assumes `wizcli` is installed and authenticated. If a command fails with an auth or "command not found" error, read `references/install-and-auth.md` and have the user run the login (it needs a human to approve in a browser).

## Why this exists

The Wiz MCP connector only sees default-branch data. For an open PR it returns empty lists or `NOT_FOUND`, and GitHub check runs carry only counts, with no paths. A local `wizcli` scan reproduces the PR's SAST findings with full file paths and lines.

## The command

```bash
wizcli scan dir <dir> \
  --disabled-scanners Vulnerability,Secret,SensitiveData,Misconfiguration,SoftwareSupplyChain,AIModels,Malware \
  --no-publish \
  --by-policy-hits DISABLED \
  --sarif-output-file "$SCRATCH/wiz.sarif"
```

- `--disabled-scanners ...` leaves only SAST on. (`--types` is for IaC types, not scanner selection.)
- `--no-publish` keeps results local. Without it the scan is uploaded to Wiz.
- `--by-policy-hits DISABLED` shows findings that did not hit a policy. The default `BLOCK` hides below-threshold findings, and the output then says "SAST (N filtered)".
- `--by-policy-hits` takes exactly one value (`BLOCK`, `AUDIT`, `DISABLED`). A comma list errors out.
- Run it from the repo root and pass a directory. Scan the package dirs the PR touches, not the whole repo.

## Read the findings

SARIF is the parseable output. The `--json-output-file` report holds scan metadata, not a flat findings list.

```bash
jq -r '.runs[].results[] | [.ruleId, .level, .locations[0].physicalLocation.artifactLocation.uri, .locations[0].physicalLocation.region.startLine] | @tsv' "$SCRATCH/wiz.sarif"
```

Stdout also prints a table with name, rule, path, start line, severity, and CWE. The table's Path column shows only the file name, so use SARIF for full paths.

## Reading the result

- `Verdict: PASSED_BY_POLICY` with findings listed means they are below the policy threshold, matching the PR's "Below Threshold" tab and a `neutral` Wiz SAST check.
- Open the flagged lines and judge each finding. Rule names look like `WS-PYTHON-00344`.

## Known limits

- Verified once, on k-repo PR 75662: the local scan reproduced the PR's 2 Medium findings exactly. Rules and thresholds may differ from the GitHub App in other cases.
- The `wizcli` exit code and auth expiry behavior are unverified.
- Scanning a whole large repo was not tried.
