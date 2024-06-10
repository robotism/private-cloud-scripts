# scripts for privte k8s cloud deployment

> **私有云部署脚本**

>  </br>-----------------------------------------------------------------------------------------------
>  </br>   cloud servers + traefix acme + frp servers
>  </br>-----------------------------------------------------------------------------------------------
>  </br>   local vmware k8s cluter + helm + cilium + istio + higress + frp clients
>  </br>-----------------------------------------------------------------------------------------------
>  </br>   opentelemetry + skywalking + db + mq + spring cloud + ......
>  </br>-----------------------------------------------------------------------------------------------
>  </br>
>  </br>

## 设置环境变量

```bash

export TEMP=/opt/tmp
export DATA=/opt/data

# 代理
# export GHPROXY=https://ghproxy.org/
export GHPROXY=https://mirror.ghproxy.com/

export REPO=${GHPROXY}https://raw.githubusercontent.com/robotism/private-cloud-scripts/master
export SCRIPTS_REPO=${SCRIPTS_REPO}

export LABRING_REPO=registry.cn-shanghai.aliyuncs.com #
export BITNAMI_REPO=docker.io # 请替换自己的aliyun镜像地址

export ANSIBLE_VARS="\
export TEMP=${TEMP} && \
export DATA=${DATA} && \
export GHPROXY=${GHPROXY} && \
export REPO=${REPO} && \
export SCRIPTS_REPO=${SCRIPTS_REPO} && \
export LABRING_REPO=${LABRING_REPO} && \
export BITNAMI_REPO=${BITNAMI_REPO} && \
"

export DOMAIN=example.com
export TOKEN=Pa44VV0rd14VVrOng

# 云主机
export CLOUD_IPS=xxx,xxx # WAN
export CLOUD_SSH_PWD=xxxxxxxxx

# 本地主机
export K8S_MASTER_IPS=10.0.0.1,10.0.0.2 #VLAN
export K8S_NODE_IPS=10.0.0.3,10.0.0.4 #VLAN
export K8S_SSH_PWD=xxxxxxxxxx


```

----

## 部署云服务器

### 一键初始化debian和ansbile集群

```bash

bash <(curl -s ${REPO}/init_ansible_cluster.sh) \
--hostname cloud-node- \
--ips $CLOUD_IPS \
--password ${CLOUD_SSH_PWD}

ansible all -m raw -a "mkdir -p ${TEMP}"
ansible all -m raw -a "mkdir -p ${DATA}"


```

### 一键初始化debian和docker环境

```bash

# 单独操作
# bash <(curl -s ${REPO}/init_debian_docker.sh) --profile ${PROFILE:-release}

# 批量操作
ansible all -m raw -a "${ANSIBLE_VARS} bash <(curl -s ${REPO}/init_debian_docker.sh) --profile ${PROFILE:-release}"

ansible all -m raw -a "sleep 3s && reboot"

ansible all -m raw -a "hostname && docker ps"

# test doamin->ip->nginx:80
# ansible all -m raw -a 'docker run -dit -p 80:80 --name=nginx nginx'
# ansible all -m raw -a 'docker rm -f $(docker ps -aq)'

```

---

### 一键生成acme免费证书


```bash

ACME_CRON_DIR=${DATA}/cron
mkdir -p $ACME_CRON_DIR
ACME_CRON_SH=$ACME_CRON_DIR/acme.cron.sh
ACME_CRON_LOG=$ACME_CRON_DIR/acme.cron.log
cat << EOF > $ACME_CRON_SH
echo "####################################"
echo "acme.sh exec @ $(date +%F) $(date +%T)" >> $ACME_CRON_LOG
export DP_ID=${DP_ID:-xxxxxx}               # 请按需替换
export DP_KEY=${DP_KEY:-xxxxxxxxxxxxxxxx}   # 请按需替换
bash <(curl -s ${REPO}/install_docker_acme.sh) \
--output ${TEMP}/acme.sh \
--dns dns_dp \
--apikey DP_Id=${DP_ID} \
--apisecret DP_Key=${DP_KEY} \
--domains ${DOMAIN},*.${DOMAIN} \
--server zerossl \
--daemon false
ansible all -m raw -a "rm -rf ${DATA}/acme.sh"
ansible all -m copy -a "src=${TEMP}/acme.sh dest=${DATA} force=yes"
ansible all -m raw -a "ls ${DATA}/acme.sh"
ansible all -m raw -a "docker restart traefik 2>/dev/null"
EOF
chmod +x $ACME_CRON_SH
echo ""
echo "--------------------------------------------------------------------------"
ls $ACME_CRON_DIR
echo "--------------------------------------------------------------------------"
cat $ACME_CRON_SH
echo "--------------------------------------------------------------------------"
echo ""
bash $ACME_CRON_SH
ansible localhost -m cron -a "name='acme.cron.sh' state=absent"
ansible localhost -m cron -a "name='acme.cron.sh' job='bash $ACME_CRON_SH >> $ACME_CRON_LOG' month=*/1 day=1 hour=3 minute=0"
ansible localhost -m raw -a "crontab -l"

# ansible localhost -m cron -a "name='test' state=absent"
# ansible localhost -m cron -a "name='test' job='echo testing >> ~/test.log' minute=*/1" && tail -f ~/test.log
# 
```

### 一键部署Traefik

- dnspod

```bash

ansible all -m raw -a "${ANSIBLE_VARS} \
bash <(curl -s ${REPO}/install_docker_traefik.sh) \
--datadir ${DATA}/traefik \
--acmedir ${DATA}/acme.sh \
--route_rule 'HostRegexp(\`.*\`)' \
--dashboard_route_rule 'Host(\`traefik.${DOMAIN}\`)' \
--dashboard_user traefik \
--dashboard_password ${TOKEN} \
"
ansible all -m raw -a "docker logs -n 10 traefik"

```

### 一键部署frps

- dnspod

```bash

ansible all -m raw -a "${ANSIBLE_VARS} \
bash <(curl -s ${REPO}/install_docker_frps.sh) \
--datadir ${DATA}/frp \
--http_route_rule 'HostRegexp(\`.*\`)&&!HostRegexp(\`^(traefik|frps|tcp)\`)' \
--tcp_route_rule 'HostSNIRegexp(\`^tcp-.*.${DOMAIN}\`)' \
--dashboard_route_rule 'Host(\`frps.${DOMAIN}\`)' \
--dashboard_user frps \
--token ${TOKEN} \
"
ansible all -m raw -a "docker logs -n 10 frps"
ansible all -m raw -a "docker logs -n 10 traefik"

```

---

## 部署本地服务器

### 一键初始化系统

```bash
# init master ------------------------
bash <(curl -s ${REPO}/init_debian_docker.sh) \
--profile ${PROFILE:-release} \
--sources ustc \
--install_docker false

# init ansible  ------------------------
bash <(curl -s ${REPO}/init_ansible_cluster.sh) \
--hostname k8s-node- \
--ips ${K8S_MASTER_IPS},${K8S_NODE_IPS} \
--password ${K8S_SSH_PWD}

ansible all -m raw -a "mkdir -p ${TEMP}"
ansible all -m raw -a "mkdir -p ${DATA}"

# init all  ------------------------
ansible all -m raw -a "${ANSIBLE_VARS} bash <(curl -s ${REPO}/init_debian_docker.sh) \
--profile ${PROFILE:-release} \
--sources ustc \
--install_docker false \
"
# 本地k8s集群使用cri不需要安装docker

ansible all -m raw -a "sleep 3s && reboot"
ansible all -m raw -a "hostname"

```

### 一键初始化k8s集群(sealos)

```bash
bash <(curl -s ${REPO}/install_k8s_core.sh) \
--master_ips ${K8S_MASTER_IPS:-""} \
--node_ips ${K8S_NODE_IPS:-""} \
--password ${K8S_SSH_PWD} \
--ingress_class higress \
--higress_route_rule higress.${DOMAIN}
```


### 一键部署frpc

```bash
bash <(curl -s ${REPO}/install_k8s_frpc.sh) \
--bind_ips ${CLOUD_IPS} \
--http_upstream_host higress-gateway.higress-system.svc.cluster.local \
--http_upstream_port 80 \
--http_route_rule ${DOMAIN},*.${DOMAIN} \
--token ${TOKEN}
```

### 一键部署 rancher

```bash
bash <(curl -s ${REPO}/install_k8s_rancher.sh) \
--rancher_route_rule rancher.${DOMAIN} \
--ingress_class higress \
--password ${TOKEN}
```

### 一键部署 db

```bash
bash <(curl -s ${REPO}/install_k8s_db.sh) \
--ingress_class higress \
--password ${TOKEN}
```

### 一键部署 mq

```bash
bash <(curl -s ${REPO}/install_k8s_mq.sh) \
--ingress_class higress \
--password ${TOKEN}
```

### 一键部署 monitor

```bash
bash <(curl -s ${REPO}/install_k8s_monitor.sh) \
--ingress_class higress \
--kibana_route_rule kibana.${DOMAIN} \
--grafana_route_rule grafana.${DOMAIN} \
--prometheus_route_rule prometheus.${DOMAIN} \
--skywalking_route_rule skywalking.${DOMAIN} \
--password ${TOKEN}
```

### 一键部署 cloud-ide(code-server)

```bash
bash <(curl -s ${REPO}/install_k8s_ide.sh) \
--ingress_class higress \
--coder_route_rule coder.${DOMAIN} \
--password ${TOKEN}
```



### 一键部署 WebCMS

```bash
bash <(curl -s ${REPO}/install_k8s_webcms.sh) \
--ingress_class higress \
--web_provider ghost \
--web_route_rule ${DOMAIN},www.${DOMAIN} \
--password ${TOKEN}
```


### 一键部署 middleware

```bash
bash <(curl -s ${REPO}/install_ms_middleware.sh) \
--ingress_class higress \
--dtm_route_rule dtm.${DOMAIN} \
--password ${TOKEN}
```