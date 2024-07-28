#/bin/bash -e

if [ -n "$(echo $REPO | grep ^http)" ]
then
source <(curl -s ${REPO}/env_k8sapp.sh) 
else
source ${REPO}/env_k8sapp.sh
fi


WORK_DIR=${WORK_DIR:-`pwd`}

namespace=`getarg namespace $@ 2>/dev/null`
namespace=${namespace:-"web-system"}
password=`getarg password $@  2>/dev/null`
password=${password:-"Pa44VV0rd14VVrOng"}
storage_class=`getarg storage_class $@  2>/dev/null`
storage_class=${storage_class:-""}
ingress_class=`getarg ingress_class $@ 2>/dev/null`
ingress_class=${ingress_class:-higress}

db_namespace=`getarg db_namespace $@ 2>/dev/null`
db_namespace=${db_namespace:-db-system}

web_provider=`getarg web_provider $@ 2>/dev/null`
web_provider=${web_provider:-ghost}

web_route_rule=`getarg web_route_rule $@`
web_route_rule=${web_route_rule:-'www.localhost'}


kubectl create namespace $namespace 2>/dev/null



runSql --sql "CREATE DATABASE IF NOT EXISTS ${web_provider};"


if [ "$web_provider" = "halo" ]; then
#
# https://github.com/halo-sigs/charts/blob/main/charts/halo/values.yaml
helm upgrade --install halo halo/halo \
--set image.tag=2 \
--set mysql.enabled=false \
--set postgresql.enabled=false \
--set replicaCount=2 \
--set haloUsername=admin \
--set haloPassword=${password} \
--set externalDatabase.platform=mysql \
--set externalDatabase.host=mysql-primary.${db_namespace}.svc \
--set externalDatabase.port=3306 \
--set externalDatabase.user=root \
--set externalDatabase.password=${password} \
--set externalDatabase.database=halo \
-n ${namespace} --create-namespace
#
srv_name=$(kubectl get service -n ${namespace} | grep halo | awk '{print $1}')
src_port=$(kubectl get services -n ${namespace} $srv_name -o jsonpath="{.spec.ports[0].port}")
install_ingress_rule \
--name halo \
--namespace ${namespace} \
--ingress_class ${ingress_class} \
--service_name $srv_name \
--service_port $src_port \
--domain ${web_route_rule}
fi





if [ "$web_provider" = "ghost" ]; then
# https://github.com/bitnami/charts/blob/main/bitnami/ghost/README.md
helm upgrade --install ghost bitnami/ghost \
--set image.registry=${bitnami_image_registry} \
--set image.tag=latest \
--set image.debug=true \
--set mysql.enabled=false \
--set postgresql.enabled=false \
--set replicaCount=2 \
--set ghostUsername=admin \
--set ghostPassword=${password} \
--set service.type=ClusterIP \
--set externalDatabase.platform=mysql \
--set externalDatabase.host=mysql-primary.${db_namespace}.svc \
--set externalDatabase.port=3306 \
--set externalDatabase.user=root \
--set externalDatabase.password=${password} \
--set externalDatabase.database=ghost \
-n ${namespace} --create-namespace
#
srv_name=$(kubectl get service -n ${namespace} | grep ghost | awk '{print $1}')
src_port=$(kubectl get services -n ${namespace} $srv_name -o jsonpath="{.spec.ports[0].port}")
install_ingress_rule \
--name ghost \
--namespace ${namespace} \
--ingress_class ${ingress_class} \
--service_name $srv_name \
--service_port $src_port \
--domain ${web_route_rule}
fi



if [ "$web_provider" = "drupal" ]; then
# https://github.com/bitnami/charts/blob/main/bitnami/drupal/README.md
helm upgrade --install drupal bitnami/drupal \
--set image.registry=${bitnami_image_registry} \
--set image.tag=latest \
--set image.debug=true \
--set mysql.enabled=false \
--set mariadb.enabled=false \
--set postgresql.enabled=false \
--set replicaCount=2 \
--set drupalUsername=admin \
--set drupalPassword=${password} \
--set service.type=ClusterIP \
--set externalDatabase.host=mysql-primary.${db_namespace}.svc \
--set externalDatabase.port=3306 \
--set externalDatabase.user=root \
--set externalDatabase.password=${password} \
--set externalDatabase.database=drupal \
--set allowEmptyPassword=false \
-n ${namespace} --create-namespace
#
srv_name=$(kubectl get service -n ${namespace} | grep drupal | awk '{print $1}')
src_port=$(kubectl get services -n ${namespace} $srv_name -o jsonpath="{.spec.ports[0].port}")
install_ingress_rule \
--name drupal \
--namespace ${namespace} \
--ingress_class ${ingress_class} \
--service_name $srv_name \
--service_port $src_port \
--domain ${web_route_rule}
fi




if [ "$web_provider" = "wordpress" ]; then
# 
# https://github.com/bitnami/charts/blob/main/bitnami/wordpress/values.yaml
helm upgrade --install wordpress bitnami/wordpress \
--set image.registry=${bitnami_image_registry} \
--set image.repository=${bitnami_image_repository}/wordpress \
--set image.tag=latest \
--set image.debug=true \
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
--set-string extraEnvVars[0].value=true \
-n ${namespace} --create-namespace
#
srv_name=$(kubectl get service -n ${namespace} | grep wordpress | awk '{print $1}')
src_port=$(kubectl get services -n ${namespace} $srv_name -o jsonpath="{.spec.ports[0].port}")
install_ingress_rule \
--name wordpress \
--namespace ${namespace} \
--ingress_class ${ingress_class} \
--service_name $srv_name \
--service_port $src_port \
--domain ${web_route_rule}
# 如果出现 content mixed 问题 可以安装 ssl insecure content fixer 插件
fi


if [ "$web_provider" = "joomla" ]; then
# 
# https://github.com/bitnami/charts/blob/main/bitnami/joomla/values.yaml
helm upgrade --install joomla bitnami/joomla \
--set image.registry=${bitnami_image_registry} \
--set image.repository=${bitnami_image_repository}/joomla \
--set image.tag=latest \
--set image.debug=true \
--set replicaCount=2 \
--set mariadb.enabled=false \
--set persistence.enabled=false \
--set joomlaUsername=admin \
--set joomlaPassword=${password} \
--set service.type=ClusterIP \
--set externalDatabase.host=mysql-primary.${db_namespace}.svc \
--set externalDatabase.port=3306 \
--set externalDatabase.user=root \
--set externalDatabase.password=${password} \
--set externalDatabase.database=joomla \
-n ${namespace} --create-namespace
#
srv_name=$(kubectl get service -n ${namespace} | grep joomla | awk '{print $1}')
src_port=$(kubectl get services -n ${namespace} $srv_name -o jsonpath="{.spec.ports[0].port}")
install_ingress_rule \
--name joomla \
--namespace ${namespace} \
--ingress_class ${ingress_class} \
--service_name $srv_name \
--service_port $src_port \
--domain ${web_route_rule}
# 如果出现 content mixed 问题 可以安装 ssl insecure content fixer 插件
fi

echo "---------------------------------------------"
echo "done"
echo "---------------------------------------------"

