variable "vpc_id" {
  description = "VPC the platform runs in"
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnets (load balancer tier)"
  type        = list(string)
}

variable "private_subnet_ids" {
  description = "Private subnets (application and database tiers)"
  type        = list(string)
}

variable "cluster_id" {
  description = "ECS cluster ARN"
  type        = string
}

variable "https_listener_arn" {
  description = "HTTPS listener on the platform's application load balancer"
  type        = string
}
