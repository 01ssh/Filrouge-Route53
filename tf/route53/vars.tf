variable "ACCOUNT" {
description = "Hashicorp IO organisation name to provide"
type = string
}

variable "VAULT_ADDR" {
default     = "https://aws-wordpress-vault-cluster-public-vault-04cc1d86.d4f84486.z1.hashicorp.cloud:8200"
description = "Hashicorp Vault Token"
type = string
}

variable "CICD_VAULT_TOKEN" {
default     = "hvs.CAESILE9FpmLlaKX-tELBplbJkBlS9SVqkPybFLP144WnQUbGigKImh2cy5jVlFZcnowRERUbWhwNXRId1ViMDVXaTQuYkhudmsQirER"
description = "Hashicorp Vault Token"
type = string
}

variable "PROFILE" {
default     = "admin"
description = "Hashicorp IO organisation name to provide"
type = string
}

variable "ENV_WORKSPACE" {
default     = "development"
description = "ENV_WORKSPACE"
type = string
}

variable "domain_name" {
default     = "solcomputing.net"
description = "solcomputing.net"
type = string
}

variable "hosts_domain" {
  default   = ["blog"]
  type      = list(string)
}

variable "hostame" {
default     = "blog"
description = "blog"
type        = string
}
