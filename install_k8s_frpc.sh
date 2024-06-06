#/bin/bash -e

if [ -n "$(echo $REPO | grep ^http)" ]
then
source <(curl -s ${REPO}/env_function.sh) 
else
source ${REPO}/env_function.sh
fi

FRPC_TOML=frpc.toml
FRPC_YAML=${name}.yaml


bind_ips=$(getarg bind_ips $@)
bind_port=$(getarg bind_port $@)
bind_port=${bind_port:-7000}

tmpdir=$(getarg tmpdir $@)
tmpdir=${tmpdir:-"$(pwd)"}
tmpdir=${tmpdir}/.k8s_${name}

namepsace=$(getarg namepsace $@)
namepsace=${namepsace:-higress-system}

http_upstream_host=$(getarg http_upstream_host $@)
http_upstream_host=${http_upstream_host:-higress-gateway.higress-system.svc.cluster.local}
http_upstream_port=$(getarg http_upstream $@)
http_upstream_port=${http_upstream:-80}
http_route_rule=$(getarg http_route_rule $@)
http_route_rule=${http_route_rule:-"*"}

tcp_upstream_host=$(getarg tcp_upstream_host $@)
tcp_upstream_host=${tcp_upstream_host:-local}
tcp_upstream_port=$(getarg tcp_upstream $@)
tcp_upstream_port=${tcp_upstream:-8080}
tcp_route_rule=$(getarg tcp_route_rule $@)
tcp_route_rule=${tcp_route_rule:-"tcp-*"}


token=$(getarg token $@)
token=${token:-pa44vv0rd}

if [ ! -n "$bind_ips" ]; then
echo "missing bind_ips"
exit 0
fi


install_frpc(){

  mkdir -p $tmpdir

  name=$(getarg name $@)
  name=${name:-frpc}
  bind_ip=$(getarg bind_ip $@)

cat << EOF > ${tmpdir}/frpc.toml
serverAddr = "${bind_ip}"
serverPort = ${bind_port}
auth.token = "${token}"

log.level = "debug"

[[proxies]]
name = "k8s-tcp-${name}"
type = "tcpmux"
multiplexer = "httpconnect"
localIp = "${tcp_upstream_host}"
localPort = ${tcp_upstream_port}
customDomains = ["${tcp_route_rule}"]
EOF

  local _idx=0
  http_route_rule=$(echo $http_route_rule |  tr ',' ' ')
  for domain in $http_route_rule   
  do  
  local _idx=`expr $_idx + 1`

cat << EOF >> ${tmpdir}/frpc.toml
[[proxies]]
name = "k8s-http-client${name}-domain${_idx}"
type = "http"
localIp = "${http_upstream_host}"
localPort = ${http_upstream_port}
customDomains = ["${domain}"]
EOF
  done


  echo "------------------------------------------------------"
  cat ${tmpdir}/frpc.toml
  echo "------------------------------------------------------"

  kubectl delete secret ${name}.toml -n ${namepsace}
  kubectl create secret generic ${name}.toml -n ${namepsace} --from-file=${tmpdir}/frpc.toml

cat << EOF > ${tmpdir}/${FRPC_YAML}
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${name}
  namespace: ${namepsace}
  labels:
    app: ${name}
    frps: ${bind_ip}
spec:
  replicas: 1
  selector:
    matchLabels:
      app: ${name}
  template:
    metadata:
      labels:
        app: ${name}
        frps: ${bind_ip}
    spec:
      containers:
        - name: ${name}
          image: snowdreamtech/frpc:0.58.0
          volumeMounts:
            - name: config
              mountPath: "/etc/frp"
              readOnly: true
      volumes:
        - name: config
          secret:
            secretName: ${name}.toml
EOF
  kubectl delete -f ${tmpdir}/${FRPC_YAML} 2>/dev/null
  kubectl apply -f ${tmpdir}/${FRPC_YAML}

  rm -rf ${tmpdir}
}


idx=0
bind_ips=$(echo $bind_ips |  tr ',' ' ')
for bind_ip in $bind_ips   
do  
idx=`expr $idx + 1`
install_frpc --bind_ip $bind_ip --name frpc-${idx}
done

echo "------------------------------------------------------------------"
echo "done"
echo "------------------------------------------------------------------"
