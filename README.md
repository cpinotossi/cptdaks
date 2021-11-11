# cptdaks
simple demo of azure aks with internal loadbalancer and vnet integration

## Create Node.js App

~~~bash
npm init -y
code package.json
code .env
npm i dotenv
npm run
cat /proc/cpuinfo
ps aux | grep index.js
top -p
curl 'http://localhost:8080/?f=40'
~~~

## Docker

Create Dockerfile and add the following line:

~~~YAML
RUN apk --no-cache add curl nano
~~~

Afterward execute the following commands:

~~~bash
docker build -t cpt/ss:1.0 .
docker run --name ss -d -p3000:8080 cpt/ss:1.0
docker ps
docker logs -f ss
curl 'http://localhost:3000/?f=1'
docker exec -it ss ash
curl 'http://localhost:3000/?f=1'
curl 'http://localhost:8080/?f=1'
docker rm -f ss
~~~

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
k logs -f -n nsgreen dpgree-75665b8464-k4gwn
curl 'http://192.168..0.6/?f=25'
watch kubectl top pods -n nsgreen
k get pods -n nsgreen -w
ab -s 500 -c 10 -n 20 http://192.168.0.6/
~~~

K8s bonus

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