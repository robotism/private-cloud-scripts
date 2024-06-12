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
namespace=${namespace:-"monitor-system"}
password=`getarg password $@ 2>/dev/null`
password=${password:-"Pa44VV0rd14VVrOng"}
storage_class=`getarg storage_class $@  2>/dev/null`
storage_class=${storage_class:-""}

ingress_class=`getarg ingress_class $@ 2>/dev/null`
ingress_class=${ingress_class:-higress}

db_namespace=`getarg db_namespace $@ 2>/dev/null`
db_namespace=${db_namespace:-db-system}


# kubectl exec -i -t -n ${db_namespace} mysql-primary-0 -c mysql -- sh -c "(bash || ash || sh)"
# mysql -uroot -p${password} -e 'CREATE DATABASE IF NOT EXISTS unami;show databases;'


echo "
kind: Deployment
apiVersion: apps/v1
metadata:
  name: umami
  namespace: ${namespace:-default}
  labels:
    app: umami
spec:
  replicas: 1
  selector:
    matchLabels:
      app: umami
  template:
    metadata:
      labels:
        app: umami
    spec:
      containers:
        - name: umami
          image: docker.umami.dev/umami-software/umami:mysql-latest
          ports:
            - name: umami
              containerPort: 3000
          env:
            - name: TRACKER_SCRIPT_NAME
              value: \"{{ randAlphaNum 8 | lower }}\" # Just need to be something other than "umami", so that ad blockers don't block it
            - name: DISABLE_TELEMETRY
              value: \"1\"
            - name: DISABLE_UPDATES
              value: \"1\"
            - name: DATABASE_URL
              value: \"mysql://root:${password}@mysql-primary.${db_namespace}.svc:3306/unami\"
            - name: HASH_SALT
              value: \"{{ randAlphaNum 26 | lower }}\"
          readinessProbe:
            failureThreshold: 1
            httpGet:
              path: /
              port: 3000
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
  name: umami
  namespace: ${namespace:-default}
spec:
  type: ClusterIP
  ports:
    - protocol: TCP
      name: umami
      port: 3000
      targetPort: 3000
  selector:
    app: umami
" | kubectl apply -f -


unami_route_rule=`getarg unami_route_rule $@`
unami_route_rule=${unami_route_rule:-'unami.localhost'}
srv_name=$(kubectl get service -n ${namespace} | grep unami | awk '{print $1}')
src_port=$(kubectl get services -n ${namespace} $srv_name -o jsonpath="{.spec.ports[0].port}")
install_ingress_rule \
--name unami \
--namespace ${namespace} \
--ingress_class ${ingress_class} \
--service_name $srv_name \
--service_port $src_port \
--domain ${unami_route_rule}
