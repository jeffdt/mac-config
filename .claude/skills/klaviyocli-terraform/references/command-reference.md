# Klaviyocli Terraform: Full Command Reference

Load this file for commands beyond `plan`, `validate`, and `drift list/get` (covered in SKILL.md).

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

## Break-Glass State Operations

These bypass the normal PR → Spacelift flow. Use only when you understand why the normal flow doesn't apply (e.g. fixing a broken state, recovering from a stuck lock).

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

## Drift Detection (extended)

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
