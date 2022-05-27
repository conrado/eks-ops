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
