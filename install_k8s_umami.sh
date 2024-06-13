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
namespace=${namespace:-"web-system"}
password=`getarg password $@ 2>/dev/null`
password=${password:-"Pa44VV0rd14VVrOng"}
storage_class=`getarg storage_class $@  2>/dev/null`
storage_class=${storage_class:-""}

ingress_class=`getarg ingress_class $@ 2>/dev/null`
ingress_class=${ingress_class:-higress}

db_namespace=`getarg db_namespace $@ 2>/dev/null`
db_namespace=${db_namespace:-db-system}


kubectl exec -i -t -n ${db_namespace} mysql-primary-0 -c mysql -- sh -c "\
mysql -uroot -p${password} -e '\
CREATE DATABASE IF NOT EXISTS umami;\
show databases;\
'"

# https://stianlagstad.no/2022/08/deploy-umami-analytics-with-kubernetes/

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
              value: \"$(pwgen 16 -n 1)\" # Just need to be something other than "umami", so that ad blockers don't block it
            - name: DISABLE_TELEMETRY
              value: \"1\"
            - name: DISABLE_UPDATES
              value: \"1\"
            - name: DATABASE_URL
              value: \"mysql://root:${password}@mysql-primary.${db_namespace}.svc:3306/umami\"
            - name: HASH_SALT
              value: \"$(pwgen 16 -n 1)\"
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


umami_route_rule=`getarg umami_route_rule $@ 2>/dev/null`
umami_route_rule=${umami_route_rule:-'umami.localhost'}
srv_name=$(kubectl get service -n ${namespace} | grep umami | awk '{print $1}')
src_port=$(kubectl get services -n ${namespace} $srv_name -o jsonpath="{.spec.ports[0].port}")
install_ingress_rule \
--name umami \
--namespace ${namespace} \
--ingress_class ${ingress_class} \
--service_name $srv_name \
--service_port $src_port \
--domain ${umami_route_rule}



echo "---------------------------------------------"
echo "done: admin:umami"
echo "---------------------------------------------"


