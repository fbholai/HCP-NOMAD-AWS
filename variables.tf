variable "allowed_inbound_cidrs" {
  type        = list(string)
  description = "List of CIDR blocks to permit inbound Nomad access from"
  default = ["0.0.0.0/0"]
}

variable "aws_region"{
  type = string
  description = "which region you want to deploy?"
  default = "eu-central-1"
}
variable "bootstrap" {
  type        = bool
  default     = true
  description = "Initial Bootstrap configurations"
}

variable "nomad_clients" {
  default     = "3"
  description = "number of Nomad instances"
}

variable "nomad_servers" {
  default     = "3"
  description = "number of Nomad instances"
}
variable "consul_config" {
  description = "HCL Object with additional configuration overrides supplied to the consul servers.  This is converted to JSON before rendering via the template."
  default     = {}
}

variable "consul_cluster_version" {
  default     = "0.0.1"
  description = "Custom Version Tag for Upgrade Migrations"
}

variable "consul_version" {
  description = "Which Consul version you want to deploy?"
}

variable "nomad_version" {
  description = "Which Nomad version you want to deploy?"
}

variable "enable_connect" {
  type        = bool
  description = "Whether Consul Connect should be enabled on the cluster"
  default     = false
}

variable "instance_type" {
  default     = "t2.micro"
  description = "Instance type for Consul instances"
}

variable "key_name" {
  default     = "hashicorp"
  description = "SSH key name for Consul instances"
}

variable "name_prefix" {
  description = "Which prefix you want to use in resource names?"
}

variable "owner" {
  description = "What is the owner tag?"
}

variable "public_ip" {
  type        = bool
  default     = true
  description = "should ec2 instance have public ip?/set to true or false"
}

variable "vpc_id" {
  description = "What is the VPC-ID you want your infrastructure to deploy in?"
}
