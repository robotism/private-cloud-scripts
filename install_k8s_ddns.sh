#!/bin/bash -e

if [ -n "$(echo $REPO | grep ^http)" ]
then
source <(curl -Ls ${REPO}/env_function.sh) 
else
source ${REPO}/env_function.sh
fi

#-----------------------------------------------------------------------------------------------
# env

WORK_DIR=${WORK_DIR:-`pwd`}

namespace=`getarg namespace $@ 2>/dev/null`
namespace=${namespace:-"higress-system"}
password=`getarg password $@ 2>/dev/null`
password=${password:-"Pa44VV0rd14VVrOng"}
storage_class=`getarg storage_class $@  2>/dev/null`
storage_class=${storage_class:-""}

ingress_class=`getarg ingress_class $@ 2>/dev/null`
ingress_class=${ingress_class:-higress}

db_namespace=`getarg db_namespace $@ 2>/dev/null`
db_namespace=${db_namespace:-db-system}



dns=`getarg dns $@`
apikey=`getarg apikey $@`
apisecret=`getarg apisecret $@`
domains=`getarg domains $@`
domains=$(echo $domains | tr ',' ' ')


# https://github.com/jeessy2/ddns-go/blob/master/README.md#docker%E4%B8%AD%E4%BD%BF%E7%94%A8

config_name=ddns-config

tmpdir=$(getarg tmpdir $@)
tmpdir=${tmpdir:-"$(pwd)"}
tmpdir=${tmpdir}/.k8s_${config_name}

mkdir -p $tmpdir

cat << EOF > ${tmpdir}/.ddns_go_config.yaml
dnsconf:
    - name: ""
      ipv4:
        enable: true
        gettype: url
        url: https://myip.ipip.net, https://ddns.oray.com/checkip, https://ip.3322.net, https://4.ipw.cn
        netinterface: ""
        cmd: ""
        domains:
EOF
for domain in $domains   
do  
cat << EOF >> ${tmpdir}/.ddns_go_config.yaml
            - "${domain}"
EOF
done
cat << EOF >> ${tmpdir}/.ddns_go_config.yaml
      ipv6:
        enable: false
        gettype: url
        url: https://speed.neu6.edu.cn/getIP.php, https://v6.ident.me, https://6.ipw.cn
        netinterface: ""
        cmd: ""
        ipv6reg: ""
        domains:
EOF
for domain in $domains   
do  
cat << EOF >> ${tmpdir}/.ddns_go_config.yaml
            - "${domain}"
EOF
done
cat << EOF >> ${tmpdir}/.ddns_go_config.yaml
      dns:
        name: ${dns}
        id: "${apikey}"
        secret: ${apisecret}
      ttl: ""
user:
    username: admin
    password: $(htpasswd -bnBC 10 "" ${password} | tr -d ':\n')
webhook:
    webhookurl: ""
    webhookrequestbody: ""
    webhookheaders: ""
notallowwanaccess: true
lang: zh
EOF

echo "${config_name}.yaml"
echo "------------------------------------------------------"
cat ${tmpdir}/.ddns_go_config.yaml
echo "------------------------------------------------------"

kubectl delete secret ${config_name}.yaml -n ${namespace} 2>/dev/null
kubectl create secret generic ${config_name}.yaml -n ${namespace} --from-file=${tmpdir}/.ddns_go_config.yaml

rm -rf ${tmpdir}

echo "
kind: Deployment
apiVersion: apps/v1
metadata:
  name: ddns
  namespace: ${namespace:-default}
  labels:
    app: ddns
spec:
  replicas: 1
  selector:
    matchLabels:
      app: ddns
  template:
    metadata:
      labels:
        app: ddns
    spec:
      containers:
        - name: ddns
          image: docker.io/jeessy/ddns-go:latest
          ports:
            - name: ddns
              containerPort: 9876 
          env:
            - name: HASH_SALT
              value: \"$(pwgen 16 -n 1)\"
          readinessProbe:
            failureThreshold: 1
            httpGet:
              path: /
              port: 9876
              scheme: HTTP
            initialDelaySeconds: 10
            periodSeconds: 10
            successThreshold: 1
            timeoutSeconds: 2
          volumeMounts:
            - name: config
              mountPath: "/root/"
              readOnly: true
      volumes:
        - name: config
          secret:
            secretName: ${config_name}.yaml
" | kubectl apply -f -


echo "
apiVersion: v1
kind: Service
metadata:
  name: ddns
  namespace: ${namespace:-default}
spec:
  type: ClusterIP
  ports:
    - protocol: TCP
      name: ddns
      port: 9876
      targetPort: 9876
  selector:
    app: ddns
" | kubectl apply -f -


ddns_route_rule=`getarg ddns_route_rule $@ 2>/dev/null`
ddns_route_rule=${ddns_route_rule:-'ddns.localhost'}
srv_name=$(kubectl get service -n ${namespace} | grep ddns | awk '{print $1}')
src_port=$(kubectl get services -n ${namespace} $srv_name -o jsonpath="{.spec.ports[0].port}")
install_ingress_rule \
--name ddns \
--namespace ${namespace} \
--ingress_class ${ingress_class} \
--service_name $srv_name \
--service_port $src_port \
--domain ${ddns_route_rule}



echo "---------------------------------------------"
echo "done"
echo "---------------------------------------------"

