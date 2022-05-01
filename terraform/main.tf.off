
module "bastion" {
  source = "./bastion"

  ssh_key_name    = "conrado@icekernel.com"
  vpc_id          = module.vpc.vpc_id
  public_subnets  = module.vpc.public_subnets
  private_subnets = module.vpc.private_subnets
  route53_zone_id = data.aws_route53_zone.zone.id
  instance_type   = "c6g.medium"
}
