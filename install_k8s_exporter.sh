#!/bin/bash -e

if [ -n "$(echo $REPO | grep ^http)" ]
then
source <(curl -Ls ${REPO}/env_function.sh) 
else
source ${REPO}/env_function.sh
fi



# https://opentelemetry.io/docs/kubernetes/helm/collector/
install_opentelemetry_collector(){
  if [ ! -n "`kubectl get po -A | grep 'opentelemetry-collector'`" ]; then 
  helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
  helm upgrade --install -n opentelemetry  --create-namespace \
  --set image.repository="otel/opentelemetry-collector-k8s" \
  --set mode=daemonset \
  opentelemetry-collector open-telemetry/opentelemetry-collector
  fi
  # helm uninstall my-opentelemetry-collector -n opentelemetry
}

#  https://opentelemetry.io/docs/kubernetes/helm/operator/
install_opentelemetry_operator(){
  
  if [ ! -n "`kubectl get po -A | grep 'opentelemetry-operator'`" ]; then 
  helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
  helm upgrade --install -n opentelemetry --create-namespace \
  --set "manager.collectorImage.repository=otel/opentelemetry-collector-k8s" \
  --set admissionWebhooks.certManager.enabled=false \
  --set admissionWebhooks.autoGenerateCert.enabled=true \
  opentelemetry-operator open-telemetry/opentelemetry-operator
  # helm uninstall my-opentelemetry-operator -n opentelemetry
  fi

  # https://opentelemetry.io/docs/kubernetes/helm/demo/
  # helm install my-otel-demo open-telemetry/opentelemetry-demo
  # helm uninstall my-otel-demo -n default

}

# https://github.com/labring-actions/cluster-image/blob/main/applications/prometheus-operator 
install_prometheus_operator(){
  if [ ! -n "`kubectl get po -A | grep 'prometheus'`" ]; then
  sudo sealos run -f ${labring_image_registry}/${labring_image_repository}/prometheus-operator:v0.71.2
  fi
}

# https://github.com/labring-actions/cluster-image/blob/main/applications/prometheus
install_prometheus(){
  if [ ! -n "`kubectl get po -A | grep 'prometheus'`" ]; then
  sudo sealos run -f ${labring_image_registry}/${labring_image_repository}/prometheus:v2.49.1 \
  -e NAME=prometheus -e NAMESPACE=prometheus -e HELM_OPTS="--set server.service.type=ClusterIP"
  fi
}

# https://github.com/labring-actions/cluster-image/blob/main/applications/prometheus-node-exporter
install_prometheus_node_exporter(){
  if [ ! -n "`kubectl get po -A | grep 'prometheus-node-exporter'`" ]; then
  sudo sealos run -f ${labring_image_registry}/${labring_image_repository}/prometheus-node-exporter:v1.7.0\
  -e HELM_OPTS="--set service.type=ClusterIP"
  fi
}


install_grafana(){
  echo '------------ installGrafana ------------'
}



echo "---------------------------------------------"
echo "done"
echo "---------------------------------------------"

