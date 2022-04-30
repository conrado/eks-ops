# most minimal sample of an EKS cluster provisioned with Terraform using SSL

motivation: most of the examples I found were either old, didn't use SSL, had a
lot of self-built terraform modules. In this demo we use only vendor modules or
the excellent [terraform-aws-modules](https://github.com/terraform-aws-modules)
community modules.

this demo includes the following:

- [x] everything is created with Terraform
- [x] Kubernetes on EKS using IRSA
- [x] AWS-Load-Balancer-Controller ingress with TLS
- [x] Route53 auto-configuration of domain names
- [x] ACM auto-provisioned certificates
- [x] Cloudfront distribution with some simple defaults (note that AWS requires
  that you verify your AWS account to use the CDN, contact AWS support for that)
- [ ] Flagger, Flux and Istio

## requirements for running this demo

- You **must** have an AWS account with a **registered domain** and/or
  **functioning hosted zone** ready to deploy to, and **Cloudfront enabled**
- You **must** customize the `domain_name` variable in `variables.tf`
- You *may* change `aws_region` to deploy elsewhere in `variables.tf`
- You *may* change `cluster_name` as well in `variables.tf`

assuming you are on mac, you need the following:

```console
brew install tfenv kubectl helm awscli
brew install fluxcd/tap/flux
brew install jq yq
tfenv install 1.1.9
```

## setup everything

Note: *you should substitute example.com, us-east-1 and mycluster with what you*
*configured in variables.tf*

to put up the cluster:

```console
terraform init
terraform apply
```

generate your kube config and see pods running:

```console
aws eks --region us-east-1 update-kubeconfig --name mycluster
kubectl get nodes
```

The ALB ingress only accepts HTTPS connections: [https://origin.example.com][1]

The real site should be available on Cloudflare CDN:

- [https://example.com][2]
- [https://www.example.com][3]
- [http://example.com][4] will redirect to https
- [http://www.example.com][5] will redirect to https

[1]: https://origin.example.com
[2]: https://example.com
[3]: https://www.example.com
[4]: http://example.com
[5]: http://www.example.com

from here we can add a service mesh, gitops, centralized logging, monitoring,
alerting, backup, autoscaling, instance termination handling, the list goes on

I would love any feedback in case you see some better way of doing things

## Cleanup

To remove all created resources:

```console
terraform destroy
```
