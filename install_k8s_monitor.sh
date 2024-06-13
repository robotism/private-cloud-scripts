#/bin/bash -e

if [ -n "$(echo $REPO | grep ^http)" ]
then
source <(curl -s ${REPO}/env_function.sh) 
else
source ${REPO}/env_function.sh
fi

helm repo add bitnami https://charts.bitnami.com/bitnami

WORK_DIR=${WORK_DIR:-`pwd`}

namespace=`getarg namespace $@ 2>/dev/null`
namespace=${namespace:-"monitor-system"}
storage_class=`getarg storage_class $@  2>/dev/null`
storage_class=${storage_class:-""}
password=`getarg password $@  2>/dev/null`
password=${password:-"Pa44VV0rd14VVrOng"}
ingress_class=`getarg ingress_class $@ 2>/dev/null`
ingress_class=${ingress_class:-higress}

db_namespace=`getarg db_namespace $@ 2>/dev/null`
db_namespace=${db_namespace:-db-system}

vm_namespace=`getarg vm_namespace $@ 2>/dev/null`
vm_namespace=${vm_namespace:-${db_namespace}}

es_namespace=`getarg es_namespace $@ 2>/dev/null`
es_namespace=${es_namespace:-${db_namespace}}
es_protocol=`getarg es_protocol $@ 2>/dev/null`
es_host=`getarg es_host $@ 2>/dev/null`
es_user=`getarg es_user $@ 2>/dev/null`
es_password=`getarg es_password $@ 2>/dev/null`
es_password=${es_password:-${password}}


## install kibana
# https://github.com/bitnami/charts/tree/main/bitnami/kibana/#installing-the-chart
if [ ! -f "$es_password" ]; then 
es_password=$(kubectl get secret elasticsearch -n ${es_namespace} -o jsonpath='{.data.elasticsearch-password}' | base64 --decode)
fi

kubectl create namespace ${namespace} 2>/dev/null
kubectl delete secret kibana-admin -n ${namespace} 2>/dev/null
kubectl create secret generic kibana-admin -n ${namespace} \
  --from-literal=kibana-password=${es_password} \
  --from-literal=elasticsearch-password=${es_password}
helm upgrade --install kibana bitnami/kibana \
  --set global.storageClass=${storage_class} \
  --set elasticsearch.hosts[0]=${es_host:-elasticsearch.${es_namespace}.svc} \
  --set elasticsearch.port="9200" \
  --set elasticsearch.security.auth.enabled=true \
  --set elasticsearch.security.auth.kibanaPassword="${es_password}" \
  --set elasticsearch.security.auth.existingSecret="kibana-admin" \
  --set elasticsearch.security.auth.createSystemUser=true \
  --set elasticsearch.security.auth.elasticsearchPasswordSecret="kibana-admin" \
  -n ${namespace} --create-namespace
# helm uninstall kibana -n ${namespace}
kibana_route_rule=`getarg kibana_route_rule $@`
kibana_route_rule=${kibana_route_rule:-localhost}
srv_name=$(kubectl get service -n ${namespace} | grep kibana | awk '{print $1}')
src_port=$(kubectl get services -n ${namespace} $srv_name -o jsonpath="{.spec.ports[0].port}")
install_ingress_rule \
--name kibana \
--namespace ${namespace} \
--ingress_class ${ingress_class} \
--service_name $srv_name \
--service_port $src_port \
--domain ${kibana_route_rule}



## install prometheus
# https://github.com/bitnami/charts/tree/main/bitnami/prometheus/#installing-the-chart
# https://docs.victoriametrics.com/url-examples/ # remote write to vm
helm upgrade --install prometheus bitnami/prometheus \
  --set global.storageClass=${storage_class} \
  --set admin.password=${password} \
  --set alertmanager.enabled=false  \
  --set server.enableAdminAPI=true \
  --set server.service.type=ClusterIP \
  --set server.remoteWrite[0].url="http://victoria-metrics-cluster-vminsert.${vm_namespace}.svc:8480//insert/0/prometheus/api/v1/import/prometheus" \
  --set server.extraScrapeConfigs[0].job_name=higress \
  --set server.extraScrapeConfigs[0].kubernetes_sd_configs[0].role=endpoints \
  --set server.extraScrapeConfigs[0].kubernetes_sd_configs[0].namespaces.names='{higress-system,monitor-system}' \
  --set server.extraScrapeConfigs[0].relabel_configs[0].regex='__meta_kubernetes_pod_label_(.+)' \
  --set server.extraScrapeConfigs[0].relabel_configs[0].replacement='$1' \
  --set server.extraScrapeConfigs[0].relabel_configs[0].action='labelmap' \
  -n ${namespace} --create-namespace
# helm uninstall prometheus -n ${namespace}
prometheus_route_rule=`getarg prometheus_route_rule $@`
prometheus_route_rule=${prometheus_route_rule:-'prometheus.localhost'}
srv_name=$(kubectl get service -n ${namespace} | grep prometheus | awk '{print $1}')
src_port=$(kubectl get services -n ${namespace} $srv_name -o jsonpath="{.spec.ports[0].port}")
install_ingress_rule \
--name prometheus \
--namespace ${namespace} \
--ingress_class ${ingress_class} \
--service_name $srv_name \
--service_port $src_port \
--domain ${prometheus_route_rule}



## install grafana
# https://github.com/bitnami/charts/tree/main/bitnami/grafana/#installing-the-chart
helm upgrade --install grafana bitnami/grafana \
  --set global.storageClass=${storage_class} \
  --set admin.password=${password} \
  --set grafana.extraEnvVars[0].name=GF_SECURITY_COOKIE_SECURE \
  --set-string grafana.extraEnvVars[0].value=true \
  --set grafana.extraEnvVars[1].name=GF_SECURITY_COOKIE_SAMESITE \
  --set-string grafana.extraEnvVars[1].value=none \
  --set grafana.extraEnvVars[2].name=GF_SECURITY_ALLOW_EMBEDDING \
  --set-string grafana.extraEnvVars[2].value=true \
  -n ${namespace} --create-namespace
# helm uninstall grafana -n ${namespace}
grafana_route_rule=`getarg grafana_route_rule $@`
grafana_route_rule=${grafana_route_rule:-'grafana.localhost'}
srv_name=$(kubectl get service -n ${namespace} | grep grafana | awk '{print $1}')
src_port=$(kubectl get services -n ${namespace} $srv_name -o jsonpath="{.spec.ports[0].port}")
install_ingress_rule \
--name grafana \
--namespace ${namespace} \
--ingress_class ${ingress_class} \
--service_name $srv_name \
--service_port $src_port \
--domain ${grafana_route_rule}


## install skywalking
# https://github.com/apache/skywalking-helm
# SW_ES_USER,SW_ES_PASSWORD,SW_STORAGE_ES_HTTP_PROTOCOL,SW_SW_STORAGE_ES_SSL_JKS_PATH,SW_SW_STORAGE_ES_SSL_JKS_PASS
git clone ${GHPROXY}https://github.com/apache/skywalking-helm
cd skywalking-helm
sed -i '1,31!d' chart/skywalking/Chart.yaml # remove dependences
helm upgrade --install skywalking chart/skywalking  \
  --version 4.6.0 \
  --set ui.image.repository=docker.io/apache/skywalking-ui \
  --set ui.image.tag=10.0.1 \
  --set oap.image.repository=docker.io/apache/skywalking-oap-server \
  --set oap.image.tag=10.0.1 \
  --set oap.replicas=1 \
  --set elasticsearch.enabled=false \
  --set postgresql.enabled=false \
  --set banyandb.enabled=false \
  --set oap.storageType=elasticsearch \
  --set elasticsearch.replicas=1 \
  --set elasticsearch.config.protocol=${es_protocol:-http} \
  --set elasticsearch.config.host=${es_host:-elasticsearch.${es_namespace}.svc} \
  --set elasticsearch.config.user="${es_user:-elastic}" \
  --set elasticsearch.config.password="${es_password}" \
  --set elasticsearch.persistence.enabled=true \
  --set elasticsearch.antiAffinity="" \
  --set elasticsearch.antiAffinityTopologyKey="" \
  --set satellite.enabled=false \
  --set satellite.image.repository=docker.io/apache/skywalking-satellite \
  --set satellite.image.tag=v1.2.0 \
  -n ${namespace} --create-namespace
cd $WORK_DIR
rm -rf skywalking-helm
# helm uninstall skywalking -n ${namespace} 
skywalking_route_rule=`getarg skywalking_route_rule $@ 2>/dev/null`
skywalking_route_rule=${skywalking_route_rule:-'skywalking.localhost'}
srv_name=$(kubectl get service -n ${namespace} | grep skywalking | grep ui | awk '{print $1}')
src_port=$(kubectl get services -n ${namespace} $srv_name -o jsonpath="{.spec.ports[0].port}")
install_ingress_rule \
--name skywalking \
--namespace ${namespace} \
--ingress_class ${ingress_class} \
--service_name $srv_name \
--service_port $src_port \
--domain ${skywalking_route_rule}



echo "---------------------------------------------------------------------"
echo "done"
echo "---------------------------------------------------------------------"
