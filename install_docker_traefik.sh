#/bin/bash -e

if [ -n "$(echo $REPO | grep ^http)" ]
then
source <(curl -Ls ${REPO}/env_function.sh) 
else
source ${REPO}/env_function.sh
fi

CONTAINER_NAME=traefik

datadir=`getarg datadir $@`
datadir=${datadir:-"$(pwd)/traefik"}

acmedir=`getarg acmedir $@`
acmedir=${acmedir:-"$(pwd)/acme.sh"}

echo "datadir  => $datadir"
echo "acmedir  => $acmedir"

keyfile=`getarg keyfile $@`
certfile=`getarg certfile $@`

keyfile=${keyfile:-$(find $acmedir -name *.key | grep -v "$acmedir/ca")}
certfile=${certfile:-$(find $acmedir -name fullchain.cer | grep -v "$acmedir/ca")}

echo "keyfile  => $keyfile"
echo "certfile => $certfile"

if [ ! -f "$keyfile" ]; then
echo "missing keyfile"
exit 0
fi

if [ ! -f "$certfile" ]; then
echo "missing certfile"
exit 0
fi


route_rule=`getarg route_rule $@`
route_rule=${route_rule:-HostRegexp\(\`\.*\`\)}
dashboard_route_rule=`getarg dashboard_route_rule $@`
dashboard_route_rule=${dashboard_route_rule:-'Host(`traefik.localhost`)'}
dashboard_user=`getarg dashboard_user $@`
dashboard_user=${dashboard_user:-traefik}
dashboard_password=`getarg dashboard_password $@`
dashboard_password=${dashboard_password:-Pa44VV0rd14VVrOng}

echo "route_rule   => $route_rule"
echo "dashboard_route_rule => $dashboard_route_rule"
echo "dashboard_user       => $dashboard_user"
echo "dashboard_password   => $dashboard_password"

dashboard_password=$(openssl passwd -apr1 $dashboard_password)

mkdir -p ${datadir}
mkdir -p ${acmedir}

TREFIK_PORT_PROXY=80
TREFIK_PORT_PROXY_SSL=443

cat << EOF > ${datadir}/traefik.tls.toml
[tls]
  [tls.options]
    [tls.options.default]
      minVersion = "VersionTLS12"
      maxVersion = "VersionTLS12"
    [tls.options.tls13]
      minVersion = "VersionTLS13"
      cipherSuites = [
        "TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256",
        "TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384",
        "TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305",
        "TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305",
        "TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256",
        "TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256",
      ]
  [tls.stores]
    [tls.stores.default]
    [tls.stores.default.defaultCertificate]
      certFile = "${certfile}"
      keyFile  = "${keyfile}"
EOF
cat ${datadir}/traefik.tls.toml

docker rm -f $CONTAINER_NAME 2>/dev/null

docker run -dit \
  --restart=always \
  --privileged \
  -p ${TREFIK_PORT_PROXY}:80 \
  -p ${TREFIK_PORT_PROXY_SSL}:443 \
  -v /var/run/docker.sock:/var/run/docker.sock:ro \
  -v ${datadir}:/etc/traefik/config:ro \
  -v ${acmedir}:${acmedir}:ro \
  -l traefik.enable=true \
  -l traefik.http.routers.http-redirect.rule=${route_rule} \
  -l traefik.http.routers.http-redirect.entrypoints=web \
  -l traefik.http.routers.http-redirect.middlewares=https-redirect \
  -l traefik.http.middlewares.https-redirect.redirectscheme.scheme=https \
  -l traefik.http.middlewares.https-redirect.redirectscheme.permanent=false \
  -l traefik.http.middlewares.sslheader.headers.customrequestheaders.X-Forwarded-Proto=https \
  -l traefik.http.middlewares.auth-dashboard.basicauth.users=${dashboard_user}:${dashboard_password} \
  -l traefik.http.routers.dashboard.rule=${dashboard_route_rule} \
  -l traefik.http.routers.dashboard.tls=true \
  -l traefik.http.routers.dashboard.service=api@internal \
  -l traefik.http.routers.dashboard.middlewares=auth-dashboard \
  -l traefik.http.services.adummy.loadbalancer.server.port=3389 \
  --name=${CONTAINER_NAME} \
  traefik:v3.0 \
  --global.checkNewVersion=false \
  --global.sendAnonymousUsage=false \
  --serversTransport.insecureSkipVerify=true \
  --log.level=DEBUG \
  --api=true \
  --api.debug=false \
  --api.insecure=false \
  --api.dashboard=true \
  --entrypoints.web.address=:${TREFIK_PORT_PROXY} \
  --entrypoints.websecure.address=:${TREFIK_PORT_PROXY_SSL} \
  --providers.docker=true \
  --providers.docker.watch=true \
  --providers.docker.exposedbydefault=false \
  --providers.docker.endpoint=unix:///var/run/docker.sock \
  --providers.file=true \
  --providers.file.watch=true \
  --providers.file.directory=/etc/traefik/config \


docker ps -a | grep ${CONTAINER_NAME} 2>/dev/null
docker logs -n 1000 ${CONTAINER_NAME} 2>/dev/null

echo "-----------------------------------------------------------"
echo "done: container name = ${CONTAINER_NAME}"
echo "-----------------------------------------------------------"

  
