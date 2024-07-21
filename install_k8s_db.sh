#/bin/bash -e

if [ -n "$(echo $REPO | grep ^http)" ]
then
source <(curl -s ${REPO}/env_function.sh) 
else
source ${REPO}/env_function.sh
fi


namespace=`getarg namespace $@ 2>/dev/null`
namespace=${namespace:-"db-system"}
password=`getarg password $@  2>/dev/null`
password=${password:-"Pa44VV0rd14VVrOng"}
storage_class=`getarg storage_class $@  2>/dev/null`
storage_class=${storage_class:-""}

helm repo add bitnami https://charts.bitnami.com/bitnami


# https://github.com/labring-actions/cluster-image-docs/blob/main/docs/docker/apps.md

# https://github.com/labring-actions/cluster-image/blob/main/applications/kubeblocks
install_kubeblocks(){
  if [ ! -n "`kubectl get po -A | grep kubeblocks`" ]; then
  sudo sealos run -f ${labring_image_registry}/${labring_image_repository}/kubeblocks:v0.9.0
  # kbcli kb upgrade --version 0.8.3
  # echo "uninstall-kubeblocks" | kbcli kubeblocks uninstall
  fi
}
# install_kubeblocks


## install tidb
helm repo add pingcap https://charts.pingcap.org/

kubectl create -f ${GHPROXY}https://raw.githubusercontent.com/pingcap/tidb-operator/v1.6.0/manifests/crd.yaml



## mysql7
# https://github.com/bitnami/charts/tree/main/bitnami/mysql/#installing-the-chart
# helm upgrade --install mysql57 bitnami/mysql \
#   --set image.registry=${bitnami_image_registry} \
#   --set image.tag=5.7.43-debian-11-r73 \
#   --set global.storageClass=${storage_class} \
#   --set auth.rootPassword=${password} \
#   --set auth.authenticationPolicy=replication \
#   --set architecture=replication \
#   -n ${namespace} --create-namespace
# helm uninstall mysql -n ${namespace}


## mysql8
# https://github.com/bitnami/charts/tree/main/bitnami/mysql/#installing-the-chart
# helm upgrade --install mysql bitnami/mysql \
#   --set image.registry=${bitnami_image_registry} \
#   --set global.storageClass=${storage_class} \
#   --set auth.rootPassword=${password} \
#   --set auth.authenticationPolicy=replication \
#   --set architecture=replication \
#   -n ${namespace} --create-namespace
# helm uninstall mysql -n ${namespace}






## install postgresql
# https://github.com/bitnami/charts/tree/main/bitnami/postgresql/#installing-the-chart
# helm upgrade --install postgresql bitnami/postgresql \
#   --set image.registry=${bitnami_image_registry} \
#   --set global.storageClass=${storage_class} \
#   --set global.postgresql.auth.postgresPassword=${password} \
#   --set architecture=replication \
#   -n ${namespace} --create-namespace
# helm uninstall postgresql -n ${namespace}


## install polardb-x/oceanbase


## install redis
# https://github.com/bitnami/charts/tree/main/bitnami/redis/#installing-the-chart
helm upgrade --install redis bitnami/redis \
  --set image.registry=${bitnami_image_registry} \
  --set global.storageClass=${storage_class} \
  --set global.redis.password=${password} \
  -n ${namespace} --create-namespace



## install elasticsearch
# https://github.com/bitnami/charts/tree/main/bitnami/elasticsearch/#installing-the-chart
helm upgrade --install elasticsearch bitnami/elasticsearch \
  --set image.registry=${bitnami_image_registry} \
  --set global.storageClass=${storage_class} \
  --set master.masterOnly=false \
  --set master.replicaCount=1 \
  --set data.replicaCount=0 \
  --set coordinating.replicaCount=0 \
  --set ingest.replicaCount=0 \
  --set security.enabled=true \
  --set security.elasticPassword=${password} \
  --set security.tls.restEncryption=false \
  --set security.tls.autoGenerated=true \
  --set security.tls.verificationMode=none \
  -n ${namespace} --create-namespace
# helm uninstall elasticsearch -n ${namespace}



## install clickhouse
# https://github.com/bitnami/charts/tree/main/bitnami/clickhouse/#installing-the-chart
# helm upgrade --install clickhouse bitnami/clickhouse \
#   --set image.registry=${bitnami_image_registry} \
#   --set global.storageClass=${storage_class} \
#   --set auth.username=root \
#   --set auth.password=${password} \
#   --set zookeeper.replicaCount=1 \
#   --set shards=2 \
#   --set replicaCount=2 \
#   -n ${namespace} --create-namespace
# helm uninstall clickhouse -n ${namespace}



## install victoriametrics
# https://github.com/VictoriaMetrics/helm-charts
helm repo add victoriametrics https://victoriametrics.github.io/helm-charts/
helm upgrade --install victoria-metrics-cluster victoriametrics/victoria-metrics-cluster \
  --set persistentVolume.storageClass=${storage_class} \
  --set vmselect.fullnameOverride=victoria-metrics-cluster-vmselect \
  --set vminsert.fullnameOverride=victoria-metrics-cluster-vminsert \
  --set vmstorage.fullnameOverride=victoria-metrics-cluster-vmstorage \
  -n ${namespace} --create-namespace
# helm uninstall victoria-metrics-cluster -n ${namespace}




echo "---------------------------------------------"
echo "done"
echo "---------------------------------------------"

