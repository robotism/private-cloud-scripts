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
namespace=${namespace:-"ms-system"}
password=`getarg password $@  2>/dev/null`
password=${password:-"Pa44VV0rd14VVrOng"}
storage_class=`getarg storage_class $@  2>/dev/null`
storage_class=${storage_class:-""}
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

# install kt-connect
# https://alibaba.github.io/kt-connect
# .\ktctl.exe connect -c .\kubeconfig

# 
# mysql -u $db_user -p $db_pwd -h $db_host < xx.sql
# CREATE DATABASE IF NOT EXISTS ${spring.datasource.name} CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;




#-----------------------------------------------------------------------------------------------
# install dtm
# init db: https://github.com/dtm-labs/dtm/blob/main/sqls/dtmsvr.storage.mysql.sql
#
# kubectl exec -i -t -n ${db_namespace} mysql-primary-0 -c mysql -- sh -c "(bash || ash || sh)"
# mysql -uroot -p${password} -e 'CREATE DATABASE IF NOT EXISTS dtm;show databases;'
#
dtm_route_rule=`getarg dtm_route_rule $@ 2>/dev/null`
dtm_route_rule=${dtm_route_rule:-'dtm.localhost'}
git clone ${GHPROXY}https://github.com/dtm-labs/dtm 2>/dev/null
cd dtm
echo "
configuration: |-
  Store:
    Driver: 'mysql'
    Host: 'mysql-primary.${db_namespace}.svc'
    User: 'root'
    Password: '${password}'
    Port: 3306
    Db: 'dtm'
  TimeZoneOffset: '0'
" > dtm_values.yaml
cat dtm_values.yaml
helm uninstall dtm -n ${namespace} 
helm upgrade --install dtm ./charts \
  --set replicaCount=2 \
  --set ingress.enabled=true \
  --set ingress.className=${ingress_class} \
  --set ingress.hosts[0].host=${dtm_route_rule} \
  --set ingress.hosts[0].paths[0].path=/ \
  --set ingress.hosts[0].paths[0].pathType=Prefix \
  --values dtm_values.yaml \
  -n ${namespace} --create-namespace 
cd $WORK_DIR
rm -rf dtm





#-----------------------------------------------------------------------------------------------
# install spring cloud alibaba


#-----------------------------------------------------------------------------------------------
# install spring cloud tencent (polarmesh)


# install polarismesh
# https://polarismesh.cn/docs





