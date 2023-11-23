########################################################
## Base Resource Groups
########################################################

resource "azurerm_resource_group" "sym_resource_group" {
  name     = "rg-${var.short_name}-ugv-${var.environment}"
  location = var.location
  tags     = var.tags
}

########################################################
## Virtual Networking Resources
########################################################
resource "azurerm_virtual_network" "sym_network" {
  name                = "vnet-${var.short_name}-ugv-${var.environment}"
  address_space       = ["10.2.0.0/19"]
  location            = azurerm_resource_group.sym_resource_group.location
  resource_group_name = azurerm_resource_group.sym_resource_group.name
  tags                = var.tags
}

resource "azurerm_subnet" "sym_Subnet" {
  name                 = "${var.short_name}-${var.environment}-Subnet"
  resource_group_name  = azurerm_resource_group.sym_resource_group.name
  virtual_network_name = azurerm_virtual_network.sym_network.name
  address_prefixes     = ["10.2.0.0/24"]
}

########################################################
## App Service Resources
########################################################

resource "azurerm_service_plan" "sym_service_plan" {
  name                = "${var.short_name}-serviceplan-${var.environment}"
  resource_group_name = azurerm_resource_group.sym_resource_group.name
  location            = azurerm_resource_group.sym_resource_group.location
  sku_name            = "S1"
  os_type             = "Windows"
}

resource "azurerm_windows_web_app" "sym_windows_web_app" {
  name                = "${var.short_name}-windowswebapp-${var.environment}"
  resource_group_name = azurerm_resource_group.sym_resource_group.name
  location            = azurerm_resource_group.sym_resource_group.location
  service_plan_id = azurerm_service_plan.sym_service_plan.id


  site_config {
    http2_enabled                           = true
    application_stack {
      current_stack = "dotnetcore"
      dotnet_version = "v6.0"
    }
    always_on                = true
    ftps_state               = "Disabled"
  }
  lifecycle {
    ignore_changes = [
      app_settings,
      auth_settings_v2,
      identity,
      sticky_settings
    ]
  }
}

########################################################
## Key Vault Resources
########################################################

data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "sym_key_vault" {
  name                        = "kv-${var.short_name}-ugv-${var.environment}"
  location                    = azurerm_resource_group.sym_resource_group.location
  resource_group_name         = azurerm_resource_group.sym_resource_group.name
  enabled_for_disk_encryption = true
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days  = 7
  purge_protection_enabled    = true
  tags                        = var.tags

  sku_name = "standard"

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    key_permissions = [
      "Get",
    ]

    secret_permissions = [
      "Get", "Set",
    ]

    storage_permissions = [
      "Get",
    ]
  }

  lifecycle {
    ignore_changes = [access_policy]
  }
}


########################################################
## Post-greSQL Server
########################################################

resource "azurerm_postgresql_server" "sym_pgsql_server" {
  name                        = "${var.short_name}-pgsqlserver-${var.environment}"
  location                    = azurerm_resource_group.sym_resource_group.location
  resource_group_name         = azurerm_resource_group.sym_resource_group.name

  administrator_login                  = "symcloudadmin"
  administrator_login_password         = azurerm_key_vault_secret.Postgresql_Server_Secret.value

  sku_name   = "GP_Gen5_4"
  version    = "11"
  storage_mb = 640000

  ssl_enforcement_enabled          = false
  ssl_minimal_tls_version_enforced = "TLSEnforcementDisabled"
}

########################################################
## Post-greSQL Database
########################################################

resource "azurerm_postgresql_database" "sym_pgsql_database" {
  name                        = "${var.short_name}-pgsqldb-${var.environment}"
  resource_group_name         = azurerm_resource_group.sym_resource_group.name
  server_name                 = azurerm_postgresql_server.sym_pgsql_server.name
  charset                     = "UTF8"
  collation                   = "English_United States.1252"
}

## Secret generation

resource "random_password" "Postgresql_Server_Secret" {
  length      = 20
  min_upper   = 2
  min_lower   = 2
  min_numeric = 2
  min_special = 2
}

resource "azurerm_key_vault_secret" "Postgresql_Server_Secret" {
  name         = "Postgresql-Server-Secret"
  value        = random_password.Postgresql_Server_Secret.result
  key_vault_id = azurerm_key_vault.sym_key_vault.id
}