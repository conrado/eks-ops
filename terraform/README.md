# eks-ops

This was built by updating some versions of the tutorial described here:

https://learnk8s.io/terraform-eks

current working state is as follows

to put up the cluster and generate your kube config:

```
terraform init
terraform apply
aws eks --region sa-east-1 update-kubeconfig --name ice01
kubectl get nodes
```

to deploy the sample app:

```
kubectl apply -f ./deployment.yml
kubectl apply -f ./service-loadbalancer.yml
```

Here you should be able to visit the ELB public endpoint for kubernetes test
app... on mac you can do that with the following command:

```
open http://$(kubectl get svc hello-kubernetes -o json | jq -r '.status.loadBalancer.ingress[0].hostname')
```

Following instruction on https://kubernetes-sigs.github.io/aws-load-balancer-controller/v2.2/deploy/installation/

added the eks helm repo:

```
helm repo add eks https://aws.github.io/eks-charts
kubectl apply -k "github.com/aws/eks-charts/stable/aws-load-balancer-controller//crds?ref=master"
```

I'm having problems with the IAM roles because nobody seems to have an
up-to-date tutorial on getting the terraform EKS module working right...

contrary to most tutorials using eksctl out there, we do need to create the
service account, so we will do not use `--set serviceAccount.create=false`
in the when installing the `aws-load-balancer-controller`

because we set `metadata_http_put_response_hop_limit = 2` in the eks module when
difining the eks_managed_node_groups we also do not need to set
`--set region=<aws-region>` or `--set vpcId=<vpc-id>`

```
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
    --set clusterName=ice01 \
    --set serviceAccount.create=false \
    --set serviceAccount.name=aws-load-balancer-controller \
    -n kube-system
```

then you should be able to apply the ALB ingress:

```
kubectl apply -f ./nodePort.yml
kubectl apply -f ./ingress.yml
```

That should overwrite the ELB service and setup an ALB ingress that accesses the
NodePort type service, connecting to the app's container node

Still TODO ... I have to figure out how the IAM policies should be wired up
correctly
