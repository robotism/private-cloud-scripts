#/bin/bash -e

if [ -n "$(echo $REPO | grep ^http)" ]
then
source <(curl -s ${REPO}/env_function.sh) 
else
source ${REPO}/env_function.sh
fi



# 安装docker
if [ ! -n "`which docker`" ]; then
  # curl -fsSL https://get.docker.com | bash -s docker --mirror Aliyun
  sudo dnf install docker-ce --nobest
fi
# 安装docker-compose
if [ ! -n "`which docker-compose`" ]; then
  dnf -y install docker-compose-plugin
  DOCKER_COMPOSE=$(find / -name docker-compose | grep "docker" 2>/dev/null)
  echo $DOCKER_COMPOSE
  sudo chmod 777 $DOCKER_COMPOSE
  \cp -rf $DOCKER_COMPOSE /usr/bin/docker-compose
fi

# 配置
sudo mkdir -p /etc/docker
sudo tee /etc/docker/daemon.json <<-'EOF'
{
    "registry-mirrors": [
        "https://1nj0zren.mirror.aliyuncs.com",
        "http://docker.m.daocloud.io"
    ],
    "max-concurrent-downloads": 20,
    "log-driver": "json-file",
    "log-level": "warn",
    "log-opts": {"max-size":"100m", "max-file":"1"},
    "exec-opts": ["native.cgroupdriver=systemd"],
    "storage-driver": "overlay2",
    "insecure-registries": [
      "sealos.hub:5000"
    ],
    "data-root": "/var/lib/docker"
}
EOF
cat /etc/docker/daemon.json
mkdir -p /etc/systemd/system/docker.service.d
cat > /etc/systemd/system/docker.service.d/limit-nofile.conf <<EOF
[Service]
LimitNOFILE=1048576
EOF

sudo systemctl start docker 2>/dev/null
sudo systemctl enable docker 2>/dev/null
sudo systemctl restart docker 2>/dev/null

docker ps


echo "--------------------------------------------------------------------------------------------"
echo "done"
echo "--------------------------------------------------------------------------------------------"


