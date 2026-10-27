output "address" {
  value = aws_instance.db.private_ip
}

output "endpoint" {
  value = "${aws_instance.db.private_ip}:3306"
}

output "instance_id" {
  description = "Session Manager ile baglanmak icin: aws ssm start-session --target <id>"
  value       = aws_instance.db.id
}

output "data_volume_id" {
  value = aws_ebs_volume.data.id
}
