# Global Settings — Azure Role Definitions (Terraform/OpenTofu)

## 1. Overview

This configuration manages Azure RBAC custom role definitions for subscription `618c8e34-b87b-44e8-bb3a-b2de95df60ed`. Today it manages one resource: the built-in **Key Vault Administrator** role definition, exposed through a reusable module and driven by a `role_definitions` map variable.

How it was produced:

1. The code was generated from discovered cloud resources (the discovery data lists one `azurerm_role_definition`, "Key Vault Administrator").
2. The resource was imported into state with the `imports.sh` script.
3. The configuration was reconciled until `plan` reported no drift. Final reconciliation result: **No changes. Your infrastructure matches the configuration.**

Provider: `hashicorp/azurerm` (no version constraint is pinned in `versions.tf`; the resolved version is recorded in `.terraform.lock.hcl`).

## 2. Resources

| Terraform address | Provider type | Real-world name | Real-world ID | Purpose |
|---|---|---|---|---|
| `module.role_definition["key_vault_administrator"].azurerm_role_definition.this` | `azurerm_role_definition` | Key Vault Administrator (`BuiltInRole`) | `/subscriptions/618c8e34-b87b-44e8-bb3a-b2de95df60ed/providers/Microsoft.Authorization/roleDefinitions/00482a5a-887f-4fb3-b363-3b7fe8e74483` (role GUID `00482a5a-887f-4fb3-b363-3b7fe8e74483`) | Data-plane administrator role for Key Vault: all data operations on vaults and their keys, secrets, and certificates. Cannot manage vaults or role assignments. |

Only one resource instance exists, created via `for_each` over `var.role_definitions`.

## 3. Module structure

```
.
├── versions.tf          terraform block; requires provider hashicorp/azurerm
├── providers.tf         provider "azurerm" { features {} }
├── main.tf              module "role_definition" (for_each over var.role_definitions)
├── variables.tf         variable "role_definitions" (map of objects, default {})
├── outputs.tf           empty (no root outputs)
├── imports.sh           one-time import script
├── environments/
│   └── sg.tfvars        values for role_definitions
└── modules/
    └── role_definition/
        ├── main.tf      azurerm_role_definition.this (dynamic "permissions")
        ├── variables.tf name, scope, description, assignable_scopes, permissions
        └── outputs.tf   output "id" = azurerm_role_definition.this.id
```

- **`modules/role_definition`** (local module, `source = "./modules/role_definition"`): wraps one `azurerm_role_definition` named `this`. Inputs are `name`, `scope`, `description` (default null), `assignable_scopes` (default `[]`), and `permissions` (default `[]`; each entry has `actions`, `not_actions`, `data_actions`, `not_data_actions`, all defaulting to `[]`). Exposes `id`.
- **Root module**: no external (`git::`) modules are used. The only module call is the local `role_definition` module.

## 4. How import works

`imports.sh` runs one import per managed resource, using the module-qualified address:

```sh
"$1" import -var-file environments/sg.tfvars \
  'module.role_definition["key_vault_administrator"].azurerm_role_definition.this' \
  '/subscriptions/618c8e34-b87b-44e8-bb3a-b2de95df60ed/providers/Microsoft.Authorization/roleDefinitions/00482a5a-887f-4fb3-b363-3b7fe8e74483|/subscriptions/618c8e34-b87b-44e8-bb3a-b2de95df60ed'
```

- The first argument is the IaC binary (e.g. `/tmp/tmp.EdfaEA/terraform`). The script is run as `sh imports.sh <binary>`.
- The import ID for `azurerm_role_definition` has the form `<roleDefinitionId>|<scope>`.
- The import has already been run once to populate state. **Do not re-run it** unless state is lost.

To re-import the single resource if state is lost (substitute your binary path):

```sh
terraform import -var-file=environments/sg.tfvars \
  'module.role_definition["key_vault_administrator"].azurerm_role_definition.this' \
  '/subscriptions/618c8e34-b87b-44e8-bb3a-b2de95df60ed/providers/Microsoft.Authorization/roleDefinitions/00482a5a-887f-4fb3-b363-3b7fe8e74483|/subscriptions/618c8e34-b87b-44e8-bb3a-b2de95df60ed'
```

Then run `plan` and confirm it reports no changes.

## 5. How to use the code

Run all commands from the working directory (`/mnt/sg_workspace/user/global-settings`). Substitute `terraform` with your binary if it is not on `PATH` (e.g. `/tmp/tmp.EdfaEA/terraform`).

```sh
# 1. Initialize providers and modules
terraform init

# 2. Preview changes for the sg environment
terraform plan -var-file=environments/sg.tfvars

# 3. Apply changes
terraform apply -var-file=environments/sg.tfvars
```

### Targeting another environment (e.g. dev → prod)

No `.tf` edits are required:

1. Copy the environment file: `cp environments/sg.tfvars environments/prod.tfvars`
2. Edit the values in `environments/prod.tfvars` (at minimum the `scope` and any `assignable_scopes`/`permissions` for the target subscription; change the role `name` and map key if you want a distinct role).
3. Plan and apply against the new file:

   ```sh
   terraform plan -var-file=environments/prod.tfvars
   terraform apply -var-file=environments/prod.tfvars
   ```

Note: the state file is shared by default. To keep environments isolated, use a separate state (e.g. a different backend key or workspace) before planning against a different subscription, otherwise the existing state tracks the `sg` role definition.

## 6. Variables

| Variable | Type | Default | Controls |
|---|---|---|---|
| `role_definitions` | `map(object({...}))` | `{}` | Map of custom role definitions. Each key becomes a `module.role_definition["<key>"]` instance. Fields: `name` (string, required), `scope` (string, required), `description` (optional string), `assignable_scopes` (optional list of strings, default `[]`), `permissions` (optional list of objects with `actions`, `not_actions`, `data_actions`, `not_data_actions`, each an optional list defaulting to `[]`). |

Value set in `environments/sg.tfvars`:

- `role_definitions.key_vault_administrator.name` = `"Key Vault Administrator"`
- `role_definitions.key_vault_administrator.scope` = `"/subscriptions/618c8e34-b87b-44e8-bb3a-b2de95df60ed"`
- `role_definitions.key_vault_administrator.assignable_scopes` = `["/"]`
- `role_definitions.key_vault_administrator.permissions` = one entry with `actions` (10 entries under `Microsoft.Authorization`, `Microsoft.Insights`, `Microsoft.Resources`, `Microsoft.Support`, and `Microsoft.KeyVault`) and `data_actions` = `["Microsoft.KeyVault/vaults/*"]`.

**Sensitive variables:** None. `variables.tf` declares no `sensitive = true` variables, and no `secrets.auto.tfvars` file is present or required for this configuration. If you later add sensitive variables, supply them via `secrets.auto.tfvars` or `-var` before planning.

## 7. Infrastructure graph

```
subscription 618c8e34-b87b-44e8-bb3a-b2de95df60ed   (scope, external)
└── Microsoft.Authorization/roleDefinitions/00482a5a-887f-4fb3-b363-3b7fe8e74483
    (Key Vault Administrator, module.role_definition["key_vault_administrator"])
    └── azurerm_role_definition.this
        ├── name              <- var.name              ("Key Vault Administrator")
        ├── scope             <- var.scope             (subscription ID above)
        ├── assignable_scopes <- var.assignable_scopes (["/"])
        └── permissions (dynamic) <- var.permissions
            └── actions / data_actions  (Microsoft.KeyVault/vaults/*)
```

Dependencies: there are no inter-resource references. The only dependency is the module's `for_each` over `var.role_definitions`; the root `output` set is empty.

## 8. Notable decisions & caveats

- **Single module, `for_each` keying.** The role definition is wrapped in a local module and instantiated with `for_each` keyed by `key_vault_administrator`. Adding another role means adding another map entry and another import; the key is part of the state address and must not change.
- **Import ID format.** `azurerm_role_definition` imports require `<roleDefinitionId>|<scope>`; the scope here is the subscription path.
- **`data_actions` source.** The discovery data did not include `data_actions`. The `Microsoft.KeyVault/vaults/*` data action was taken from the plan output during reconciliation, not from discovery. Treat it as the authoritative value for this role unless the Azure portal shows otherwise.
- **Omitted computed attributes.** The discovery record includes fields such as `tags`, `references`, `integrations` (integration group links), `CSP`, `service`, `region`, and `scanned_at`. These are not Terraform arguments for `azurerm_role_definition` and are not modeled. `tags` was empty.
- **Discovery `notActions`.** The discovered permission had `notActions: []`, which matches the code (`not_actions` defaults to empty).
- **Built-in role managed as custom definition.** The role is `BuiltInRole` in Azure. Managing it through `azurerm_role_definition` works, but changes to the built-in definition are generally not permitted by Azure; a `plan` showing changes to this role may fail at apply time.
- **Root output empty.** `outputs.tf` exists but is empty; the module's `id` output is not re-exported at the root.
- **Shared state.** Environments are selected only by `-var-file`; there is no backend or workspace configuration in the code, so separate environments need separate state handling (see section 5).
- **Drift.** None outstanding at the time of reconciliation (final result: no changes).
