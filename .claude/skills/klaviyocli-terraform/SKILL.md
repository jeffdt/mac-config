---
name: klaviyocli-terraform
version: 2.0.0
description: This skill should be used when the user asks to "run terraform plan", "plan this module", "check drift", "fix drift", "clear state lock", "force unlock", or when working with infrastructure-as-code in infrastructure-deployment or terraform repos. Handles AWS authentication and environment selection automatically via klaviyocli. Also fires when the user asks how to "apply" terraform changes — the answer is always to merge the PR, never to run apply directly.
---

> Generated from ~/.agents/skills/klaviyocli-terraform/SKILL.md. Do not edit this copy directly.
> Edit the source under ~/.agents, then run agents-publish.

# Klaviyocli Terraform

The `klaviyocli terraform` command wraps Terraform with Klaviyo-specific authentication, environment selection, and state management. Run from the root of the infrastructure-deployment repo.

**Applies never happen manually.** All `apply`s land via Spacelift when the PR merges — that's the whole workflow: plan locally to preview, open the PR, merge, let Spacelift apply. Never run `klaviyocli terraform apply` yourself, and never propose it as a step, even when a user asks "how do I apply this" — point them to merging the PR instead. Use the `spacelift-verify` skill after merge to confirm the run applied cleanly.

For less common operations — `destroy`, `import`, `taint`, `clear-lock`, `force-unlock`, drift sharing, `root-variables`, `prepare-plans`, `audit-all`, and troubleshooting — see [references/command-reference.md](references/command-reference.md).

## Module Path Convention (Critical)

The `<module>` argument is the path **relative to `infrastructure/live/<env>/`**. The environment argument already selects the correct environment directory, so never include `infrastructure/live/<env>/` in the module path.

**Deriving the module path:** Given a file at `infrastructure/live/prod/machine_roles/k-ops-x/iam_machine_roles/main.tf`, strip the `infrastructure/live/prod/` prefix to get the module path: `machine_roles/k-ops-x/iam_machine_roles`.

```bash
# CORRECT - module path is relative to infrastructure/live/<env>/
klaviyocli terraform plan prod machine_roles/amplify-cs/iam_machine_roles

# WRONG - do not include the infrastructure/live/<env>/ prefix
klaviyocli terraform plan prod infrastructure/live/prod/machine_roles/amplify-cs/iam_machine_roles
```

## Quick Reference

```bash
# Plan changes (preview only — merging the PR is what applies)
klaviyocli terraform plan <env> <module>

# Check drift
klaviyocli terraform drift list <env>
klaviyocli terraform drift get <env> <module>

# Validate configuration
klaviyocli terraform validate <env> <module>
```

## Core Commands

### `plan`

Generate an execution plan showing what changes Terraform will make. This is the only step that runs before opening a PR — the plan is for review, not for staging an apply you'll run yourself.

```bash
klaviyocli terraform plan <env> <module>

# Examples
klaviyocli terraform plan prod machine_roles/amplify-cs/iam_machine_roles
klaviyocli terraform plan eng rds/my-database

# With options
klaviyocli terraform plan prod api/my-service --elevated  # Use elevated IAM role
klaviyocli terraform plan prod api/my-service -t aws_instance.web  # Target specific resource
klaviyocli terraform plan prod api/my-service --ttl 2  # 2-hour session
```

**Options:**
- `--elevated` - Use TeamElevated AWS IAM role if available
- `--ttl INTEGER` - AWS session duration in hours (default: 1)
- `-t, --target TEXT` - Target specific resources (can use multiple times)
- `--deploy-env TEXT` - Deployment environment name, selects .tfvars and .backend files from vars/ and backends/ directories
- `--enable-trace-logging` - Enable trace logging for Terraform
- `--quiet` - Suppress custom output
- `--no-color` - Disable color output

### `validate`

Validate Terraform configuration syntax and internal consistency.

```bash
klaviyocli terraform validate <env> <module>
```

## Drift Detection

### `drift list`

List all root modules and their drift status.

```bash
klaviyocli terraform drift list <env>

# Examples
klaviyocli terraform drift list prod
klaviyocli terraform drift list prod -d  # Only show drifted modules
klaviyocli terraform drift list prod -e  # Only show errored modules
klaviyocli terraform drift list prod -t "my-team"  # Filter by team
```

**Options:**
- `-d, --is-drifted` - Show only modules with detected drift
- `-e, --is-errored` - Show only modules with errors
- `-s, --is-syntax-errored` - Show only modules with syntax errors
- `-t, --team-names TEXT` - Filter by CODEOWNERS team (CSV)
- `-a, --all-columns` - Show all columns
- `-b, --branch-name TEXT` - Branch to check (default: master)

### `drift get`

Get detailed drift information for a specific module including plan output.

```bash
klaviyocli terraform drift get <env> <module>

# Example
klaviyocli terraform drift get prod api/my-service
```

For shared-submodule drift, `root-variables`, `prepare-plans`, and other less common operations, see [references/command-reference.md](references/command-reference.md).

## Common Workflows

### 1. Make Infrastructure Changes

```bash
# 1. Plan changes to preview them
klaviyocli terraform plan prod api/my-service

# 2. Review the plan output carefully

# 3. Open a PR with the change and merge it — Spacelift applies automatically
```

### 2. Save Plan Output to a File

```bash
# Redirect plan output to a text file (strips color codes)
klaviyocli terraform plan prod api/my-service --no-color 2>&1 | tee plan-output.txt
```

### 3. Check and Fix Drift

```bash
# 1. List drifted modules
klaviyocli terraform drift list prod -d

# 2. Get details on specific drift
klaviyocli terraform drift get prod api/my-service

# 3. Plan to see what would change
klaviyocli terraform plan prod api/my-service

# 4. Open a PR reconciling the drift — merge it, Spacelift applies
```

## Best Practices

1. **Always plan before opening a PR** - Review the plan output carefully; the PR merge is what applies it
2. **Use `--elevated` sparingly** - Only when standard permissions are insufficient
3. **Check drift regularly** - Use `drift list -d` to find modules needing attention
4. **Target specific resources** - Use `-t` flag when making targeted changes
