variable "cluster_name" {
  type = string
}

variable "kubernetes_version" {
  type    = string
  default = "1.30"
}

variable "cluster_role_arn" {
  type = string
}

variable "node_role_arn" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "public_subnet_ids" {
  type = list(string)
}

variable "public_access_cidrs" {
  type    = list(string)
  default = ["0.0.0.0/0"] # tighten to office/VPN CIDRs in prod
}

variable "system_instance_types" {
  type    = list(string)
  default = ["t3.medium"]
}

variable "system_desired_size" {
  type    = number
  default = 2
}

variable "system_min_size" {
  type    = number
  default = 2
}

variable "system_max_size" {
  type    = number
  default = 4
}

variable "app_instance_types" {
  type    = list(string)
  default = ["m6i.large"]
}

variable "app_capacity_type" {
  description = "ON_DEMAND or SPOT. Use SPOT for dev/staging app node group to cut cost."
  type        = string
  default     = "ON_DEMAND"
}

variable "app_desired_size" {
  type    = number
  default = 3
}

variable "app_min_size" {
  type    = number
  default = 3
}

variable "app_max_size" {
  type    = number
  default = 10
}

variable "tags" {
  type    = map(string)
  default = {}
}
