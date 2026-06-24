variable "region" {
  default = "us-east-1"
}

variable "mysql_username" {
  description = "MySQL RDS master username"
  type        = string
  default     = "helen_mysql_admin"
}

variable "mysql_password" {
  description = "MySQL RDS master password"
  type        = string
  sensitive   = true
}

variable "pg_username" {
  description = "PostgreSQL RDS master username"
  type        = string
  default     = "helen_pg_admin"
}

variable "pg_password" {
  description = "PostgreSQL RDS master password"
  type        = string
  sensitive   = true
}
