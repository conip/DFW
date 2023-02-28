# # #---------------------------------------------------------- Transit ----------------------------------------------------------

module "azure_transit" {
  source  = "terraform-aviatrix-modules/mc-transit/aviatrix"
  version = "2.4.1"
  name    = "${local.env_prefix}-AZ-trans-1"
  cloud   = "azure"
  region  = var.azure_region
  cidr    = "10.1.0.0/23"
  account = var.avx_ctrl_account_azure
}




#================================== spoke 1 =====================================
resource "azurerm_resource_group" "this" {
  name     = "RG-spoke1"
  location = var.azure_region
}

resource "azurerm_route_table" "this" {
  for_each            = toset(["gateway", "internal1", "internal2", "public1", "public2"])
  name                = "spoke1-${each.value}"
  location            = var.azure_region
  resource_group_name = azurerm_resource_group.this.name

  #Only add blackhole routes for Internal route tables
  dynamic "route" {
    for_each = can(regex("internal", each.value)) ? ["dummy"] : [] #Trick to make block conditional. Count not available on dynamic blocks.
    content {
      name           = "Blackhole"
      address_prefix = "0.0.0.0/0"
      next_hop_type  = "None"
    }
  }

  lifecycle {
    ignore_changes = [route, ] #Since the Aviatrix controller will maintain the routes, we want to ignore any changes to them in Terraform.
  }
}


module "vnet" {
  source              = "Azure/vnet/azurerm"
  vnet_name           = "${local.env_prefix}-vnet1"
  vnet_location       = var.azure_region
  use_for_each = true
  resource_group_name = azurerm_resource_group.this.name
  address_space       = [var.gw_subnet_spoke1, var.vnet_cidr_spoke1] #Use a separate CIDR for gateways, to optimize usable IP space for workloads.
  subnet_prefixes = [
    var.gw_subnet_spoke1,
    cidrsubnet(var.vnet_cidr_spoke1, 3, 0),
    cidrsubnet(var.vnet_cidr_spoke1, 3, 1),
    cidrsubnet(var.vnet_cidr_spoke1, 3, 2),
    cidrsubnet(var.vnet_cidr_spoke1, 3, 3),
    cidrsubnet(var.vnet_cidr_spoke1, 3, 4),
    cidrsubnet(var.vnet_cidr_spoke1, 3, 5),
    cidrsubnet(var.vnet_cidr_spoke1, 3, 6),
    cidrsubnet(var.vnet_cidr_spoke1, 3, 7)
  ]
  subnet_names = [
    "AviatrixGateway",
    "Internal1",
    "Internal2",
    "Internal3",
    "Internal4",
    "External1",
    "External2",
    "External3",
    "External4",
  ]

  route_tables_ids = {
    AviatrixGateway = azurerm_route_table.this["gateway"].id
    Internal1       = azurerm_route_table.this["internal1"].id
    Internal2       = azurerm_route_table.this["internal2"].id
    Internal3       = azurerm_route_table.this["internal1"].id
    Internal4       = azurerm_route_table.this["internal2"].id
    External1       = azurerm_route_table.this["public1"].id
    External2       = azurerm_route_table.this["public2"].id
    External3       = azurerm_route_table.this["public1"].id
    External4       = azurerm_route_table.this["public2"].id
  }

  depends_on = [
    azurerm_resource_group.this
  ]
}

module "spoke1_azure" {
  source  = "terraform-aviatrix-modules/mc-spoke/aviatrix"
  version = "1.5.0"

  cloud            = "Azure"
  name             = "${local.env_prefix}-spoke1"
  region           = var.azure_region
  account          = var.avx_ctrl_account_azure
  transit_gw       = module.azure_transit.transit_gateway.gw_name
  use_existing_vpc = true
  vpc_id           = format("%s:%s", module.vnet.vnet_name, azurerm_resource_group.this.name)
  gw_subnet        = var.gw_subnet_spoke1
  ha_gw            = false
  # hagw_subnet      = var.gw_subnet #Can be the same subnet, as in Azure subnets stretch AZ's.

  depends_on = [
    module.azure_transit,
    module.vnet
  ]
}

#================================== spoke 2 =====================================
resource "azurerm_resource_group" "RG_spoke2" {
  name     = "RG-spoke2"
  location = var.azure_region
}

resource "azurerm_route_table" "RT_spoke2" {
  for_each            = toset(["gateway", "internal1", "internal2", "public1", "public2"])
  name                = "spoke2-${each.value}"
  location            = var.azure_region
  resource_group_name = azurerm_resource_group.RG_spoke2.name

  #Only add blackhole routes for Internal route tables
  dynamic "route" {
    for_each = can(regex("internal", each.value)) ? ["dummy"] : [] #Trick to make block conditional. Count not available on dynamic blocks.
    content {
      name           = "Blackhole"
      address_prefix = "0.0.0.0/0"
      next_hop_type  = "None"
    }
  }

  lifecycle {
    ignore_changes = [route, ] #Since the Aviatrix controller will maintain the routes, we want to ignore any changes to them in Terraform.
  }
}


module "vnet2" {
  source              = "Azure/vnet/azurerm"
  vnet_name           = "${local.env_prefix}-vnet2"
  vnet_location       = var.azure_region
  use_for_each = true
  resource_group_name = azurerm_resource_group.RG_spoke2.name
  address_space       = [var.gw_subnet_spoke2, var.vnet_cidr_spoke2] #Use a separate CIDR for gateways, to optimize usable IP space for workloads.
  subnet_prefixes = [
    var.gw_subnet_spoke2,
    cidrsubnet(var.vnet_cidr_spoke2, 3, 0),
    cidrsubnet(var.vnet_cidr_spoke2, 3, 1),
    cidrsubnet(var.vnet_cidr_spoke2, 3, 2),
    cidrsubnet(var.vnet_cidr_spoke2, 3, 3),
    cidrsubnet(var.vnet_cidr_spoke2, 3, 4),
    cidrsubnet(var.vnet_cidr_spoke2, 3, 5),
    cidrsubnet(var.vnet_cidr_spoke2, 3, 6),
    cidrsubnet(var.vnet_cidr_spoke2, 3, 7)
  ]
  subnet_names = [
    "AviatrixGateway",
    "Internal1",
    "Internal2",
    "Internal3",
    "Internal4",
    "External1",
    "External2",
    "External3",
    "External4",
  ]

  route_tables_ids = {
    AviatrixGateway = azurerm_route_table.RT_spoke2["gateway"].id
    Internal1       = azurerm_route_table.RT_spoke2["internal1"].id
    Internal2       = azurerm_route_table.RT_spoke2["internal2"].id
    Internal3       = azurerm_route_table.RT_spoke2["internal1"].id
    Internal4       = azurerm_route_table.RT_spoke2["internal2"].id
    External1       = azurerm_route_table.RT_spoke2["public1"].id
    External2       = azurerm_route_table.RT_spoke2["public2"].id
    External3       = azurerm_route_table.RT_spoke2["public1"].id
    External4       = azurerm_route_table.RT_spoke2["public2"].id
  }

  depends_on = [
    azurerm_resource_group.RG_spoke2
  ]
}

module "spoke2_azure" {
  source  = "terraform-aviatrix-modules/mc-spoke/aviatrix"
  version = "1.5.0"

  cloud            = "Azure"
  name             = "${local.env_prefix}-spoke2"
  region           = var.azure_region
  account          = var.avx_ctrl_account_azure
  transit_gw       = module.azure_transit.transit_gateway.gw_name
  use_existing_vpc = true
  vpc_id           = format("%s:%s", module.vnet2.vnet_name, azurerm_resource_group.RG_spoke2.name)
  gw_subnet        = var.gw_subnet_spoke2
  ha_gw            = false
  # hagw_subnet      = var.gw_subnet #Can be the same subnet, as in Azure subnets stretch AZ's.

  depends_on = [
    module.azure_transit,
    module.vnet2
  ]
}

# 1 - enable DFW
resource "aviatrix_distributed_firewalling_config" "test" {
  enable_distributed_firewalling = true
}


# # 2 - enable intra vpc DFW per vnet
resource "aviatrix_distributed_firewalling_intra_vpc" "test" {
# vpc_id
# "vpc_id": "VNet_name:RG_name:resourceGuid"
  
  vpcs {
    account_name = var.avx_ctrl_account_azure
    vpc_id       = module.spoke1_azure.vpc.vpc_id
    region       = var.azure_region
  }
}
  vpcs {
    account_name = var.avx_ctrl_account_azure
    vpc_id       = module.spoke2_azure.vpc.vpc_id
    region       = var.azure_region
  }
}
#   vpcs {
#     account_name = var.avx_ctrl_account_azure
#     vpc_id       = "${module.vnet2.vnet.name}:${module.vnet2.azurerm_virtual_network.vnet.resource_group_name}:${module.vnet2.azurerm_virtual_network.vnet.guid}"
#     region       = var.azure_region
#   }

#   depends_on = [
#     module.vnet,
#     module.vnet2
#   ]
# }