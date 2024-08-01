#/bin/basah -e

#############################################################
# if [ -n "$(echo $REPO | grep ^http)" ]
# then
# source <(curl -s ${REPO}/env_function.sh) 
# else
# source ${REPO}/env_function.sh
# fi
#############################################################

[ "$debug" == "true" -o "$debug" == "yes" ] && set -x
[ "$DEBUG" == "true" -o "$DEBUG" == "yes" ] && set -x

if [ -n "`which yum 2>/dev/null`" ]; then
export PM=yum
fi

if [ -n "`which apt 2>/dev/null`" ]; then
export PM=apt
fi

export labring_image_registry=${LABRING_REPO}
export labring_image_registry=${labring_image_registry:-registry.cn-shanghai.aliyuncs.com}
export labring_image_repository=${labring_image_repository:-labring}

export bitnami_image_registry=${BITNAMI_REPO}
export bitnami_image_registry=${bitnami_image_registry:-docker.io}
export bitnami_image_repository=${bitnami_image_repository:-bitnami}


export WORK_DIR=`pwd`

getrelease(){
  if [ ! -n "$release" ]; then
  local release=` cat /etc/issue | awk '{print $1}' | tr A-Z a-z 2>/dev/null `
  fi
  if [ ! -n "$release" ]; then
  local release=` cat /etc/issue.net | awk '{print $1}' | tr A-Z a-z 2>/dev/null `
  fi
  if [ ! -n "$release" ]; then
  local release=` cat /etc/centos-release | awk '{print $1}' | tr A-Z a-z 2>/dev/null `
  fi
  if [ ! -n "$release" ]; then
  local release=` cat /etc/fedora-release | awk '{print $1}' | tr A-Z a-z 2>/dev/null `
  fi
  if [ ! -n "$release" ]; then
  local release=` cat /etc/redhat-release | awk '{print $1}' | tr A-Z a-z 2>/dev/null `
  fi
  if [ ! -n "$release" ]; then
  local release=` cat /etc/system-release | awk '{print $1}' | tr A-Z a-z 2>/dev/null `
  fi
  if [ ! -n "$release" ]; then
  local release=` cat /etc/centos-release | awk '{print $1}' | tr A-Z a-z 2>/dev/null `
  fi
  if [ ! -n "$release" ]; then
  local release=` cat /etc/os-release | tr '""' ' ' | awk '{print $2}' | sed -n 1p | tr A-Z a-z 2>/dev/null `
  fi
  echo "$release"
}
export -f getrelease

getarg(){
  local __name=$1
  local __args=$@
  
  local __value=""
  for arg in $__args   
  do
    if [ -n "`echo $arg | grep ^-`" ]; then
    	local _aname=`echo ${arg} | sed 's/^[-]*//'`
    	if [ "$_aname" = "$__name" ]; then 
    	  local __start=true
    	fi
    	if [ "$_aname" != "$__name" ]; then 
    	  local __start=false
    	fi
    fi
    if [ ! -n "`echo $arg | grep ^-`" ]; then
      if [ "$__start" = "true" ]; then 
    	  local __value="$__value $arg"
      fi
    fi
  done  
  echo $__value
}
export -f getarg

sum(){
  local total=0
  for arg in $@   
  do 
    local total=`expr $arg + $total`
  done 
  echo $total
}
export -f sum


run(){
  local script=$1
  local online=$(echo $REPO | grep ^http)
  if [ -n "$online" ]
  then
  bash <(curl -s ${REPO}/${script}) $@
  else
  bash ${REPO}/${script} $@
  fi
}
export -f run

# https://kubernetes.github.io/ingress-nginx/examples/auth/basic/
install_ingress_rule(){
local name=`getarg name $@`
local namespace=`getarg namespace $@`
local domains=`getarg domain $@`
local ingress_class=`getarg ingress_class $@`
local service_name=`getarg service_name $@`
local service_port=`getarg service_port $@`
local auth_type=`getarg auth_type $@`
local auth_seacret=`getarg auth_secret $@`
local auth_realm=`getarg auth_realm $@`
local domains=${domains:-${name}.localhost}
local domains=$(echo $domains |  tr ',' ' ')
echo ">>>"
echo ">>> install ingress domains: ${domains}"
echo ">>>"
idx=0
for domain in $domains   
do  
idx=`expr $idx + 1`
echo "--------------------------------------------------------------------------"
echo "kubectl apply ingress: "
echo "                name = ${name}${idx} "
echo "           namespace = ${namespace} "
echo "              domain = ${domain} "
echo "       ingress_class = ${ingress_class} "
echo "        service_name = ${service_name} "
echo "        service_port = ${service_port} "
echo "           auth_type = ${auth_type} "
echo "         auth_secret = ${auth_secret} "
echo "          auth_realm = ${auth_realm} "
echo ""--------------------------------------------------------------------------""
echo "
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ${name}${idx}
  namespace: ${namespace:-default}
  annotations:
    nginx.ingress.kubernetes.io/auth-type: ${auth_type}
    nginx.ingress.kubernetes.io/auth-secret: ${auth_secret}
    nginx.ingress.kubernetes.io/auth-realm: '${auth_realm:-Authentication Required - ${domain}}'
spec:
  ingressClassName: ${ingress_class:-higress}
  rules:
  - host: ${domain}
    http:
      paths:
      - pathType: Prefix
        path: "/"
        backend:
          service:
            name: ${service_name:-${name}}
            port:
              number: ${service_port:-80}
" | kubectl apply -f -
done

}
export -f install_ingress_rule