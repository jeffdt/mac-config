---
name: klaviyocli-terraform
version: 1.0.0
description: This skill should be used when the user asks to "run terraform plan", "run terraform apply", "plan this module", "apply terraform changes", "check drift", "fix drift", "clear state lock", "force unlock", or when working with infrastructure-as-code in infrastructure-deployment or terraform repos. Handles AWS authentication and environment selection automatically via klaviyocli.
---

# Klaviyocli Terraform

The `klaviyocli terraform` command wraps Terraform with Klaviyo-specific authentication, environment selection, and state management. Run from the root of the infrastructure-deployment repo.

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
# Plan changes
klaviyocli terraform plan <env> <module>

# Apply changes (after plan)
klaviyocli terraform apply <env> <module>

# Check drift
klaviyocli terraform drift list <env>
klaviyocli terraform drift get <env> <module>

# Validate configuration
klaviyocli terraform validate <env> <module>
```

## AWS Environments

Common environments (use the appropriate one for your module):

| Environment | Description |
|-------------|-------------|
| `prod` | Production |
| `eng` | Engineering/staging |
| `dev` | Development |
| `security_logging` | Security logging |
| `secops` | Security operations |
| `it` | IT infrastructure |
| `bi` | Business intelligence |
| `prodnet` | Production networking |
| `prod_euc1` | Production EU (euc1) |

Use `klaviyocli terraform plan --help` to see the full list of available environments.

## Core Commands

### `plan`

Generate an execution plan showing what changes Terraform will make.

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

### `apply`

Apply changes from a previously generated plan file (tf.plan).

```bash
klaviyocli terraform apply <env> <module>

# Examples
klaviyocli terraform apply prod machine_roles/amplify-cs/iam_machine_roles
klaviyocli terraform apply eng rds/my-database --parallelism 20
```

**Options:**
- `--elevated` - Use TeamElevated AWS IAM role
- `--parallelism INTEGER` - Parallelism for operations (default: 10, increase for bulk RDS operations)
- `--lock / --nolock` - Enable/disable state locking (use with caution)

### `validate`

Validate Terraform configuration syntax and internal consistency.

```bash
klaviyocli terraform validate <env> <module>
```

### `destroy`

Destroy a specific Terraform-managed resource.

```bash
klaviyocli terraform destroy <env> <module> <resource>

# Example
klaviyocli terraform destroy prod api/my-service aws_instance.old_server
```

### `import`

Import existing infrastructure into Terraform state.

```bash
klaviyocli terraform import <env> <module> <address> <id>

# Example
klaviyocli terraform import prod api/my-service aws_instance.web i-1234567890abcdef0
```

**Options:**
- `--var TEXT` - Set a variable (can use multiple times)
- `--var-file TEXT` - Load variables from file

### `taint`

Mark a resource as tainted (will be destroyed/recreated on next apply).

```bash
klaviyocli terraform taint <env> <module> <resource>

# Example
klaviyocli terraform taint prod api/my-service aws_instance.web
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

### `drift get-shared-drift`

Check drift in modules that share a common submodule.

```bash
klaviyocli terraform drift get-shared-drift <env> <submodule>
```

### `drift refresh-shared-drift`

Refresh drift for modules sharing a submodule.

```bash
klaviyocli terraform drift refresh-shared-drift <env> <submodule>
```

## State Management

### `clear-lock`

Clear a stale DynamoDB lock for a statefile.

```bash
klaviyocli terraform clear-lock <env> <statefile_key>

# The statefile_key is the S3 key from the module's backend configuration
```

### `force-unlock`

Remove the state lock for the current configuration.

```bash
klaviyocli terraform force-unlock <env> <module>
```

## Module Management

### `list-root-modules`

List root modules that use a given submodule.

```bash
klaviyocli terraform list-root-modules <env> <submodule_path>

# Example - find all modules using a shared submodule
klaviyocli terraform list-root-modules prod rds-instance
```

### `root-variables`

Manage variables stored in AWS Secrets Manager for root modules.

```bash
# List variables
klaviyocli terraform root-variables list <env> <module>

# Create variable
klaviyocli terraform root-variables create <env> <module> <name> <value>

# Update variable
klaviyocli terraform root-variables update <env> <module> <name> <value>

# Delete variable
klaviyocli terraform root-variables delete <env> <module> <name>

# Restore deleted variable
klaviyocli terraform root-variables restore <env> <module> <name>

# Add team access
klaviyocli terraform root-variables add-additional-team <env> <module> <team>
```

## Utility Commands

### `prepare-plans`

Output or execute plan commands for modules with modified files (compared to master).

```bash
# Show plan commands for modified modules
klaviyocli terraform prepare-plans

# Execute plans for all modified modules
klaviyocli terraform prepare-plans --execute
```

### `audit-all`

Verify all .tf files have correct team names in their configuration.

```bash
klaviyocli terraform audit-all
```

## Common Workflows

### 1. Make Infrastructure Changes

```bash
# 1. Plan changes
klaviyocli terraform plan prod api/my-service

# 2. Review the plan output carefully

# 3. Apply if plan looks correct
klaviyocli terraform apply prod api/my-service
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

# 4. Apply to fix drift
klaviyocli terraform apply prod api/my-service
```

### 4. Plan Modified Modules in a Branch

```bash
# See which modules need planning based on git changes
klaviyocli terraform prepare-plans

# Run all plans
klaviyocli terraform prepare-plans --execute
```

### 5. Handle State Lock Issues

```bash
# If a plan/apply fails due to stale lock
klaviyocli terraform clear-lock <env> <statefile_key>

# Or use force-unlock for the current module
klaviyocli terraform force-unlock <env> <module>
```

## Best Practices

1. **Always plan before apply** - Review the plan output carefully before applying
2. **Use `--elevated` sparingly** - Only when standard permissions are insufficient
3. **Check drift regularly** - Use `drift list -d` to find modules needing attention
4. **Use `prepare-plans`** - Before PRs, run this to identify affected modules
5. **Target specific resources** - Use `-t` flag when making targeted changes
6. **Handle parallelism carefully** - Increase for bulk operations, but not for autoscaling resources

## Troubleshooting

### Authentication Errors
- Ensure you're connected to the VPN
- Try running with `--elevated` if you need additional permissions
- Check your AWS session hasn't expired (use `--ttl` to extend)

### State Lock Errors
- First, verify no one else is running terraform on the same module
- Use `clear-lock` or `force-unlock` only if the lock is truly stale

### Drift Detection Issues
- Check the `last_task` ID in drift output to view ICA task details
- Use `klaviyocli ica <env> task get -t <task_id>` to investigate

## Getting Help

```bash
# Main help
klaviyocli terraform --help

# Command-specific help
klaviyocli terraform plan --help
klaviyocli terraform drift --help
klaviyocli terraform root-variables --help
```
