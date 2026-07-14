output "nexus_ci_public_ip" {
  value = aws_instance.nexus_ci.public_ip
}

output "nexus_app_public_ip" {
  value = aws_instance.nexus_app.public_ip
}

output "nexus_secops_public_ip" {
  value = aws_instance.nexus_secops.public_ip
}
