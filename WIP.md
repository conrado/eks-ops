# WIP notes

attempting app-mesh deploy, going off of this tutorial and converting it to
terraform.

https://www.eksworkshop.com/advanced/330_servicemesh_using_appmesh/

## EKS Fargate and Observability Setup

COMPLETE

## Deploy Product Catalog App

- added docker build script and dockerfiles

  `./build-images.sh` should build and push the images

  this means that we will have broken our pure IaC setup with this manual step.
  Correcting it will be left for after the tutorial is complete

- got base app running.

  there are a few tests to see if thigns are running... I'm usually running
  inside an alpine shell and hitting these up:

  `curl http://prodcatalog.prodcatalog-ns.svc.cluster.local:5000/products/`

## Install AWS AppMesh Controller

added aws appmesh controller.

to verify check the following have the correct output

```
kubectl get deployment appmesh-controller \
    -n appmesh-system \
    -o json  | jq -r ".spec.template.spec.containers[].image" | cut -f2 -d ':'

kubectl get crds | grep appmesh

kubectl -n appmesh-system get all
```
