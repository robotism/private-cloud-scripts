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
password=${password:-"pa44vv0rd"}
storage_class=`getarg storage_class $@  2>/dev/null`
storage_class=${storage_class:-""}

helm repo add bitnami https://charts.bitnami.com/bitnami



## mysql 
# https://github.com/bitnami/charts/tree/main/bitnami/mysql/#installing-the-chart
helm upgrade --install mysql bitnami/mysql \
  --set global.storageClass=${storage_class} \
  --set auth.rootPassword=${password} \
  --set architecture=replication \
  -n ${namespace} --create-namespace
# helm uninstall mysql -n ${namespace}



## install tidb



## install postgresql
# https://github.com/bitnami/charts/tree/main/bitnami/postgresql/#installing-the-chart
helm upgrade --install postgresql bitnami/postgresql \
  --set global.storageClass=${storage_class} \
  --set global.postgresql.auth.postgresPassword=${password} \
  --set architecture=replication \
  -n ${namespace} --create-namespace
# helm uninstall postgresql -n ${namespace}


## install polardb-x/oceanbase


## install redis
# https://github.com/bitnami/charts/tree/main/bitnami/redis/#installing-the-chart
helm upgrade --install redis bitnami/redis \
  --set global.storageClass=${storage_class} \
  --set global.redis.password=${password} \
  -n ${namespace} --create-namespace


## install elasticsearch
# https://github.com/bitnami/charts/tree/main/bitnami/elasticsearch/#installing-the-chart
helm upgrade --install elasticsearch bitnami/elasticsearch \
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
helm upgrade --install victoria-metrics-cluster vm/victoria-metrics-cluster \
  --set persistentVolume.storageClass=${storage_class} \
  --set vmselect.fullnameOverride=victoria-metrics-cluster-vmselect \
  --set vminsert.fullnameOverride=victoria-metrics-cluster-vminsert \
  --set vmstorage.fullnameOverride=victoria-metrics-cluster-vmstorage \
  -n ${namespace} --create-namespace
# helm uninstall victoria-metrics-cluster -n ${namespace}






