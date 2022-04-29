# Developer Notes

## requirements for this demo

you'll need to have an AWS account with a registered domain and hosted zone ready
to deploy to. You should only need to customize the `domain_name` variable in
`./terraform/variables.tf` (or apply some .tfvars file) and the aws region you
wish to deploy to in `./terraform/providers.tf`

besides that, you probably need the following:

```console
tfenv install 1.1.9
brew install kubectl
brew install helm
```

## setup everything

to put up the cluster and generate your kube config:

```console
terraform init
terraform apply
aws eks --region sa-east-1 update-kubeconfig --name ice01
kubectl get nodes
```

The ALB ingress has been changed to accept only HTTPS connections.

It is now available on [https://origin.icekernelcloud01.com][1]

also try accessing the following to see Cloudflare CDN do some magic:

- [https://icekernelcloud01.com][2]
- [https://www.icekernelcloud01.com][3]
- [http://icekernelcloud01.com][4]
- [http://www.icekernelcloud01.com][5]

[1]: https://origin.icekernelcloud01.com
[2]: https://icekernelcloud01.com
[3]: https://www.icekernelcloud01.com
[4]: http://icekernelcloud01.com
[5]: http://www.icekernelcloud01.com
