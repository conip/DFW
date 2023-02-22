# # #---------------------------------------------------------- Transit ----------------------------------------------------------
module "mc_transit" {
  source                        = "terraform-aviatrix-modules/mc-transit/aviatrix"
  version                       = "v2.2.1"
  cloud                         = "AWS"
  name                          = "${local.env_prefix}-AZ-trans-1"
  region                        = var.aws_region
  cidr                          = "10.200.0.0/23"
  account                       = var.avx_ctrl_account_aws
  ha_gw                         = true
  local_as_number               = "65100"
  enable_transit_firenet        = true
  enable_advertise_transit_cidr = true
  tags = {
    Owner = "pkonitz"
    Blog  = "post10"
  }
}


module "mc-spoke1" {
  source     = "terraform-aviatrix-modules/mc-spoke/aviatrix"
  version    = "1.3.1"
  cloud      = "AWS"
  name       = "${local.env_prefix}-AWS-spoke-1"
  region     = var.aws_region
  cidr       = "10.201.0.0/23"
  account    = var.avx_ctrl_account_aws
  ha_gw         = false
  transit_gw = module.mc_transit.transit_gateway.gw_name
}

# module "mc-spoke2" {
#   source     = "terraform-aviatrix-modules/mc-spoke/aviatrix"
#   version    = "1.3.1"
#   cloud      = "AWS"
#   name       = "${local.env_prefix}-AWS-spoke-2"
#   region     = var.aws_region
#   cidr       = "10.202.0.0/23"
#   account    = var.avx_ctrl_account_aws
#   ha_gw      = false
#   transit_gw = module.mc_transit.transit_gateway.gw_name
# }

# module "mc-spoke3" {
#   source     = "terraform-aviatrix-modules/mc-spoke/aviatrix"
#   version    = "1.3.1"
#   cloud      = "AWS"
#   name       = "${local.env_prefix}-AWS-vpn-spoke"
#   region     = "eu-west-1"
#   cidr       = "10.203.0.0/23"
#   account    = var.avx_ctrl_account_aws
#   ha_gw      = false
#   transit_gw = module.mc_transit.transit_gateway.gw_name
# }

# # Create an Aviatrix AWS Gateway with VPN enabled
# resource "aviatrix_gateway" "test_vpn_gateway_aws" {
#   cloud_type   = 1
#   account_name = var.avx_ctrl_account_aws
#   gw_name      = "vpn-gw-1"
#   vpc_id       = module.mc-spoke3.vpc.vpc_id
#   vpc_reg      = "eu-west-1"
#   gw_size      = "t2.micro"
#   subnet       = module.mc-spoke3.vpc.public_subnets[0].cidr
#   vpn_access   = true
#   vpn_cidr     = "192.168.43.0/24"
#   max_vpn_conn = "100"
#   enable_elb   = true
# }


# # Create an Aviatrix AWS VPN User Profile
# resource "aviatrix_vpn_profile" "vpn_profile_1" {
#   name      = "DB_access"
#   base_rule = "allow_all"
# }

# # Create an Aviatrix VPN User
# resource "aviatrix_vpn_user" "test_vpn_user" {
#   vpc_id     = module.mc-spoke3.vpc.vpc_id
#   gw_name    = aviatrix_gateway.test_vpn_gateway_aws.gw_name
#   user_name  = "username1"
#   user_email = "pkonitz@aviatrix.com"
#   manage_user_attachment = true
#   profiles = [aviatrix_vpn_profile.vpn_profile_1.name]
# }