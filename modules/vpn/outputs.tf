output "security_group_id" {
  description = "Özel katmanlara erişim açmak için security modülüne verilir"
  value       = aws_security_group.vpn.id
}

output "instance_id" {
  value = aws_instance.pritunl.id
}

output "public_ip" {
  value = aws_eip.vpn.public_ip
}

output "admin_url" {
  value = "https://${aws_eip.vpn.public_ip}/"
}

output "setup_key_command" {
  description = "1. adım: web konsoluna girerken istenen setup key'i alır"
  value       = "aws ssm send-command --region ${data.aws_region.current.name} --instance-ids ${aws_instance.pritunl.id} --document-name AWS-RunShellScript --parameters 'commands=[\"pritunl setup-key\"]'"
}

output "default_password_command" {
  description = "2. adım: konsoldaki kurulum sihirbazı bittikten sonra ilk yönetici parolasını alır"
  value       = "aws ssm send-command --region ${data.aws_region.current.name} --instance-ids ${aws_instance.pritunl.id} --document-name AWS-RunShellScript --parameters 'commands=[\"pritunl default-password\"]'"
}

output "mongodb_uri" {
  description = "Kurulum sihirbazının sorduğu MongoDB adresi; Pritunl ile aynı makinede çalışıyor"
  value       = "mongodb://localhost:27017/pritunl"
}
