#----------------- AVIATRIX -----------------
variable "avx_controller_admin_password" {
  type        = string
  description = "[sensitive.auto.tfvars] - aviatrix controller admin password"
}
variable "controller_ip" {
  type        = string
  description = "[terraform.auto.tfvars] - aviatrix controller "
}
variable "aws_region" {
  type        = string
  description = "AWS Region"
  default     = "eu-west-2"
}

variable "azure_region" {
  type = string
  default = "West Europe"
}

variable "ssh_key" {
  type        = string
  description = "SSH key for the ubuntu VMs"

}

variable "aws_ssh_key" {
  type        = string
  description = "SSH key for the ubuntu VMs"

}

variable "pre_shared_key" {
  type    = string
  default = "some_key"
}

variable "avx_ctrl_account_azure" {
  type = string
}

variable "avx_ctrl_account_aws" {
  type = string
}

#========================= spoke 1
variable "gw_subnet_spoke1" {
  default = "192.168.1.0/24"
}

variable "vnet_cidr_spoke1" {
  default = "10.101.0.0/16"
}

#========================= spoke 2
variable "gw_subnet_spoke2" {
  default = "192.168.2.0/24"
}

variable "vnet_cidr_spoke2" {
  default = "10.102.0.0/16"
}


