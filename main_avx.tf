# # # #---------------------------------------------------------- Transit ----------------------------------------------------------

module "azure_transit" {
  source  = "terraform-aviatrix-modules/mc-transit/aviatrix"
  version = "2.4.1"
  name    = "${local.env_prefix}-AZ-trans-1"
  cloud   = "azure"
  region  = var.azure_region
  cidr    = "10.1.0.0/23"
  account = var.avx_ctrl_account_azure
  local_as_number = "65001"
}

module "azure_transit_2" {
  source  = "terraform-aviatrix-modules/mc-transit/aviatrix"
  version = "2.4.1"
  name    = "${local.env_prefix}-AZ-trans-2"
  cloud   = "azure"
  region  = var.azure_region
  cidr    = "10.2.0.0/23"
  account = var.avx_ctrl_account_azure
  local_as_number = "65002"
}

resource "aviatrix_transit_gateway_peering" "test_transit_gateway_peering" {
  transit_gateway_name1                       = module.azure_transit.transit_gateway.gw_name
  transit_gateway_name2                       = module.azure_transit_2.transit_gateway.gw_name

  enable_peering_over_private_network         = false
  enable_insane_mode_encryption_over_internet = false
}

resource "aviatrix_transit_external_device_conn" "conn1" {
  depends_on                    = [module.azure_transit]
  vpc_id                        = module.azure_transit.transit_gateway.vpc_id
  connection_name               = "conn1" 
  gw_name                       = module.azure_transit.transit_gateway.gw_name                 
  connection_type               = "bgp"
  tunnel_protocol               = "IPsec"
  bgp_local_as_num              = module.azure_transit.transit_gateway.local_as_number #"123"
  bgp_remote_as_num             = "65003"                                              
  remote_gateway_ip             = "51.144.121.165"                                       #"public_IP_VNG1, public_IP_VNG2"
  remote_tunnel_cidr            = "172.16.1.1/30,172.16.2.1/30"                      # ! replace with mod var - "169.254.21.1/30,169.254.22.1/30"
  local_tunnel_cidr             = "172.16.1.2/30,172.16.2.2/30"
  custom_algorithms             = true
  phase_1_authentication        = "SHA-256"
  phase_2_authentication        = "HMAC-SHA-256"
  phase_1_dh_groups             = "2"
  phase_2_dh_groups             = "5"
  phase_1_encryption            = "AES-256-CBC"
  phase_2_encryption            = "AES-256-CBC"
  ha_enabled                    = false
  enable_ikev2                  = true
         pre_shared_key     = "AvXtest$123"
  phase1_remote_identifier      = ["10.241.0.4"]
}

resource "aviatrix_transit_external_device_conn" "conn2" {
  depends_on                    = [module.azure_transit_2]
  vpc_id                        = module.azure_transit_2.transit_gateway.vpc_id
  connection_name               = "conn2" 
  gw_name                       = module.azure_transit_2.transit_gateway.gw_name                 
  connection_type               = "bgp"
  tunnel_protocol               = "IPsec"
  bgp_local_as_num              = module.azure_transit_2.transit_gateway.local_as_number #"123"
  bgp_remote_as_num             = "65003"                                              
  remote_gateway_ip             = "51.144.121.165"                                       #"public_IP_VNG1, public_IP_VNG2"
  remote_tunnel_cidr            = "172.16.3.1/30,172.16.4.1/30"                      # ! replace with mod var - "169.254.21.1/30,169.254.22.1/30"
  local_tunnel_cidr             = "172.16.3.2/30,172.16.4.2/30"
  custom_algorithms             = true
  phase_1_authentication        = "SHA-256"
  phase_2_authentication        = "HMAC-SHA-256"
  phase_1_dh_groups             = "2"
  phase_2_dh_groups             = "5"
  phase_1_encryption            = "AES-256-CBC"
  phase_2_encryption            = "AES-256-CBC"
  ha_enabled                    = false
  enable_ikev2                  = true
         pre_shared_key     = "AvXtest$123"
  phase1_remote_identifier      = ["10.241.0.4"]
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
  use_for_each        = true
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
  instance_size = "Standard_D2_v5"
  # hagw_subnet      = var.gw_subnet #Can be the same subnet, as in Azure subnets stretch AZ's.

  depends_on = [
    module.azure_transit,
    module.vnet
  ]
}

# #================================== spoke 2 =====================================
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
  use_for_each        = true
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



data "azurerm_virtual_network" "data_vnet1" {
  name                = "${local.env_prefix}-vnet1"
  resource_group_name = "RG-spoke1"
}

data "azurerm_virtual_network" "data_vnet2" {
  name                = "${local.env_prefix}-vnet2"
  resource_group_name = "RG-spoke2"
}

# 2 - enable intra vpc DFW per vnet
resource "aviatrix_distributed_firewalling_intra_vpc" "test" {
  # vpc_id
  # "vpc_id": "VNet_name:RG_name:resourceGuid"

  vpcs {
    account_name = var.avx_ctrl_account_azure
    vpc_id       = "${module.vnet.vnet_name}:${azurerm_resource_group.this.name}:${data.azurerm_virtual_network.data_vnet1.guid}"
    region       = var.azure_region
  }

  vpcs {
    account_name = var.avx_ctrl_account_azure
    vpc_id       = "${module.vnet2.vnet_name}:${azurerm_resource_group.RG_spoke2.name}:${data.azurerm_virtual_network.data_vnet2.guid}"
    region       = var.azure_region
  }

  depends_on = [
    data.azurerm_virtual_network.data_vnet1,
    data.azurerm_virtual_network.data_vnet2
  ]
}



module "spoke_1_vm1" {
  #source    = "git::https://github.com/conip/terraform-azure-instance-build-module.git"
  source               = "/mnt/c/ubuntu-subsystem/modules/terraform-azure-instance-build-module"
  name                 = "${local.env_prefix}spoke1-vm1"
  region               = var.azure_region
  rg_name              = azurerm_resource_group.this.name
  subnet_id            = lookup(module.vnet.vnet_subnets_name_id, "External1")
  vm_password          = "secretpass$123"
  enable_password_auth = true
  #ssh_key   = var.ssh_key
  public_ip = true

  tags = {
    env = "NAV"
  }

  depends_on = [
    module.vnet
  ]
}

module "spoke_1_vm2" {
  #source    = "git::https://github.com/conip/terraform-azure-instance-build-module.git"
  source               = "/mnt/c/ubuntu-subsystem/modules/terraform-azure-instance-build-module"
  name                 = "${local.env_prefix}spoke1-vm2"
  region               = var.azure_region
  rg_name              = azurerm_resource_group.this.name
  subnet_id            = lookup(module.vnet.vnet_subnets_name_id, "External2")
  vm_password          = "secretpass$123"
  enable_password_auth = true
  #ssh_key   = var.ssh_key
  public_ip = true

  tags = {
    env = "AVD"
  }

  depends_on = [
    module.vnet
  ]
}

module "spoke_1_vm3" {
  #source    = "git::https://github.com/conip/terraform-azure-instance-build-module.git"
  source               = "/mnt/c/ubuntu-subsystem/modules/terraform-azure-instance-build-module"
  name                 = "${local.env_prefix}spoke1-vm3"
  region               = var.azure_region
  rg_name              = azurerm_resource_group.this.name
  subnet_id            = lookup(module.vnet.vnet_subnets_name_id, "External2")
  vm_password          = "secretpass$123"
  enable_password_auth = true
  #ssh_key   = var.ssh_key
  public_ip = true

  tags = {
    env = "Other"
  }

  depends_on = [
    module.vnet
  ]
}

module "spoke_2_vm4" {
  #source    = "git::https://github.com/conip/terraform-azure-instance-build-module.git"
  source               = "/mnt/c/ubuntu-subsystem/modules/terraform-azure-instance-build-module"
  name                 = "${local.env_prefix}spoke2-vm4"
  region               = var.azure_region
  rg_name              = azurerm_resource_group.RG_spoke2.name
  subnet_id            = lookup(module.vnet2.vnet_subnets_name_id, "External1")
  vm_password          = "secretpass$123"
  enable_password_auth = true
  #ssh_key   = var.ssh_key
  public_ip = true

  tags = {
    env = "Other"
  }

  depends_on = [
    module.vnet2
  ]
}


# module "spoke_test" {
#   #source    = "git::https://github.com/conip/terraform-azure-instance-build-module.git"
#   source               = "/mnt/c/ubuntu-subsystem/modules/Heineken/terraform-aviatrix-az-spoke-sgw"

#   name = "hein-spoke1"
#   cidr_user = "10.222.0.0/16"
#   cidr_spoke_gw = "192.168.33.0/26"
#   region = "West Europe"
#   transit_gw = {
#     "West Europe" = "DFW-AZ-trans-1"
#   }
#   account_name = "AZURE-pkonitz"
#   prefix = false
#   suffix = false
#   ha_gw = true

#   attached = true
  
# }



