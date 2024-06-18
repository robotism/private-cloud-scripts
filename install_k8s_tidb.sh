#/bin/bash -e

if [ -n "$(echo $REPO | grep ^http)" ]
then
source <(curl -s ${REPO}/env_function.sh) 
else
source ${REPO}/env_function.sh
fi

WORK_DIR=${WORK_DIR:-`pwd`}

password=`getarg password $@  2>/dev/null`
password=${password:-"Pa44VV0rd14VVrOng"}
storage_class=`getarg storage_class $@  2>/dev/null`
storage_class=${storage_class:-""}


tidb_image_version=v1.6.0
tidb_image_registry=${TIDB_REPO}
tidb_image_registry=${tidb_image_registry:-registry.cn-beijing.aliyuncs.com}
tidb_image_repository=${tidb_image_repository:-tidb}


kubectl create namespace tidb-admin
kubectl create namespace tidb-cluster

helm repo add pingcap https://charts.pingcap.org/


# crds
kubectl create -f ${GHPROXY}https://raw.githubusercontent.com/pingcap/tidb-operator/${tidb_image_version}/manifests/crd.yaml


# tidb-operator
git clone ${GHPROXY}https://github.com/pingcap/tidb-operator.git
cd tidb-operator
helm upgrade --install tidb-operator charts/tidb-operator \
  --version v1.6.0 \
  --set operatorImage=${tidb_image_registry}/${tidb_image_repository}/tidb-operator:${tidb_image_version} \
  --set tidbBackupManagerImage=${tidb_image_registry}/${tidb_image_repository}/tidb-backup-manager:${tidb_image_version} \
  --set scheduler.kubeSchedulerImageName=registry.cn-hangzhou.aliyuncs.com/google_containers/kube-scheduler \
  --namespace tidb-admin

# tidb-cluster
kubectl -n tidb-cluster apply -f ${GHPROXY}https://raw.githubusercontent.com/pingcap/tidb-operator/v1.6.0/examples/basic-cn/tidb-cluster.yaml

# monitor
kubectl -n tidb-cluster apply -f ${GHPROXY}https://raw.githubusercontent.com/pingcap/tidb-operator/v1.6.0/examples/basic-cn/tidb-monitor.yaml