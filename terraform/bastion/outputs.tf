output "bastion_sg" {
  description = "security group that allows ssh access through bastion"
  value       = aws_security_group.bastion.id
}
