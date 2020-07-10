#!/bin/bash

. init.conf

# Create the metrics server
kubectl apply -f /opt/Source/metrics-server/components.yaml 

# Create the namespace and context
kubectl create namespace mongodb
kubectl config set-context $(kubectl config current-context) --namespace=mongodb

# Deploy and MongoDB Enterprise Operator
kubectl apply -f crds.yaml
kubectl apply -f mongodb-enterprise.yaml

# Create the credentials for main admin user
kubectl delete secret admin-user-credentials > /dev/null 2>&1
kubectl create secret generic admin-user-credentials \
  --from-literal=Username="${user}" \
  --from-literal=Password="${password}" \
  --from-literal=FirstName="${firstName}" \
  --from-literal=LastName="${lastName}"

#  Deploy OpsManager resources
## kubectl apply -f ops-mgr-resource-ext-np.yaml
kubectl apply -f ops-mgr-resource-ext-lb.yaml

# Monitor the progress until the OpsMgr app is ready
while true
do
    kubectl get om 
    eval status=$( kubectl get om -o json | jq .items[0].status.opsManager.phase )
    if [[ $status == "Running" ]];
    then
        break
    fi
    sleep 10
done

# get the OpsMgr URL and internal IP
opsMgrUrl=$( kubectl get om -o json | jq .items[0].status.opsManager.url )
opsMgrIp=$(  kubectl get pod/opsmanager-0 -o json | jq .status.podIP )
kubectl get svc/opsmanager-svc-ext
eval hostname=$( kubectl get svc/opsmanager-svc-ext -o json | jq .status.loadBalancer.ingress[0].hostname ) 
opsMgrUrlExt=http://${hostname}:$( kubectl get svc/opsmanager-svc-ext -o json | jq .spec.ports[0].port )

cat init.conf |sed -e '/opsMgrUrl/d' -e '/opsMgrIp/d' -e '/opsMgrUrlExt/d'> new
echo  opsMgrUrl="$opsMgrUrl"        | tee -a new
echo  opsMgrIp="$opsMgrIp"          | tee -a new
echo  opsMgrUrlExt=\""$opsMgrUrlExt"\"  | tee -a new

mv new init.conf