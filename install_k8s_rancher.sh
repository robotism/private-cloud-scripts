#/bin/bash -e

if [ -n "$(echo $REPO | grep ^http)" ]
then
source <(curl -s ${REPO}/env_function.sh) 
else
source ${REPO}/env_function.sh
fi


password=`getarg password $@`
password=${password:Pa44VV0rd14VVrOng}
ingress_class=`getarg ingress_class $@`
ingress_class=${ingress_class:higress}
rancher_route_rule=`getarg rancher_route_rule $@`
rancher_route_rule=${rancher_route_rule:-'rancher.localhost'}

helm repo add rancher-stable https://releases.rancher.com/server-charts/stable

helm repo update

# https://ranchermanager.docs.rancher.com/zh/getting-started/installation-and-upgrade/installation-references/helm-chart-options

helm upgrade --install \
--namespace cattle-system --create-namespace \
--set replicas=1 \
--set ingress.extraAnnotations."kubernetes\.io/ingress\.class"=${ingress_class} \
--set hostname=${rancher_route_rule} \
--set bootstrapPassword=${password} \
rancher rancher-stable/rancher 

kubectl -n cattle-system rollout status deploy/rancher
kubectl -n cattle-system get deploy rancher

echo "------------------------------------------------------------------"
echjo "done"
echo "------------------------------------------------------------------"
