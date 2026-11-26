#!/bin/sh
set -e
"$1" import -var-file environments/sg.tfvars 'module.role_definition["key_vault_administrator"].azurerm_role_definition.this' '/subscriptions/618c8e34-b87b-44e8-bb3a-b2de95df60ed/providers/Microsoft.Authorization/roleDefinitions/00482a5a-887f-4fb3-b363-3b7fe8e74483|/subscriptions/618c8e34-b87b-44e8-bb3a-b2de95df60ed'
