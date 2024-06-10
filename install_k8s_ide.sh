#/bin/bash -e

if [ -n "$(echo $REPO | grep ^http)" ]
then
source <(curl -s ${REPO}/env_function.sh) 
else
source ${REPO}/env_function.sh
fi

#-----------------------------------------------------------------------------------------------
# env
WORK_DIR=${WORK_DIR:-`pwd`}

namespace=`getarg namespace $@ 2>/dev/null`
namespace=${namespace:-"ide-system"}
password=`getarg password $@  2>/dev/null`
password=${password:-"Pa44VV0rd14VVrOng"}
storage_class=`getarg storage_class $@  2>/dev/null`
storage_class=${storage_class:-""}

ingress_class=`getarg ingress_class $@`
ingress_class=${ingress_class:-higress}

install_coder(){
  # install code server
  # https://github.com/coder/code-server/blob/main/docs/helm.md
  # https://github.com/coder/code-server/blob/main/ci/helm-chart/values.yaml
  git clone ${GHPROXY}https://github.com/coder/code-server 2>/dev/null
  cd code-server
  helm upgrade --install code-server ci/helm-chart \
    --set persistence.storageClass=${storage_class} \
    --set password=${password} \
    -n ${namespace} --create-namespace
  cd $WORK_DIR
  rm -rf code-server
  # helm delete code-server -n ${namespace}
}

install_coder_ingress(){
  coder_route_rule=`getarg coder_route_rule $@`
  coder_route_rule=${coder_route_rule:-'coder.localhost'}
  srv_name=$(kubectl get service -n ${namespace} | grep code-server | awk '{print $1}')
  src_port=$(kubectl get services -n ${namespace} $srv_name -o jsonpath="{.spec.ports[0].port}")
  install_ingress_rule \
  --name code-server \
  --namespace ${namespace} \
  --ingress_class ${ingress_class} \
  --service_name $srv_name \
  --service_port $src_port \
  --domain ${coder_route_rule}
}

install_coder $@
install_coder_ingress $@
