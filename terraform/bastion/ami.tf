
data "aws_ami" "bastion" {

  owners      = ["099720109477"]
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-arm64-server*"]
  }
  filter {
    name   = "state"
    values = ["available"]
  }
}
