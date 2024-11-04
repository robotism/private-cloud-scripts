#/bin/bash -e

if [ -n "$(echo $REPO | grep ^http)" ]
then
source <(curl -Ls ${REPO}/env_function.sh) 
else
source ${REPO}/env_function.sh
fi


# sealos, k8s, helm, gateway-api, cilium, istio, openebs, cert-manager, higress

cri_provider=`getarg cri_provider $@ 2>/dev/null`
cri_provider=${cri_provider:-containerd}


### 安装命令工具 Sealos
install_sealos(){
  if [ ! -n "`which sealos 2>/dev/null`" ]; then
    echo "deb [trusted=yes] https://apt.fury.io/labring/ /" | sudo tee /etc/apt/sources.list.d/labring.list
    sudo apt update
    sudo apt install sealos --fix-missing
  fi
}


# https://github.com/labring-actions/cluster-image-docs/blob/main/docs/aliyun-shanghai/rootfs.md
install_k8s(){
  local password=$(getarg password $@)
  local masters=`getarg masters $@`
  local nodes=`getarg nodes $@`
  
  if [ "$cri_provider" = "containerd" ]; then
  local k8s_image="kubernetes"
  fi
  if [ "$cri_provider" = "docker" ]; then
  local k8s_image="kubernetes-docker"
  fi
  if [ "$cri_provider" = "k3s" ]; then
  local k8s_image="k3s"
  fi
  local k8s_image=${k8s_image:-"kubernetes"}
  if [ ! -n "`which kubectl 2>/dev/null`" ]; then
  sudo sealos run -f ${labring_image_registry}/${labring_image_repository}/${k8s_image}:v1.29.9 --masters ${masters:-""} -p ${password}
  fi
  if [ -n "$nodes" ]; then
  sealos add --nodes $nodes -p ${password}
  fi
}


# https://github.com/labring-actions/cluster-image-docs/blob/main/docs/aliyun-shanghai/apps.md

  # https://github.com/labring-actions/cluster-image/blob/main/applications/helm
isntall_helm(){
  sudo sealos run -f ${labring_image_registry}/${labring_image_repository}/helm:v3.15.4
}


install_helm_charts(){
  helm repo add aliyun https://kubernetes.oss-cn-hangzhou.aliyuncs.com/charts >/dev/null
  helm repo add kaiyuanshe http://mirror.kaiyuanshe.cn/kubernetes/charts >/dev/null
  helm repo add dandydev https://dandydeveloper.github.io/charts >/dev/null
  helm repo add azure http://mirror.azure.cn/kubernetes/charts >/dev/null
  helm repo add bitnami https://charts.bitnami.com/bitnami >/dev/null
}

# https://github.com/kubernetes-sigs/gateway-api/releases
install_gateway_api(){
  # Gateway API CRD 
  # kubectl apply -f ${GHPROXY}https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.1.1/standard-install.yaml
  kubectl apply -f ${GHPROXY}https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.1.1/experimental-install.yaml
}

# https://github.com/labring-actions/cluster-image/blob/main/applications/cilium
install_cilium(){
  kubectl -n kube-system delete ds kube-proxy
  kubectl -n kube-system delete cm kube-proxy
  # Run on each node with root permissions:
  # iptables-save | grep -v KUBE | iptables-restore
  
  sudo sealos run -f ${labring_image_registry}/${labring_image_repository}/cilium:v1.16.1 \
    --env ExtraValues="kubeProxyReplacement=true,"
    # -e HELM_OPTS="--set bpf.masquerade=true --set kubeProxyReplacement=true --set ipam.mode=kubernetes "

  cilium status --wait
  cilium status 
}

upgrade_cilium(){
  local version=`getarg version $@`
  local version=${version:-v1.16.1}
  local running=$(cilium version | grep running)
  local running=$(echo $running |awk -F '[ ]' '{print $NF}')
  local hubble=`getarg hubble $@`
  local hubble=${hubble:-false}
  
  local gateway=${gateway:-false}

  cilium upgrade --version $version \
  --set kubeProxyReplacement=true \
  --set ipam.mode=kubernetes \
  --set bpf.masquerade=true \
  --set operator.replicas=1 \
  --set hubble.enabled=${hubble} \
  --set hubble.ui.enabled=${hubble} \
  --set hubble.relay.enabled=${hubble} \
  # --set gatewayAPI.enabled=${gateway} \
  # --set gatewayAPI.hostNetwork.enabled=false \
  # --set enable-ipv4=true \
  # --set envoy.enabled=true \
  # --set envoyConfig.enabled=true \
  # --set loadBalancer.l7.backend=envoy \
  # --set ingressController.enabled=true \
  # --set ingressController.loadbalancerMode=shared \

  cilium status --wait
  cilium status 
}


delete_cilium_cidr_all(){
  kubectl delete CiliumLoadBalancerIPPool --all 2>/dev/null
}


install_cilium_cidr(){
  #
  local cidr=`getarg cidr $@`
  local cidr=$(echo $cidr |  tr ',' ' ')
  echo "cidr=>$cidr"
  for addr in $cidr   
  do  
kubectl apply -f - <<EOF
apiVersion: "cilium.io/v2alpha1"
kind: CiliumLoadBalancerIPPool
metadata:
  name: "ip-pool-${addr}"
spec:
  blocks:
  - cidr: "${addr}/32"
EOF
  done

}


# https://github.com/labring-actions/cluster-image/blob/main/applications/openebs
install_openebs(){
  sudo sealos run -f ${labring_image_registry}/${labring_image_repository}/openebs:v3.10.0
}

# https://github.com/labring-actions/cluster-image/blob/main/applications/longhorn
install_longhorn(){
  sudo sealos run -f ${labring_image_registry}/${labring_image_repository}/longhorn:v1.6.1
}

# https://github.com/labring-actions/cluster-image/blob/main/applications/cert-manager
install_cert_manager(){
  sudo sealos run -f ${labring_image_registry}/${labring_image_repository}/cert-manager:v1.15.0
  kubectl -n cert-manager wait --for=condition=Ready pods --all
}



# https://istio.io/latest/zh/docs/reference/config/istio.operator.v1alpha1/#GatewaySpec
# https://github.com/labring-actions/cluster-image/blob/main/applications/istio
# https://istio.io/latest/zh/docs/setup/additional-setup/config-profiles/
install_istio(){
  local profile=`getarg profile $@`
  
  sudo sealos run -f ${labring_image_registry}/${labring_image_repository}/istio:v1.20.1 \
      -e ISTIOCTL_OPTS="--set profile=${profile:-minimal} -y"
  kubectl -n istio-system wait --for=condition=Ready pods --all
  kubectl get gatewayclass
  kubectl label namespace default istio-injection=enabled
  # istioctl dashboard controlz deployment/istiod.istio-system
  # kubectl get namespace -L istio-injection
  # kubectl get all -n istio-system
  
}


# https://github.com/labring-actions/cluster-image/blob/main/applications/metrics-server
install_metrics_server(){
  sudo sealos run -f ${labring_image_registry}/${labring_image_repository}/metrics-server:v0.7.1
}

# https://github.com/labring-actions/cluster-image/blob/main/applications/kube-state-metrics
install_kube_state_metrics(){
  sudo sealos run -f ${labring_image_registry}/${labring_image_repository}/kube-state-metrics:v2.4.2
}


# https://github.com/labring-actions/cluster-image/blob/main/applications/ingress-nginx
install_ingress_nginx(){
  local host=`getarg host $@`
  sudo sealos run -f ${labring_image_registry}/${labring_image_repository}/ingress-nginx:v1.11.2 \
  -e HELM_OPTS="--set controller.hostNetwork=${host:-true} --set controller.kind=DaemonSet --set controller.service.type=NodePort"
  # 使用宿主机网络, DaemonSet保证每个节点都可以接管流量, 使用NodePort暴露端口
  # 至此可以应用可以使用 ingressClass=ingress 暴露服务; 值得注意的是, 如果服务不可用,可能LoadBalancer不会分配ExternalIP
}

# https://github.com/labring-actions/cluster-image/blob/main/applications/higress
install_higress(){

  local local=`getarg local $@`
  local host=`getarg host $@`
  local type=`getarg type $@`
  local istio=`getarg istio $@`
  local gateway=`getarg gateway $@`

  echo "local=${local:-true}"
  echo "host=${host:-false}"
  echo "type=${type:-LoadBalancer}"
  echo "istio=${istio:-true}"
  echo "gateway=${gateway:-true}"

  sudo sealos run -f ${labring_image_registry}/${labring_image_repository}/higress:v2.0.1 \
  -e HELM_OPTS=" \
  --set global.local=${local:-true} \
  --set global.ingressClass=higress \
  --set global.enableIstioAPI=${istio:-true} \
  --set global.enableGatewayAPI=${gateway:-true} \
  --set higress-core.gateway.replicas=1 \
  --set higress-core.gateway.hostNetwork=${host:-false} \
  --set higress-core.gateway.service.type=${type:-LoadBalancer} \
  --set higress-core.controller.replicas=1 \
  --set higress-core.controller.service.type=ClusterIP \
  --set higress.console.replicas=1 \
  --set higress-console.service.type=NodePort \
  --set higress-console.certmanager.enabled=false \
  "

  kubectl -n higress-system wait --for=condition=Ready pods --all
  kubectl get po -n higress-system
  # kubectl port-forward service/higress-gateway -n higress-system 80:80 443:443

}

install_higress_console(){
  higress_route_rule=`getarg higress_route_rule $@`
  srv_name=$(kubectl get service -n higress-system | grep console | awk '{print $1}')
  srv_port=$(kubectl get services -n higress-system $srv_name -o jsonpath="{.spec.ports[0].port}")
  install_ingress_rule \
  --name higress-console \
  --namespace higress-system \
  --ingress_class higress \
  --service_name $srv_name \
  --service_port ${src_port:-8080} \
  --domain $higress_route_rule
}

master_ips=$(getarg master_ips $@)
node_ips=$(getarg node_ips $@)
password=$(getarg password $@)

istio_enable=$(getarg istio_enable $@)
istio_enable=${istio_enable:-false}

gateway_enable=$(getarg gateway_enable $@)
gateway_enable=${gateway_enable:-false}

storage_type=$(getarg storage_type $@)
storage_type=${storage_type:-openebs}

ingress_class=$(getarg ingress_class $@)
ingress_class=${ingress_class:-higress}

ingress_node_type=$(getarg ingress_node_type $@)
ingress_node_type=${ingress_node_type:-LoadBalancer}

ingress_host_net=$(getarg ingress_host_net $@)
ingress_host_net=${ingress_host_net:-false}

install_sealos

if [ ! -n "$master_ips" ]; then
echo "missing master_ips"
exit 0
fi

install_k8s --masters ${master_ips} --nodes ${node_ips} --password ${password}
isntall_helm
install_helm_charts

install_gateway_api

install_cilium
upgrade_cilium --hubble false --gateway ${gateway_enable}

install_cert_manager

install_metrics_server
install_kube_state_metrics


if [ "$storage_type" = "openebs" ]; then
install_openebs
fi
if [ "$storage_type" = "longhorn" ]; then
install_longhorn
fi

if [ "$istio_enable" = "true" ]; then
install_istio --profile minimal
fi

if [ "$ingress_class" = "nginx" ]; then
install_ingress_nginx --host ${ingress_host_net}
fi

if [ "$ingress_class" = "higress" ]; then
install_higress --type ${ingress_node_type} --istio ${istio_enable} --gateway ${gateway_enable}
install_higress_console $@
fi

if [ "$ingress_node_type" = "LoadBalancer" ]; then
IP_POOL=${master_ips},${node_ips}
delete_cilium_cidr_all
install_cilium_cidr --cidr $IP_POOL
kubectl annotate svc higress-gateway -n higress-system --overwrite io.cilium/lb-ipam-ips=$IP_POOL
fi

kubectl taint nodes --all node-role.kubernetes.io/master-  2>/dev/null
kubectl taint nodes --all node-role.kubernetes.io/control-plane-  2>/dev/null


echo "---------------------------------------------"
echo "kubeconfig: cat /etc/kubernetes/admin.conf"
echo "done"
echo "---------------------------------------------"

