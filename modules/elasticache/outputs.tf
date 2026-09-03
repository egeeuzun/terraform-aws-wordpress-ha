output "configuration_endpoint" {
  description = "Auto Discovery destekleyen istemciler için. Auto Discovery kullanmayan bir istemci bu adresi çözdüğünde node'lardan yalnızca birine bağlanır ve hangisine bağlanacağı garanti değildir."
  value       = aws_elasticache_cluster.memcached.configuration_endpoint
}

output "cluster_address" {
  value = aws_elasticache_cluster.memcached.cluster_address
}

output "node_addresses" {
  description = "Tekil node adresleri. Auto Discovery yapmayan istemcilerde hepsi birden verilmeli; libmemcached anahtarları node'lara deterministik dağıtır, böylece bütün task'lar aynı anahtar için aynı node'a gider."
  value       = [for n in aws_elasticache_cluster.memcached.cache_nodes : n.address]
}

output "primary_node_address" {
  description = "Tek sunucu bekleyen istemciler için sabit adres. Configuration endpoint'in aksine hangi node olduğu değişmez, dolayısıyla bütün task'lar aynı cache'i paylaşır."
  value       = aws_elasticache_cluster.memcached.cache_nodes[0].address
}
