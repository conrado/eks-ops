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
