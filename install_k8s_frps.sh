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

namespace=$(getarg namespace $@)
namespace=${namespace:-frp-system}

kubectl create namespace $namespace 2>/dev/null

token=$(getarg token $@)
token=${token:-${TOKEN}}
token=${token:-Pa44VV0rd14VVrOng}


dashboard_route_rule=`getarg dashboard_route_rule $@`
dashboard_route_rule=${dashboard_route_rule:-'Host(`frps.localhost`)'}

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


http_route_rule=$(getarg http_route_rule $@)
http_route_rule=${http_route_rule:-Host\(\`localhost\`\)}

tcp_route_rule=$(getarg tcp_route_rule $@)
tcp_route_rule=${tcp_route_rule:-HostSNI\(\`localhost\`\)}


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
        traefik.enable: "true"
        traefik.http.routers.${CONTAINER_NAME}-http.rule: "${http_route_rule}"
        traefik.http.routers.${CONTAINER_NAME}-http.tls: "${tls}"
        traefik.http.routers.${CONTAINER_NAME}-http.entrypoints: "${entrypoints}"
        traefik.http.routers.${CONTAINER_NAME}-http.service: "${CONTAINER_NAME}-http@docker"
        traefik.http.services.${CONTAINER_NAME}-http.loadbalancer.server.port: "${port_http}"
        traefik.http.services.${CONTAINER_NAME}-http.loadBalancer.passHostHeader: "true"
        traefik.http.middlewares.${CONTAINER_NAME}-http.headers.customrequestheaders.X-Forwarded-Proto: "https"
        traefik.http.middlewares.${CONTAINER_NAME}-http.headers.contentSecurityPolicy: "upgrade-insecure-requests"
        traefik.tcp.routers.${CONTAINER_NAME}-tcp.rule: "${tcp_route_rule}"
        traefik.tcp.routers.${CONTAINER_NAME}-tcp.tls: "${tls}"
        traefik.tcp.routers.${CONTAINER_NAME}-tcp.entrypoints: "${entrypoints}"
        traefik.tcp.routers.${CONTAINER_NAME}-tcp.service: "${CONTAINER_NAME}-tcp@docker"
        traefik.tcp.services.${CONTAINER_NAME}-tcp.loadbalancer.server.port: "${port_tcp}"
        traefik.http.routers.${CONTAINER_NAME}-ui.rule: "${dashboard_route_rule}"
        traefik.http.routers.${CONTAINER_NAME}-ui.tls: "${tls}"
        traefik.http.routers.${CONTAINER_NAME}-ui.entrypoints: "${entrypoints}"
        traefik.http.routers.${CONTAINER_NAME}-ui.service: "${CONTAINER_NAME}-ui@docker"
        traefik.http.services.${CONTAINER_NAME}-ui.loadbalancer.server.port: "${port_ui}"
    spec:
      containers:
        - name: frps
          image: docker.io/snowdreamtech/frps:0.61
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

rm -rf ${tmpdir}


echo "------------------------------------------------------------------"
echo "done"
echo "------------------------------------------------------------------"
