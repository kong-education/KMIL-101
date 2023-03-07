#!/bin/bash

# echo -e "\nConfiguring Kubernetes"
# sleep 0.5
# ./setup-k8s.sh > /dev/null 2>&1
# # kubectl cluster-info > /dev/null 2>&1

# echo -e "\nCloning Course Repo"
# git clone https://github.com/kong-education/KMIL-101.git > /dev/null 2>&1 && cd KMIL-101
# sleep 0.5
echo -e "\nDeploying Marketplace Application...."
kubectl apply -f 03/01-kong-mesh-demo-aio.yaml > /dev/null 2>&1
kubectl wait --for=condition=available --timeout=600s deployment/kuma-demo-app -n kong-mesh-demo
kubectl wait --for=condition=available --timeout=600s deployment/kong-mesh-demo-backend-v0 -n kong-mesh-demo
kubectl wait --for=condition=available --timeout=600s deployment/redis-master -n kong-mesh-demo
kubectl wait --for=condition=available --timeout=600s deployment/postgres-master -n kong-mesh-demo
# kubectl get pods -n kong-mesh-demo
sleep 0.5
echo -e "\nExposing ports"
kubectl port-forward svc/frontend -n kong-mesh-demo --address 0.0.0.0 8080:8080 > /dev/null 2>&1 &
# export KONG_MESH_DEMO=https://${AVL_PRIMARY_CONTAINER_EXTERNAL_DOMAIN#?}
sleep 0.5
# echo -e "\nNow browse to $KONG_MESH_DEMO"

echo -e "\nNow click on 'Marketplace Application' tab in the lab environment"

echo -e "\nAlternatively browse to $KONG_MESH_DEMO"

# undo
# kubectl delete -f 03/01-kong-mesh-demo-aio.yaml
# cd
# rm -rf KMIL-101

echo -e "\nDeploying Kong Mesh"

curl -sLX GET https://docs.konghq.com/mesh/installer.sh | VERSION="1.9.0" sh -
mkdir -p ~/.local/bin
mv $(find . -iname kumactl) ~/.local/bin/
source ~/.profile
kumactl install control-plane --license-path=/etc/kong/license.json|kubectl apply -f -

sleep 5

echo -e "\nConfiguring Kong Mesh"

kubectl expose deployment kong-mesh-control-plane -n kong-mesh-system \
  --type=NodePort --name=kongmesh-cp --port 5681
kubectl patch service kongmesh-cp --namespace=kong-mesh-system  --type='json' \
 --patch='[{"op": "replace", "path": "/spec/ports/0/nodePort", "value":30001}]'

sleep 2
kumactl config control-planes add --name=kongmesh-cp --address=$KONG_MESH_URI

curl -sX GET $KONG_MESH_URI | jq

kubectl get deployments -n kong-mesh-demo -o name | sed -e 's/.*\///g' | xargs -I {} kubectl patch deployment -n kong-mesh-demo {} --type='strategic' --patch='{"spec":{"template":{"metadata":{"labels":{"kuma.io/sidecar-injection":"enabled"}}}}}'

kill $(jobs -l|grep svc/frontend |awk -F" " '{print $2}')

kubectl port-forward svc/frontend -n kong-mesh-demo --address 0.0.0.0 8080:8080 > /dev/null 2>&1 &
