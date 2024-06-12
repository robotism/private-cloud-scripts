#/bin/bash -e

if [ -n "$(echo $REPO | grep ^http)" ]
then
source <(curl -s ${REPO}/env_function.sh) 
else
source ${REPO}/env_function.sh
fi

namespace=`getarg namespace $@ 2>/dev/null`
namespace=${namespace:-"mq-system"}
password=`getarg password $@  2>/dev/null`
password=${password:-"Pa44VV0rd14VVrOng"}
storage_class=`getarg storage_class $@  2>/dev/null`
storage_class=${storage_class:-""}
ingress_class=`getarg ingress_class $@ 2>/dev/null`
ingress_class=${ingress_class:-higress}


helm repo add bitnami https://charts.bitnami.com/bitnami


## instakk kafka
# https://github.com/bitnami/charts/tree/main/bitnami/kafka/#installing-the-chart
helm upgrade --install kafka bitnami/kafka \
  --set global.storageClass=${storage_class} \
  --set replicaCount=1 \
  --set controller.replicaCount=1 \
  -n ${namespace} --create-namespace
# helm uninstall kafka -n ${namespace}


## install rabbitmq
# https://github.com/bitnami/charts/tree/main/bitnami/rabbitmq/#installing-the-chart
helm upgrade --install rabbitmq bitnami/rabbitmq \
  --set global.storageClass=${storage_class} \
  --set image.debug=true \
  --set auth.password=${password} \
  --set auth.erlangCookie=ERLANG_COOKIE \
  --set clustering.forceBoot=true \
  --set replicaCount=1 \
  --set podManagementPolicy=Parallel \
  --set serviceAccount.create=true \
  --set serviceAccount.automountServiceAccountToken=true \
  --set startupProbe.timeoutSeconds=60 \
  --set livenessProbe.timeoutSeconds=60 \
  --set readinessProbe.timeoutSeconds=60 \
  --set plugins="rabbitmq_management rabbitmq_event_exchange rabbitmq_peer_discovery_k8s" \
  --set extraPlugins="" \
  --set extraEnvVars[0].name=LOG_LEVEL \
  --set extraEnvVars[0].value=debug \
  -n ${namespace} --create-namespace
# helm uninstall rabbitmq -n ${namespace}
rabbitmq_route_rule=`getarg rabbitmq_route_rule $@`
rabbitmq_route_rule=${rabbitmq_route_rule:-rabbitmq.localhost}
srv_name=$(kubectl get service -n ${namespace} | grep rabbitmq | grep -v 'headless' | awk '{print $1}')
src_port=$(kubectl get services -n ${namespace} $srv_name -o jsonpath="{.spec.ports[?(@.name=='http-stats')].port}")
install_ingress_rule \
--name rabbitmq \
--namespace ${namespace} \
--ingress_class ${ingress_class} \
--service_name $srv_name \
--service_port $src_port \
--domain ${rabbitmq_route_rule}

## install rocketmq
# https://github.com/itboon/rocketmq-helm
helm repo add rocketmq https://helm-charts.itboon.top/rocketmq
helm upgrade --install rocketmq rocketmq/rocketmq-cluster \
  --set broker.size.master="1" \
  -n ${namespace} --create-namespace
# helm uninstall rocketmq -n ${namespace}
rocketmq_route_rule=`getarg rocketmq_route_rule $@`
rocketmq_route_rule=${rocketmq_route_rule:-rocketmq.localhost}
srv_name=$(kubectl get service -n ${namespace} | grep rocketmq | grep dashboard | awk '{print $1}')
src_port=$(kubectl get services -n ${namespace} $srv_name -o jsonpath="{.spec.ports[0].port}")
install_ingress_rule \
--name rocketmq \
--namespace ${namespace} \
--ingress_class ${ingress_class} \
--service_name $srv_name \
--service_port $src_port \
--domain ${rocketmq_route_rule}
  
## install emqx
# https://github.com/emqx/emqx/blob/master/deploy/charts/emqx/README.md
helm repo add emqx https://repos.emqx.io/charts
helm upgrade --install emqx emqx/emqx \
  --set service.type=NodePort \
  --set persistence.enabled=true \
  --set persistence.storageClass=${storage_class} \
  --set replicaCount=1 \
  --set emqxConfig.EMQX_DASHBOARD__DEFAULT_USERNAME=admin \
  --set emqxConfig.EMQX_DASHBOARD__DEFAULT_PASSWORD=${password} \
  -n ${namespace} --create-namespace
# helm uninstall emqx -n ${namespace}
emqx_route_rule=`getarg emqx_route_rule $@`
emqx_route_rule=${emqx_route_rule:-emqx.localhost}
srv_name=$(kubectl get service -n ${namespace} | grep emqx | grep -v 'headless' | awk '{print $1}')
src_port=$(kubectl get services -n ${namespace} $srv_name -o jsonpath="{.spec.ports[?(@.name=='dashboard')].port}")
install_ingress_rule \
--name emqx \
--namespace ${namespace} \
--ingress_class ${ingress_class} \
--service_name $srv_name \
--service_port $src_port \
--domain ${emqx_route_rule}

echo "---------------------------------------------"
echo "done"
echo "---------------------------------------------"

