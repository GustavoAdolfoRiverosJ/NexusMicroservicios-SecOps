variable "aws_region" {
  description = "Region AWS donde se desplegara Nexus SecOps"
  type        = string
  default     = "us-east-1"
}

variable "ami_id" {
  description = "AMI Ubuntu Server usada para las instancias"
  type        = string
}

variable "key_name" {
  description = "Nombre del key pair SSH"
  type        = string
  default     = "nexus-secops-key"
}

variable "my_ip_cidr" {
  description = "CIDR permitido para administracion"
  type        = string
  default     = "0.0.0.0/0"
}
