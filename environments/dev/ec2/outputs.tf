output "instance_id" {
  description = "ID of the EC2 instance."
  value       = aws_instance.main.id
}

output "public_ip" {
  description = "Public IP of the EC2 instance (empty when the subnet does not auto-assign one)."
  value       = aws_instance.main.public_ip
}

output "private_ip" {
  description = "Private IP of the EC2 instance."
  value       = aws_instance.main.private_ip
}

output "ami_id" {
  description = "AMI ID the instance was launched from."
  value       = aws_instance.main.ami
}

output "availability_zone" {
  description = "Availability Zone of the instance."
  value       = aws_instance.main.availability_zone
}
