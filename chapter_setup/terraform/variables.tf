variable "region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-1"
}

variable "num_students" {
  description = "Number of students for the hands-on lab"
  type        = number
  default     = 3
}

variable "vpc_cidr_block" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnet_cidr" {
  description = "CIDR block for the subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "availability_zone" {
  description = "Availability zone for the subnet"
  type        = string
  default     = "ap-northeast-1a"
}

variable "az_index" {
  description = "Index of the availability zone to use"
  type        = number
  default     = 0
}

variable "instance_type" {
  description = "EC2 instance type for students"
  type        = string
  default     = "t3.xlarge"
}

variable "s3_bucket_name" {
  description = "S3 bucket name for storing SSH keys"
  default     = "cnd-handson-bucket"
}

variable "stage_name" {
  description = "API Gatewayのステージ名"
  type        = string
  default     = "default"
}

variable "handson_ingress_ports" {
  description = "List of ingress ports to allow"
  type        = list(number)
  default     = [22, 80, 443, 8080, 8443, 18080, 18443, 28080, 28443]
}