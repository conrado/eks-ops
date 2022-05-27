#!/bin/sh

source ./set-env.sh
envsubst < ./deployment/base_app.yaml | kubectl apply -f -

