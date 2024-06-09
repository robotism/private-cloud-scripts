#/bin/bash -e

if [ -n "$(echo $REPO | grep ^http)" ]
then
source <(curl -s ${REPO}/env_function.sh) 
else
source ${REPO}/env_function.sh
fi


WORK_DIR=${WORK_DIR:-`pwd`}

namespace=`getarg namespace $@ 2>/dev/null`
namespace=${namespace:-"web-system"}
password=`getarg password $@  2>/dev/null`
password=${password:-"pa44vv0rd"}
storage_class=`getarg storage_class $@  2>/dev/null`
storage_class=${storage_class:-""}
ingress_class=`getarg ingress_class $@ 2>/dev/null`
ingress_class=${ingress_class:-higress}
halo_route_rule=`getarg halo_route_rule $@`
halo_route_rule=${halo_route_rule:-'halo.localhost'}

db_namespace=`getarg db_namespace $@ 2>/dev/null`
db_namespace=${db_namespace:-db-system}

helm repo add halo https://halo-sigs.github.io/charts/


#
# kubectl exec -i -t -n ${db_namespace} mysql-primary-0 -c mysql -- sh -c "(bash || ash || sh)"
# mysql -uroot -p${password} -e 'CREATE DATABASE IF NOT EXISTS halo;show databases;'

# https://github.com/halo-sigs/charts/blob/main/charts/halo/values.yaml
helm upgrade --install halo halo/halo \
--set image.tag=2 \
--set mysql.enabled=false \
--set postgresql.enabled=false \
--set haloUsername=admin \
--set haloPassword=${password} \
--set externalDatabase.platform=mysql \
--set externalDatabase.host=mysql-primary.${db_namespace}.svc \
--set externalDatabase.port=3306 \
--set externalDatabase.user=root \
--set externalDatabase.password=${password} \
--set externalDatabase.database=halo \
-n ${namespace} --create-namespace


srv_name=$(kubectl get service -n ${namespace} | grep halo | awk '{print $1}')
src_port=$(kubectl get services -n ${namespace} $srv_name -o jsonpath="{.spec.ports[0].port}")
install_ingress_rule \
--name halo \
--namespace ${namespace} \
--ingress_class ${ingress_class} \
--service_name $srv_name \
--service_port $src_port \
--domain ${halo_route_rule}
