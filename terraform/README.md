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
kubectl port-forward service/hello-kubernetes 8080:8080
```

now you can test by pointint your browser locally to

http://localhost:8080

then you should be able to apply the ALB ingress:

```
kubectl apply -f ./nodePort.yml
kubectl apply -f ./ingress.yml
```

And now you should be able to connect to the app through the ALB over the
internet. You can lookup the ALB address with:

```
kubectl get ingress
```

be sure to use HTTP not HTTPS, as we are not yet using cert-manager...
