#/bin/bash -e

if [ -n "$(echo $REPO | grep ^http)" ]
then
source <(curl -s ${REPO}/env_function.sh) 
else
source ${REPO}/env_function.sh
fi

CONTAINER_NAME=frps

datadir=$(getarg datadir $@)
datadir=${datadir:-"$(pwd)/frp"}

ip=$(getarg ip $@)
ip=${ip:-$(curl ifconfig.me --silent)}
tls=$(getarg tls $@)
tls=${tls:-true}

token=$(getarg token $@)
token=${token:-pa44vv0rd}

http_route_rule=$(getarg http_route_rule $@)
http_route_rule=${http_route_rule:-Host\(\`localhost\`\)}

tcp_route_rule=$(getarg tcp_route_rule $@)
tcp_route_rule=${tcp_route_rule:-HostSNI\(\`localhost\`\)}

dashboard_route_rule=`getarg dashboard_route_rule $@`
dashboard_route_rule=${dashboard_route_rule:-'Host(`frps.localhost`)'}
dashboard_user=`getarg dashboard_user $@`
dashboard_user=${dashboard_user:-frps}
dashboard_password=`getarg dashboard_password $@`
dashboard_password=${dashboard_password:-${token}}

if [ "$tls" = "true" ]; then
entrypoints=websecure
fi
if [ "$tls" != "true" ]; then
entrypoints=web
fi

echo "http_route_rule => $http_route_rule"
echo "tcp_route_rule => $tcp_route_rule"
echo "dashboard_route_rule => $dashboard_route_rule"
mkdir -p ${datadir}

port_bind=${port_bind:-7000}
port_ui=${port_ui:-7500}
port_http=${port_http:-8080}
port_tcp=${port_tcp:-8000}

FRPS_CONFIG=frps.toml
cat << EOF > ${datadir}/${FRPS_CONFIG}
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
echo "${FRPS_CONFIG}:"
cat ${datadir}/${FRPS_CONFIG}
echo "------------------------------------------------------"

docker rm -f $CONTAINER_NAME 2>/dev/null

# https://doc.traefik.io/traefik/v3.0/routing/providers/docker
docker run -dit \
  --restart=always \
  --privileged \
  -p ${port_bind}:${port_bind} \
  -v ${datadir}/${FRPS_CONFIG}:/etc/frp/${FRPS_CONFIG} \
  -l traefik.enable=true \
  -l traefik.http.routers.${CONTAINER_NAME}-http.rule=${http_route_rule} \
  -l traefik.http.routers.${CONTAINER_NAME}-http.tls=${tls} \
  -l traefik.http.routers.${CONTAINER_NAME}-http.entrypoints=${entrypoints} \
  -l traefik.http.routers.${CONTAINER_NAME}-http.service=${CONTAINER_NAME}-http@docker \
  -l traefik.http.services.${CONTAINER_NAME}-http.loadbalancer.server.port=${port_http} \
  -l traefik.http.services.${CONTAINER_NAME}-http.loadBalancer.passHostHeader=true \
  -l traefik.http.middlewares.${CONTAINER_NAME}-http.headers.contentSecurityPolicy=upgrade-insecure-requests \
  -l traefik.tcp.routers.${CONTAINER_NAME}-tcp.rule=${tcp_route_rule} \
  -l traefik.tcp.routers.${CONTAINER_NAME}-tcp.tls=${tls} \
  -l traefik.tcp.routers.${CONTAINER_NAME}-tcp.entrypoints=${entrypoints} \
  -l traefik.tcp.routers.${CONTAINER_NAME}-tcp.service=${CONTAINER_NAME}-tcp@docker \
  -l traefik.tcp.services.${CONTAINER_NAME}-tcp.loadbalancer.server.port=${port_tcp} \
  -l traefik.http.routers.${CONTAINER_NAME}-ui.rule=${dashboard_route_rule} \
  -l traefik.http.routers.${CONTAINER_NAME}-ui.tls=${tls} \
  -l traefik.http.routers.${CONTAINER_NAME}-ui.entrypoints=${entrypoints} \
  -l traefik.http.routers.${CONTAINER_NAME}-ui.service=${CONTAINER_NAME}-ui@docker \
  -l traefik.http.services.${CONTAINER_NAME}-ui.loadbalancer.server.port=${port_ui} \
  --name=${CONTAINER_NAME} \
  snowdreamtech/frps:0.58.0

docker ps -a | grep ${CONTAINER_NAME} 2>/dev/null
docker logs -n 1000 ${CONTAINER_NAME} 2>/dev/null

echo "-----------------------------------------------------------"
echo "done"
echo "-----------------------------------------------------------"

  
