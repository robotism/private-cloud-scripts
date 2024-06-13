#/bin/bash -e

if [ -n "$(echo $REPO | grep ^http)" ]
then
source <(curl -s ${REPO}/env_function.sh) 
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




# https://github.com/jeessy2/ddns-go/blob/master/README.md#docker%E4%B8%AD%E4%BD%BF%E7%94%A8

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

