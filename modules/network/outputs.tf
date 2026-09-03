output "vpc_id" {
  value = aws_vpc.this.id
}

output "vpc_cidr" {
  value = aws_vpc.this.cidr_block
}

output "azs" {
  description = "VPC'nin yayıldığı AZ'ler, public_subnet_map sırasıyla"
  value       = local.public_azs
}

output "public_subnet_ids" {
  value = aws_subnet.public[*].id
}

output "app_subnet_ids" {
  value = aws_subnet.app[*].id
}

output "data_subnet_ids" {
  value = aws_subnet.data[*].id
}

output "public_subnet_id_by_az" {
  description = "AZ -> public subnet id. Belirli bir AZ'ye kaynak sabitlemek için (ör. Pritunl 1a'da)."
  value       = { for idx, s in var.public_subnet_map : s.az => aws_subnet.public[idx].id }
}

output "app_subnet_id_by_az" {
  value = { for idx, s in var.app_subnet_map : s.az => aws_subnet.app[idx].id }
}

output "data_subnet_id_by_az" {
  value = { for idx, s in var.data_subnet_map : s.az => aws_subnet.data[idx].id }
}

output "nat_gateway_ids" {
  value = aws_nat_gateway.this[*].id
}

output "nat_public_ips" {
  description = "AZ başına NAT çıkış IP'leri; dış servislerde IP allowlist'i için"
  value       = aws_eip.nat[*].public_ip
}

output "internet_gateway_id" {
  value = aws_internet_gateway.this.id
}
