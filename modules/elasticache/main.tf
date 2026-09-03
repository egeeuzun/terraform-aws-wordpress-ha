resource "aws_elasticache_cluster" "memcached" {
  cluster_id      = "${var.name}-memcached"
  engine          = "memcached"
  node_type       = var.node_type
  num_cache_nodes = var.num_cache_nodes
  port            = 11211

  az_mode              = var.num_cache_nodes > 1 ? "cross-az" : "single-az"
  subnet_group_name    = aws_elasticache_subnet_group.this.name
  security_group_ids   = [var.cache_sg_id]
  parameter_group_name = "default.memcached1.6"

  tags = { Name = "${var.name}-memcached" }
}

resource "aws_elasticache_subnet_group" "this" {
  name       = "${var.name}-cache-subnets"
  subnet_ids = var.data_subnet_ids
}
