# master
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

# master1
output "instance_id_01" {
  description = "ID of the EC2 instance"
  value       = aws_instance.sut_server[1].id
}

output "instance_public_ip_01" {
  description = "Public IP address of the EC2 instance"
  value       = aws_instance.sut_server[1].public_ip
}

output "instance_private_ip_01" {
  description = "Private IP address of the EC2 instance"
  value       = aws_instance.sut_server[1].private_ip
}

# master2
output "instance_id_02" {
  description = "ID of the EC2 instance"
  value       = aws_instance.sut_server[2].id
}

output "instance_public_ip_02" {
  description = "Public IP address of the EC2 instance"
  value       = aws_instance.sut_server[2].public_ip
}

output "instance_private_ip_02" {
  description = "Private IP address of the EC2 instance"
  value       = aws_instance.sut_server[2].private_ip
}

# slave
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

# slave1
output "instance_id_11" {
  description = "ID of the EC2 instance"
  value       = aws_instance.sut_server_1[1].id
}

output "instance_public_ip_11" {
  description = "Public IP address of the EC2 instance"
  value       = aws_instance.sut_server_1[1].public_ip
}

output "instance_private_ip_11" {
  description = "Private IP address of the EC2 instance"
  value       = aws_instance.sut_server_1[1].private_ip
}

# slave2
output "instance_id_12" {
  description = "ID of the EC2 instance"
  value       = aws_instance.sut_server_1[2].id
}

output "instance_public_ip_12" {
  description = "Public IP address of the EC2 instance"
  value       = aws_instance.sut_server_1[2].public_ip
}

output "instance_private_ip_12" {
  description = "Private IP address of the EC2 instance"
  value       = aws_instance.sut_server_1[2].private_ip
}