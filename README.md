# cptdaks
simple demo of azure aks with internal loadbalancer and vnet integration

## AKS and Application Gateway ingress controller

![Overview AKS and AGW](img/aks.agw.02.overview.png "Overview AKS and AGW")

Based on:
- [Application Gateway Ingress Controller (AGIC) Annotations Reference](https://github.com/Azure/application-gateway-kubernetes-ingress/blob/master/docs/annotations.md#azure-waf-policy-for-path)
- [MS Docs AGIC tutorial](https://docs.microsoft.com/en-us/azure/application-gateway/tutorial-ingress-controller-add-on-existing)


### Define some variables

~~~ bash
prefix=cptdaks # Will be used to name most of our azure resources.
location=eastus # location where we will deploy our azure resources.
myip=$(curl ifconfig.io) # Just in case we like to whitelist our own ip.
myobjectid=$(az ad user list --query '[?displayName==`ga`].objectId' -o tsv) # just in case we like to assing some RBAC roles to ourself.
~~~

### Create resource group and same basic resources

~~~ bash
az group create -n $prefix -l $location
az deployment group create -n $prefix -g $prefix --template-file bicep/deploy.bicep -p myobjectid=$myobjectid myip=$myip prefix=$prefix
appgwid=$(az network application-gateway show -n $prefix -g $prefix -o tsv --query "id")
akssubnetid=$(az network vnet subnet show -n aks --vnet-name $prefix -g $prefix --query id -o tsv)
acrid=$(az acr show -n $prefix -g $prefix --query id -o tsv)
az aks create -n $prefix -g $prefix --network-plugin azure --enable-managed-identity --appgw-id $appgwid --vnet-subnet-id $akssubnetid --node-resource-group ${prefix}_MC -a ingress-appgw --service-cidr  '10.2.0.0/16' --dns-service-ip '10.2.0.10' --attach-acr $prefix -y
~~~

### Upload container image to our container registry

~~~ bash
az acr build -r $prefix -t cpt/ss:1.0 .
~~~

### Deploy app with waf enabled.

~~~ bash
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

### Test WAF policy per http listner.

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
---
## AKS, AGW and the Rule Path Engine

based on: https://azure.github.io/application-gateway-kubernetes-ingress/tutorials/tutorial.e2e-ssl/

We like to mimic the following flow use cases:

### Use case backend-path-prefix

AGW to modify the incoming url request of the client by adding the prefix "/ssoauth" to the path:

~~~ mermaid
sequenceDiagram
    participant Client
    participant AGW
    participant AKS

    Client->>AGW: GET
    Note right of AGW: Append /ssoauth
    AGW-->>AKS: fws GET /ssoauth/
    Note right of AKS: Process request /ssoauth/ 
    AKS->>AGW: 200 OK
    AGW->>Client: fwd 200 OK
~~~

### Use case ssl-redirect

Redirect all traffic to https. Independend of the url path.

~~~ mermaid
sequenceDiagram
    participant Client
    participant AGW
    participant AKS

    Client->>AGW: GET /
    Note right of AGW: Identify HTTP protocol 
    AGW->>Client: 301 redirec to HTTPS
~~~

### Use case cookie-based-affinity

Allow AGW to add an cookie to the client request so that the client can be directed allways to the same backend/pod inside the AKS cluster for the url path /red and /admin.

~~~ mermaid
sequenceDiagram
    participant Client
    participant AGW
    participant AKS

    Client->>AGW: GET /red
    AGW-->>AKS: fwd GET /red
    Note right of AKS: Process request /red 
    AKS->>AGW: 200 OK
    Note right of AGW: Append sticky cookie
    AGW->>Client: fwd 200 OK + sticky cookie
~~~

To make things a little bit more challenging we will combine the three use cases as follow

~~~ mermaid
flowchart TD
    A[Start] --> B{Is HTTPS?}
    B -->|Yes| E{path /red?}
    B -->|No| C[ssl-redirect HTTP 2 HTTPS]
    E -->|No| F[Append /ssoauth to fwd req]
    E -->|Yes| G[Response with cookie-based-affinity]
~~~

### Create resources

Please follow the steps

- [Define some variables](#define-some-variables)
- [Create resource group and same basic resources](#create-resource-group-and-same-basic-resources)
- [Upload container image to our container registry](#upload-container-image-to-our-container-registry)

After the deployments have been finished please follow the steps described next.

### Create TLS Certificates

> IMPORTANT: This steps are optional and only needed if you like to use your own certificates. By default we use the once which already existing under the folder openssl.

~~~ bash
openssl ecparam -out fe.cptdaks.key -name prime256v1 -genkey # Create the frontend certificate which will be presented by the AGW.
openssl req -new -sha256 -key fe.cptdaks.key -out fe.cptdaks.csr -subj "/CN=fe.cptdaks.org"
openssl x509 -req -sha256 -days 365 -in fe.cptdaks.csr -signkey fe.cptdaks.key -out fe.cptdaks.crt # Create the backend certificate which will be presented by the AKS.
openssl ecparam -out be.cptdaks.key -name prime256v1 -genkey
openssl req -new -sha256 -key be.cptdaks.key -out be.cptdaks.csr -subj "/CN=be.cptdaks.org"
openssl x509 -req -sha256 -days 365 -in be.cptdaks.csr -signkey be.cptdaks.key -out be.cptdaks.crt
~~~

### Add the certificates to the Application Gateway.

> NOTE: In case you created your own certificates please take care to update the following command lines if needed.

~~~ bash
az network application-gateway root-cert create --gateway-name $prefix  -g $prefix -n backend-tls --cert-file openssl/be.cptdaks.crt # Add trusted certificates to agw.
az network application-gateway root-cert create --gateway-name $prefix  -g $prefix -n frontend-tls --cert-file openssl/fe.cptdaks.crt # Add trusted certificates to agw.
az network application-gateway root-cert list --gateway-name $prefix -g $prefix --query [].name # List certificates of our agw.
~~~

### Create all needed resources for the AKS.

~~~ bash
az aks get-credentials -g $prefix -n $prefix --overwrite-existing # Login to AKS.
k create ns color # create namespace color.
# Create the secrets inside the AKS
k create secret tls frontend-tls --key="openssl/fe.cptdaks.key" --cert="openssl/fe.cptdaks.crt" -n color
k create secret tls backend-tls --key="openssl/be.cptdaks.key" --cert="openssl/be.cptdaks.crt" -n color
k get secret -n color # Check if the secrets are created correctly.
k apply -f k8s/nas/colorapp.yaml # Apply again, this time we should see ingress to be configred
k exec -it redapp -n color -- curl -v -k https://localhost:4040/ # test https on pod directly
k exec -it redapp -n color -- curl -v http://localhost:8080/ # test http on pod directly
~~~

Verify if the corresponding AGW resources have been created via AGIC.

~~~ bash
az network application-gateway show -g $prefix -n $prefix --query backendAddressPools[].name # we expect two backendAddressPools.
az network application-gateway show -g $prefix -n $prefix --query backendHttpSettingsCollection[].name # we expect three backendHttpSettingsCollection.
az network application-gateway show -g $prefix -n $prefix --query urlPathMaps[].pathRules[].paths[] # we expect 4 paths entries.
~~~

Test the ingress.

~~~ bash
agwpubip=$(kubectl get ingress/coloringresshttps -n color -o jsonpath='{.status.loadBalancer.ingress[0].ip}') # retrieve the IP used by the ingress.
# use case backend-path-prefix
curl -k -v -H"host: fe.cptdaks.org" https://$agwpubip/ # We expect an 200 OK from backend and fwd path /ssoauth/
curl -k -s -o /dev/null -w "%{http_code}" -H"host: fe.cptdaks.org" https://$agwpubip/redwrong # We expect an 200 OK and fwd path /ssoauth/redwrong.
# use case cookie-based-affinity
curl -k -v -H"host: fe.cptdaks.org" https://$agwpubip/red # We expect an 200 OK and a sticky cookie from AGW.
# use case ssl-redirect
curl -s -o /dev/null -w "%{http_code}" -H"host: fe.cptdaks.org" http://$agwpubip/ # We expect an 301 from http to https from AGW.
curl -s -o /dev/null -w "%{http_code}" -H"host: fe.cptdaks.org" http://$agwpubip/red # We expect an 301 from http to https from AGW.
~~~
---
## Tips

### Base64 and Certs

~~~ bash
fecert=$(base64 openssl/fe.cptdaks.crt)
fekey=$(base64 openssl/fe.cptdaks.key)
becert=$(base64 openssl/be.cptdaks.crt)
bekey=$(base64 openssl/be.cptdaks.key)
~~~

### Gateway Public IP

You should expect to get the public ip of the application gateway which can be checked as follow.

~~~ bash
agwpubipid=$(az network application-gateway show -n $prefix -g $prefix --query frontendIpConfigurations[].publicIpAddress.id -o tsv)
agwpubip=$(az network public-ip show --ids $agwpubipid --query ipAddress -o tsv)
~~~


### Restart application gateway

Based on https://stackoverflow.com/questions/49788958/how-can-i-restart-application-gateway-in-azure

~~~ bash
az network application-gateway stop --id $appgwid
az network application-gateway start --id $appgwid
~~~

Or via powershell.

~~~ pwsh
$appGWName = "cptdaks"
If (Get-AzApplicationGateway | where-object {$_.Name -eq $appGWName}) {
  $appGW = Get-AzApplicationGateway | where-object {$_.Name -eq $appGWName}
  Write-Host "Stopping the $appGWName ..."
  Stop-AzApplicationGateway -ApplicationGateway $appgw
  Write-Host "Starting the $appGWName ..."
  Start-AzApplicationGateway -ApplicationGateway $appgw
} Else {
  Write-Host "Application Gateway not found!"
}
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


### Setup Prometheus (Work in Progress)

Based on https://techcommunity.microsoft.com/t5/apps-on-azure-blog/using-azure-kubernetes-service-with-grafana-and-prometheus/ba-p/3020459

~~~ bash
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

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

### Create Node.js App

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

### Docker Tips and tricks

~~~ text
docker images
docker ps -all
docker rm ss
docker rmi cpt/ss:1.0
~~~

### Bicep

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

### K8s

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
k delete ns blue
k delete ns green
k delete ns red

k get nodes -o wide
k apply -f red/
k get service -n nsred -o wide
sudo kubectl port-forward -n nsred svc/svred 80
startedgeguest http://localhost
curl -v localhost

curl whatismyip.akamai.com
k get services -l cbase=ss -o wide -A
k get pods -n color -l cbase=ss -A
k exec -it -n nsblue dpblue-8676d598dc-28dgw -- ash
curl 52.152.201.81
curl 52.226.110.101
curl 10.0.202.212
curl 10.0.140.210
k port-forward -n nsred svc/svred 9090:80
k describe pod redapp -n color # get more details
kubectl logs -n color -p redapp --previous --tail 10 # get the last 10 lines of the pod
k delete ns color
k apply -f k8s/nas/colorapp.yaml
k apply -f k8s/nas/colorapp.tls.yaml
k apply -f k8s/nas/colorapp.http.yaml
k get ingress -A
k describe ingress/coloringresshttps -n color
k get svc -n color
k get pod -n color
k logs -f -n color redapp
k exec -it -n color redapp -- ash
~~~

### color apps

Create another color.

~~~ bash
rm -r green
mkdir green
cp -r red/* green/
sed -i 's/red/green/g' ./green/*.yaml
tree -L 2  //In case you like to see the new folder structure
~~~

### Chaos at AKS

~~~ bash
helm repo add chaos-mesh https://charts.chaos-mesh.org
helm repo update
k create ns chaos-testing
helm install chaos-mesh chaos-mesh/chaos-mesh --namespace=chaos-testing --version 2.0.3 --set chaosDaemon.runtime=containerd --set chaosDaemon.socketPath=/run/containerd/containerd.sock
helm list -A
k get pods -n chaos-testing -l app.kubernetes.io/instance=chaos-mesh
k get pods --all-namespaces
watch kubectl top pods -n nsgreen
~~~

~~~ yaml
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


