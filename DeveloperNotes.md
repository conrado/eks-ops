# Developer Notes

## setup everything

to put up the cluster and generate your kube config:

```console
terraform init
terraform apply
aws eks --region sa-east-1 update-kubeconfig --name ice01
kubectl get nodes
```

to deploy the sample app (let's work on automating this next):

```console
kubectl apply -f ./deployment.yml
kubectl apply -f ./nodePort.yml
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