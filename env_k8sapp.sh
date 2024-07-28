#/bin/basah -e

#############################################################
# if [ -n "$(echo $REPO | grep ^http)" ]
# then
# source <(curl -s ${REPO}/env_k8sapp.sh) 
# else
# source ${REPO}/env_k8sapp.sh
# fi
#############################################################


if [ -n "$(echo $REPO | grep ^http)" ]
then
source <(curl -s ${REPO}/env_function.sh) 
else
source ${REPO}/env_function.sh
fi


[ "$debug" == "true" -o "$debug" == "yes" ] && set -x
[ "$DEBUG" == "true" -o "$DEBUG" == "yes" ] && set -x


db_namespace=`getarg db_namespace $@ 2>/dev/null`
db_namespace=${db_namespace:-db-system}

password=`getarg password $@  2>/dev/null`
password=${password:-"Pa44VV0rd14VVrOng"}

export DATABASE_TYPE=${DATABASE_TYPE:-mysql}
export DATABASE_HOST=${DATABASE_HOST:-mysql-primary.${db_namespace}.svc}
export DATABASE_PORT=${DATABASE_PORT:-3306}
export DATABASE_USER=${DATABASE_USER:-root}
export DATABASE_PASSWORD=${DATABASE_PASSWORD:-${password}}


# 
# kubectl exec -i -t -n ${db_namespace} mysql-primary-0 -c mysql -- sh -c "(bash || ash || sh)"
# mysql -uroot -p${password} -e 'CREATE DATABASE IF NOT EXISTS wordpress;show databases;'
# 

# kubectl exec -i -t -n ${db_namespace} mysql-primary-0 -c mysql -- sh -c "\
# mysql -uroot -p${password} -e '\
# CREATE DATABASE IF NOT EXISTS umami;\
# show databases;\
# '"
# 

# mysql -u $db_user -p $db_pwd -h $db_host < xx.sql
# CREATE DATABASE IF NOT EXISTS ${spring.datasource.name} CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;



runSql(){
  local sql=`getarg sql $@`
  local type=`getarg type $@`
  local type=${type:-$DATABASE_TYPE}

  local file="/tmp/.k8sapp.run.sql"

  rm -rf $file
  
  if [ -n "$(echo $sql | grep ^http)" ]
  then
  wget $sql -q -O $file
  else
  echo $sql > $file
  fi
  
  if [ type = 'mysql' ]
  kubectl exec -i -t -n ${db_namespace} mysql-primary-0 -c mysql -- \
    mysql \
    -h${DATABASE_HOST} \
    -P${DATABASE_PORT:-3306} \
    -u${DATABASE_USER:-root} \
    -p${DATABASE_PASSWORD} \
    < $file
  fi

  rm -rf $file
}
export -f runSql