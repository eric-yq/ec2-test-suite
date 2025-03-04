# web0
output "instance_id_0" {
  description = "ID of the EC2 instance"
  value       = aws_instance.sut_server[0].id
}

output "instance_public_ip_0" {
  description = "Public IP address of the EC2 instance"
  value       = aws_instance.sut_server[0].public_ip
}

output "instance_private_ip_0" {
  description = "Private IP address of the EC2 instance"
  value       = aws_instance.sut_server[0].private_ip
}

# web1
output "instance_id_1" {
  description = "ID of the EC2 instance"
  value       = aws_instance.sut_server_1[0].id
}

output "instance_public_ip_1" {
  description = "Public IP address of the EC2 instance"
  value       = aws_instance.sut_server_1[0].public_ip
}

output "instance_private_ip_1" {
  description = "Private IP address of the EC2 instance"
  value       = aws_instance.sut_server_1[0].private_ip
}