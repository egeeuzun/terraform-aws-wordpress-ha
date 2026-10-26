output "state_bucket" {
  value = aws_s3_bucket.state.id
}

output "backend_hcl" {
  description = "envs/<ortam>/backend.hcl icerigi"
  value       = <<-EOT
    bucket = "${aws_s3_bucket.state.id}"
    region = "${var.region}"
  EOT
}
