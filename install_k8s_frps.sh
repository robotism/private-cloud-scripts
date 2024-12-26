#!/bin/bash -e

if [ -n "$(echo $REPO | grep ^http)" ]
then
source <(curl -Ls ${REPO}/env_function.sh) 
else
source ${REPO}/env_function.sh
fi

tmpdir=$(getarg tmpdir $@)
tmpdir=${tmpdir:-"$(pwd)"}
tmpdir=${tmpdir}/.k8s_frps
mkdir -p $tmpdir

namespace=`getarg namespace $@ 2>/dev/null`
namespace=${namespace:-frp-system}
password=`getarg password $@ 2>/dev/null`
password=${password:-"Pa44VV0rd14VVrOng"}
storage_class=`getarg storage_class $@  2>/dev/null`
storage_class=${storage_class:-""}

ingress_class=`getarg ingress_class $@ 2>/dev/null`
ingress_class=${ingress_class:-higress}


kubectl create namespace $namespace 2>/dev/null

token=$(getarg token $@)
token=${token:-${TOKEN}}
token=${token:-Pa44VV0rd14VVrOng}



dashboard_user=`getarg dashboard_user $@`
dashboard_user=${dashboard_user:-frps}

dashboard_password=`getarg dashboard_password $@`
dashboard_password=${dashboard_password:-${token}}

port_bind=$(getarg port_bind $@)
port_bind=${port_bind:-7000}

port_ui=$(getarg port_ui $@)
port_ui=${port_ui:-7500}

port_http=$(getarg port_http $@)
port_http=${port_http:-8080}

port_tcp=$(getarg port_tcp $@)
port_tcp=${port_tcp:-8000}

tls=$(getarg tls $@)
tls=${tls:-true}

if [ "$tls" = "true" ]; then
entrypoints=websecure
fi
if [ "$tls" != "true" ]; then
entrypoints=web
fi

CONTAINER_NAME=frps

FRPS_TOML=frps.toml
FRPS_YAML=frps.yaml


cat << EOF > ${tmpdir}/${FRPS_TOML}
bindPort = ${port_bind}
tcpmuxHTTPConnectPort = ${port_tcp}
vhostHTTPPort = ${port_http}
webServer.addr = "0.0.0.0"
webServer.port = ${port_ui}
webServer.user = "${dashboard_user:admin}"
webServer.password = "${dashboard_password}"
auth.token = "${token}"
log.level = "debug"
log.maxDays = 7
log.disablePrintColor = false
detailedErrorsToClient = true
# 用于 HTTP 请求的自定义 404 页面
# custom404Page = "/path/to/404.html"
EOF

echo "------------------------------------------------------"
cat ${tmpdir}/${FRPS_TOML}
echo "------------------------------------------------------"

kubectl delete secret ${FRPS_TOML} -n ${namespace} 2>/dev/null
kubectl create secret generic ${FRPS_TOML} -n ${namespace} --from-file=${tmpdir}/${FRPS_TOML}

cat << EOF > ${tmpdir}/${FRPS_YAML}
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frps
  namespace: ${namespace}
  labels:
    app: frps
spec:
  replicas: 1
  selector:
    matchLabels:
      app: frps
  template:
    metadata:
      labels:
        app: frps
    spec:
      containers:
        - name: frps
          image: docker.io/snowdreamtech/frps:0.61
          ports:
            - name: bind
              containerPort: ${port_bind}
            - name: http
              containerPort: ${port_http}
            - name: tcp
              containerPort: ${port_tcp}
            - name: ui
              containerPort: ${port_ui}
          volumeMounts:
            - name: config
              mountPath: "/etc/frp"
              readOnly: true
      volumes:
        - name: config
          secret:
            secretName: ${FRPS_TOML}
EOF

kubectl delete -f ${tmpdir}/${FRPS_YAML} 2>/dev/null
kubectl apply -f ${tmpdir}/${FRPS_YAML}


echo "
apiVersion: v1
kind: Service
metadata:
  name: frps
  namespace: ${namespace:-default}
spec:
  type: ClusterIP
  ports:
    - protocol: TCP
      name: bind
      port: ${port_bind}
      targetPort: ${port_bind}
    - protocol: TCP
      name: http
      port: ${port_http}
      targetPort: ${port_http}
    - protocol: TCP
      name: tcp
      port: ${port_tcp}
      targetPort: ${port_tcp}
    - protocol: TCP
      name: ui
      port: ${port_ui}
      targetPort: ${port_ui}
  selector:
    app: frps
" | kubectl apply -f -


bind_route_rule=$(getarg bind_route_rule $@)
bind_route_rule=${bind_route_rule:-'frps.localhost'}

dashboard_route_rule=`getarg dashboard_route_rule $@`
dashboard_route_rule=${dashboard_route_rule:-'frps-ui.localhost'}

http_route_rule=$(getarg http_route_rule $@)
http_route_rule=${http_route_rule:-'frps-http-*.localhost'}

tcp_route_rule=$(getarg tcp_route_rule $@)
tcp_route_rule=${tcp_route_rule:-'frps-tcp-*localhost'}


srv_name=$(kubectl get service -n ${namespace} | grep frps | awk '{print $1}')

install_ingress_rule \
--name frps-bind \
--namespace ${namespace} \
--ingress_class ${ingress_class} \
--service_name $srv_name \
--service_port $port_bind \
--domain ${bind_route_rule}

install_ingress_rule \
--name frps-ui \
--namespace ${namespace} \
--ingress_class ${ingress_class} \
--service_name $srv_name \
--service_port $port_ui \
--domain ${dashboard_route_rule}

install_ingress_rule \
--name frps-http \
--namespace ${namespace} \
--ingress_class ${ingress_class} \
--service_name $srv_name \
--service_port $port_http \
--domain ${http_route_rule}

install_ingress_rule \
--name frps-tcp \
--namespace ${namespace} \
--ingress_class ${ingress_class} \
--service_name $srv_name \
--service_port $port_tcp \
--domain ${tcp_route_rule}


rm -rf ${tmpdir}


echo "------------------------------------------------------------------"
echo "done"
echo "------------------------------------------------------------------"
