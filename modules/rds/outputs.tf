output "endpoint" {
  value = aws_db_instance.primary.endpoint
}

output "address" {
  value = aws_db_instance.primary.address
}

output "replica_address" {
  value = try(aws_db_instance.replica[0].address, null)
}

output "db_arn" {
  value = aws_db_instance.primary.arn
}

output "db_name" {
  value = aws_db_instance.primary.db_name
}

output "db_username" {
  value = aws_db_instance.primary.username
}
