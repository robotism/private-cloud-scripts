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
wordpress_route_rule=`getarg wordpress_route_rule $@`
wordpress_route_rule=${wordpress_route_rule:-'wordpress.localhost'}

db_namespace=`getarg db_namespace $@ 2>/dev/null`
db_namespace=${db_namespace:-db-system}

#
# kubectl exec -i -t -n ${db_namespace} mysql-primary-0 -c mysql -- sh -c "(bash || ash || sh)"
# mysql -uroot -p${password} -e 'CREATE DATABASE IF NOT EXISTS wordpress;show databases;'
# 
# https://github.com/bitnami/charts/blob/main/bitnami/wordpress/values.yaml
helm upgrade --install wordpress bitnami/wordpress \
--set image.registry=${bitnami_image_registry} \
--set image.repository=${bitnami_image_repository}/wordpress \
--set image.tag=latest \
--set replicaCount=2 \
--set mariadb.enabled=false \
--set persistence.enabled=false \
--set wordpressUsername=admin \
--set wordpressPassword=${password} \
--set wordpressScheme=http \
--set service.type=ClusterIP \
--set externalDatabase.host=mysql-primary.${db_namespace}.svc \
--set externalDatabase.user=root \
--set externalDatabase.password=${password} \
--set externalDatabase.database=wordpress \
--set extraEnvVars[0].name=WP_AUTO_UPDATE_CORE \
--set extraEnvVars[0].value=true \
-n ${namespace} --create-namespace


srv_name=$(kubectl get service -n ${namespace} | grep wordpress | awk '{print $1}')
src_port=$(kubectl get services -n ${namespace} $srv_name -o jsonpath="{.spec.ports[0].port}")
install_ingress_rule \
--name wordpress \
--namespace ${namespace} \
--ingress_class ${ingress_class} \
--service_name $srv_name \
--service_port $src_port \
--domain ${wordpress_route_rule}

# 如果出现 content mixed 问题 可以安装 ssl insecure content fixer 插件