variable "name" {
  type = string
}

variable "data_subnet_ids" {
  type = list(string)
}

variable "cache_sg_id" {
  type = string
}

variable "node_type" {
  type    = string
  default = "cache.t3.micro"
}

variable "num_cache_nodes" {
  type    = number
  default = 2
}
