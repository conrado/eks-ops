locals {
  role = "bastion"
}

resource "aws_elb" "bastion" {
  name            = local.role
  subnets         = var.public_subnets
  security_groups = [aws_security_group.bastion.id]

  listener {
    instance_port     = 22
    instance_protocol = "tcp"
    lb_port           = 22
    lb_protocol       = "tcp"
  }

}

resource "aws_security_group" "bastion" {
  name        = local.role
  description = "Allow only inbound ssh traffic"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  lifecycle {
    create_before_destroy = true
  }
}

# data "template_file" "cloud_config_bastion" {
#   template = file("${path.root}/templates/cloud-config.tpl")
#   vars = {
#     ROLE = local.role
#   }
# }

resource "aws_launch_configuration" "bastion" {
  name_prefix   = "${local.role}-"
  image_id      = data.aws_ami.bastion.id
  instance_type = var.instance_type
  key_name      = var.ssh_key_name
  # iam_instance_profile = var.iam_profile
  security_groups = [
    aws_security_group.bastion.id,
  ]
  lifecycle {
    create_before_destroy = true
  }
  # user_data = data.template_file.cloud_config_bastion.rendered
}

resource "aws_autoscaling_group" "bastion" {
  # availability_zones        = module.vpc.azs
  name                      = local.role
  max_size                  = 1
  min_size                  = 1
  health_check_grace_period = 300
  health_check_type         = "ELB"
  desired_capacity          = 1
  force_delete              = false
  termination_policies      = ["OldestInstance"]
  vpc_zone_identifier       = var.private_subnets
  launch_configuration      = aws_launch_configuration.bastion.name
  wait_for_capacity_timeout = 0

  load_balancers = [
    aws_elb.bastion.name,
  ]

  enabled_metrics = [
    "GroupMinSize",
    "GroupMaxSize",
    "GroupDesiredCapacity",
    "GroupInServiceInstances",
    "GroupPendingInstances",
    "GroupStandbyInstances",
    "GroupTerminatingInstances",
    "GroupTotalInstances",
  ]

  lifecycle {
    create_before_destroy = false
  }

  tag {
    key                 = "Name"
    value               = local.role
    propagate_at_launch = true
  }

  tag {
    key                 = "role"
    value               = local.role
    propagate_at_launch = true
  }
}

resource "aws_route53_record" "bastion" {
  name    = local.role
  type    = "CNAME"
  ttl     = "300"
  zone_id = var.route53_zone_id
  records = [aws_elb.bastion.dns_name]
}
