# cptdaks
simple demo of azure aks with internal loadbalancer and vnet integration

## AKS and Application Gateway ingress controller

![Overview AKS and AGW](img/aks.agw.02.overview.png "Overview AKS and AGW")

Based on:
- [Application Gateway Ingress Controller (AGIC) Annotations Reference](https://github.com/Azure/application-gateway-kubernetes-ingress/blob/master/docs/annotations.md#azure-waf-policy-for-path)
- [MS Docs AGIC tutorial](https://docs.microsoft.com/en-us/azure/application-gateway/tutorial-ingress-controller-add-on-existing)


Define some variables.

~~~ bash
prefix=cptdaks # Will be used to name most of our azure resources.
location=eastus # location where we will deploy our azure resources.
myip=$(curl ifconfig.io) # Just in case we like to whitelist our own ip.
myobjectid=$(az ad user list --query '[?displayName==`ga`].objectId' -o tsv) # just in case we like to assing some RBAC roles to ourself.
~~~

Create resource group and same basic resources.

~~~ bash
az group create -n $prefix -l $location
az deployment group create -n $prefix -g $prefix --template-file bicep/deploy.bicep -p myobjectid=$myobjectid myip=$myip prefix=$prefix
~~~

Create the AKS cluster.

~~~ bash
appgwid=$(az network application-gateway show -n $prefix -g $prefix -o tsv --query "id")
akssubnetid=$(az network vnet subnet show -n aks --vnet-name $prefix -g $prefix --query id -o tsv)
acrid=$(az acr show -n $prefix -g $prefix --query id -o tsv)
az aks create -n $prefix -g $prefix --network-plugin azure --enable-managed-identity --appgw-id $appgwid --vnet-subnet-id $akssubnetid --node-resource-group ${prefix}_MC -a ingress-appgw --service-cidr  '10.2.0.0/16' --dns-service-ip '10.2.0.10' --attach-acr $prefix -y
~~~

Deploy an app.

~~~ bash
az acr build -r $prefix -t cpt/ss:1.0 .
az aks get-credentials -g $prefix -n $prefix --overwrite-existing
wafruleredid=$(az network application-gateway waf-policy show -n ${prefix}red -g $prefix --query id -o tsv)
wafrulegreenid=$(az network application-gateway waf-policy show -n ${prefix}green -g $prefix --query id -o tsv)
cp templateapp.yaml k8s/redapp.yaml
sed -i "s|<wafrulerid>|${wafruleredid}|g" k8s/redapp.yaml
sed -i "s|<color>|red|g" k8s/redapp.yaml
cp k8s/greenapp.yaml k8s/blueapp.yaml
sed -i "s|green|blue|g" k8s/blueapp.yaml
cp templateapp.yaml greenapp.yaml
sed -i "s|<wafrulerid>|${wafrulegreenid}|g" k8s/greenapp.yaml
sed -i "s|<color>|green|g" k8s/greenapp.yaml
k apply -f k8s/redapp.yaml
k apply -f k8s/greenapp.yaml
k apply -f k8s/blueapp.yaml
~~~

Wait at least 5min and check afterwards if the ingress controller has already an ip assigned.

~~~ bash
k get ingress -A
~~~

There have been cases where I needed to delete the current ingress controller to trigger changes on AGW.

~~~ bash
k delete ingress greenapp -n green
k delete ingress redapp -n red
~~~

If the column ADDRESS does show an IP start testing.

Test WAF policy per http listner.

Test for httpListener on host "red.cptdaks.org".

~~~ bash
agwpubip=$(kubectl get ingress/redapp -n red -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
curl -s -o /dev/null -w "%{http_code}" -H"host: red.cptdaks.org" http://$agwpubip/ # We expect an 200 OK
curl -s -o /dev/null -w "%{http_code}" -H"host: red.cptdaks.org" http://$agwpubip/?test=green # We expect an 403
~~~

Test for httpListener on host "green.cptdaks.org".

~~~ bash
curl -s -o /dev/null -w "%{http_code}" -H"host: green.cptdaks.org" http://$agwpubip/ # We expect an 200 OK
curl -s -o /dev/null -w "%{http_code}" -H"host: green.cptdaks.org" http://$agwpubip/?test=red # We expect an 403 because of WAF Rule
~~~

Test global WAF policy.

~~~ bash
curl -s -o /dev/null -w "%{http_code}" -H"host: red.cptdaks.org" http://$agwpubip/?test=blue # We expect an 200 OK because of global WAF policy does only block query value blue.
curl -s -o /dev/null -w "%{http_code}" -H"host: blue.cptdaks.org" http://$agwpubip/?test=green # We expect an 200 OK because global WAF policy does only block query value blue.
curl -s -o /dev/null -w "%{http_code}" -H"host: blue.cptdaks.org" http://$agwpubip/?test=blue # We expect an 403 because global WAF policy does block query value blue. 
~~~

> CONCLUSION
> The more specific WAF policy will always win.
> To proof this we will setup a global WAF policy  


Clean up.

~~~ bash
az group delete -n $prefix -y
~~~

### Tips

#### Gateway Public IP

You should expect to get the public ip of the application gateway which can be checked as follow.

~~~ bash
agwpubipid=$(az network application-gateway show -n $prefix -g $prefix --query frontendIpConfigurations[].publicIpAddress.id -o tsv)
agwpubip=$(az network public-ip show --ids $agwpubipid --query ipAddress -o tsv)
~~~

#### Restart the application gateway

### Restart application gateway

Based on https://stackoverflow.com/questions/49788958/how-can-i-restart-application-gateway-in-azure

~~~ bash
az network application-gateway stop --id $appgwid
az network application-gateway start --id $appgwid
~~~

## Simple Web App Demo (Work in Progress)

> IMPORTANT: Not working yet !!

### Create Azure resources

~~~ text
az group delete -n $prefix -y
az group create -n $prefix -l eastus
az deployment group create -n $prefix -g $prefix --template-file bicep/deploy.bicep -p myobjectid=$myobjectid myip=$myip
az acr build -r $prefix -t cpt/ss:1.0 .
az aks get-credentials -g $prefix -n $prefix --overwrite-existing
~~~

### K8s Setup

~~~ text
k get nodes -o wide
k apply -f red/
k get service -n nsred -o wide
sudo kubectl port-forward -n nsred svc/svred 80
startedgeguest http://localhost
curl -v localhost
~~~

### SSH into VM via azure bastion client

Get the IP of the k8s service

~~~ text
k get services/svred  -n nsred -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
~~~

> IMPORTANT: The following commands need to executed on powershell.

You will need to replace the IP mentioned below with the one received above from the K8s.

~~~ pwsh
$prefix="cptdaks"
$vmid=az vm show -g $prefix -n ${prefix}lin --query id -o tsv
az network bastion ssh -n ${prefix}bastion -g $prefix --target-resource-id $vmid --auth-type "AAD"
curl -v http://10.1.0.66/
~~~


## Setup Prometheus

Based on https://techcommunity.microsoft.com/t5/apps-on-azure-blog/using-azure-kubernetes-service-with-grafana-and-prometheus/ba-p/3020459

~~~ text
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm install prometheus prometheus-community/kube-prometheus-stack -n monitoring --create-namespace
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090
startedgeguest http://localhost:9090
kubectl port-forward --namespace monitoring svc/prometheus-grafana 8080:80
startedgeguest http://localhost:8080
helm upgrade prometheus prometheus-community/kube-prometheus-stack -n monitoring --set kubeEtcd.enabled=false --set kubeControllerManager.enabled=false --set kubeScheduler.enabled=false 

~~~

The default username for Grafana is admin and the default password is prom-operator. You can change it in the Grafana UI later.






k get pods -n nsred
k get deployment -n nsred
k describe deployments -n nsred
k describe deployments -n nsred
redpodname=$(k get pods -n nsgreen -o json| jq -r .items[0].metadata.name)
k logs -f -n nsred $redpodname
curl 'http://10.1.0.6/'
curl 'http://192.168..0.6/?f=25'
watch kubectl top pods -n nsgreen
k get pods -n nsgreen -w
ab -s 500 -c 10 -n 20 http://192.168.0.6/
~~~







helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Misc

## Create Node.js App

~~~bash
npm init -y
code package.json
code .env
npm i dotenv
npm run start
cat /proc/cpuinfo
ps aux | grep index.js
top -p
curl 'http://localhost:8080/?f=40'
~~~

### Run Node App on a local Docker Container
~~~ text
sudo dockerd
docker build -t cpt/ss:1.0 .
docker run --name ss -d -p80:8080 cpt/ss:1.0
docker logs -f ss
curl 'http://localhost/'
curl 'http://localhost/?f=140'
docker exec -it ss ash
curl 'http://localhost:3000/?f=1'
curl 'http://localhost:8080/?f=1'
docker rm -f ss
~~~

## Docker Tips and tricks

~~~ text
docker images
docker ps -all
docker rm ss
docker rmi cpt/ss:1.0
~~~


## Docker

Create Dockerfile and add the following line:

Afterward execute the following commands:



## Bicep

~~~bash
code rg.bicep
code parameters.json
az deployment sub create -n cptdaks-create-rg -l eastus --template-file rg.bicep
cp ~/bicep/vm* .
az deployment group create -n cptdaks-create-vm -g cptdaks --template-file vm.bicep
cp rg.bicep acr.bicep
az deployment group create -n cptdaks-create-acr -g cptdaks --template-file acr.bicep
cp acr.bicep aks.bicep
az role definition list -n 'AcrPull' --query '[].name'
az role definition list -n 'Network Contributor' --query '[].name'
az deployment group create -g cptdaks -n cptdaks-aks-create --template-file aks.bicep 
az acr repository list -n cptdaks
az acr build -r cptdaks -t cpt/ss:1.0 .
az acr login -n cptdaks //why?
az aks list -g cptdaks -o table
az aks get-credentials -g cptdaks -n cptdaks
k get nodes -o wide

az ad sp show --id 'bccea724-7cac-41e8-a1eb-f47aa9230b6d'
~~~

## K8s

~~~bash
mkdir green
code green/ns.yaml
code green/dp.yaml
code green/sv.yaml
code green/pa.yaml
k apply -f green/
k get service -n nsgreen -o wide -w
k get pods -n nsgreen
k get deployment -n nsgreen
kubectl describe deployments -n nsgreen
greenpodname=$(k get pods -n nsgreen -o json| jq -r .items[0].metadata.name)
k logs -f -n nsgreen $greenpodname
curl 'http://10.1.0.6/'
curl 'http://192.168..0.6/?f=25'
watch kubectl top pods -n nsgreen
k get pods -n nsgreen -w
ab -s 500 -c 10 -n 20 http://192.168.0.6/
~~~

## K8s bonus

~~~bash
curl whatismyip.akamai.com
k get services -l cbase=ss -o wide -A
k get pods -l cbase=ss -A
k exec -it -n nsblue dpblue-8676d598dc-28dgw -- ash
curl 52.152.201.81
curl 52.226.110.101
curl 10.0.202.212
curl 10.0.140.210

k port-forward -n nsred svc/svred 9090:80
~~~

Create another color.

~~~ text
rm -r green
mkdir green
cp -r red/* green/
sed -i 's/red/green/g' ./green/*.yaml
tree -L 2  //In case you like to see the new folder structure
~~~

Chaos at AKS

~~~ text
helm repo add chaos-mesh https://charts.chaos-mesh.org
helm repo update
k create ns chaos-testing
helm install chaos-mesh chaos-mesh/chaos-mesh --namespace=chaos-testing --version 2.0.3 --set chaosDaemon.runtime=containerd --set chaosDaemon.socketPath=/run/containerd/containerd.sock
helm list -A
k get pods -n chaos-testing -l app.kubernetes.io/instance=chaos-mesh
k get pods --all-namespaces
watch kubectl top pods -n nsgreen
~~~

~~~ text
apiVersion: chaos-mesh.org/v1alpha1
kind: PodChaos
metadata:
  name: container-kill-example
  namespace: chaos-testing
spec:
  action: container-kill
  mode: one
  containerNames: ['prometheus']
  selector:
    labelSelectors:
      'app.kubernetes.io/component': 'monitor'
~~~


apiVersion: chaos-mesh.org/v1alpha1
kind: PodChaos
metadata:
  name: pod-failure-example
  namespace: chaos-testing
spec:
  action: pod-failure
  mode: one
  duration: '30s'
  selector:
    namespaces:
      - nsgreen




