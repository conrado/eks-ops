# eks-ops

This was built by updating some versions of the tutorial described here:

https://learnk8s.io/terraform-eks

current working state is as follows

to put up the cluster and generate your kube config:

```
terraform init
terraform apply
aws eks --region sa-east-1 update-kubeconfig --name ice01
kubectl get pods
```

to deploy the sample app:

```
kubectl apply -f ./deployment.yml
kubectl apply -f ./service-loadbalancer.yml
kubectl apply -f ./ingress.yml
```

Following instruction on https://kubernetes-sigs.github.io/aws-load-balancer-controller/v2.2/deploy/installation/

added the eks helm repo:

```
helm repo add eks https://aws.github.io/eks-charts
kubectl apply -k "github.com/aws/eks-charts/stable/aws-load-balancer-controller//crds?ref=master"
helm install aws-load-balancer-controller eks/aws-load-balancer-controller -n kube-system --set clusterName=ice01 --set serviceAccount.create=false --set serviceAccount.name=aws-load-balancer-controller
```

