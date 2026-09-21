variable "cluster_name" {
  type = string
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "single_nat_gateway" {
  description = "Use one NAT gateway instead of one per AZ. Set false for prod (AZ fault isolation), true for dev to cut cost."
  type        = bool
  default     = true
}

variable "tags" {
  type    = map(string)
  default = {}
}
