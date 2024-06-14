#/bin/bash -e

if [ -n "$(echo $REPO | grep ^http)" ]
then
source <(curl -s ${REPO}/env_function.sh) 
else
source ${REPO}/env_function.sh
fi

# debian

if [ ! -n "`which apt`" ]; then
echo "missing apt"
exit 0
fi


# 初始化env

DATA=${DATA:-/opt/data}

sources=`getarg sources $@`

DEBIAN_SOURCE=/etc/apt/sources.list
if [ ! -f "${DEBIAN_SOURCE}.old.bak" ]; then
  sudo \cp -rf ${DEBIAN_SOURCE} ${DEBIAN_SOURCE}.old.bak
  sudo cat ${DEBIAN_SOURCE}.old.bak
fi
if [ "$sources" = "ustc" ]; then
  sudo \cp -rf ${DEBIAN_SOURCE}.old.bak ${DEBIAN_SOURCE}
  sudo sed -i "s|deb.debian.org|mirrors.ustc.edu.cn|g" ${DEBIAN_SOURCE}
  sudo sed -i 's|security.debian.org/debian-security|mirrors.ustc.edu.cn/debian-security|g' ${DEBIAN_SOURCE}
  sudo sed -i "s|mirrors.163.com|mirrors.ustc.edu.cn|g" ${DEBIAN_SOURCE}
  sudo cat ${DEBIAN_SOURCE}
fi


skip_update=`getarg skip_update $@`

if [ "$skip_update" != "true" ]; then
  sudo apt -y update
  sudo apt -y upgrade
  sudo apt -y autoremove
fi


# init tools

if [ ! -f "/usr/bin/vim" ];then
  sudo apt install -y vim
fi

if [ ! -f "/usr/bin/git" ];then
  sudo apt install -y git
fi

if [ ! -f "/usr/sbin/ifconfig" ];then
  sudo apt install -y net-tools
fi

if [ ! -f "/usr/bin/nslookup" ];then
  sudo apt install -y dnsutils
fi

if [ ! -f "/usr/bin/wget" ];then
  sudo apt install -y wget
fi

if [ ! -f "/usr/bin/curl" ];then
  sudo apt install -y curl
fi

if [ ! -f "/usr/bin/crontab" ];then
  sudo apt install -y cron
fi

if [ ! -f "/usr/bin/pwgen" ];then
  sudo apt install -y pwgen
fi

if [ ! -f "/usr/bin/htpasswd" ];then
  sudo apt install -y apache2-utils
fi

if [ ! -f "/usr/bin/jq" ];then
  sudo apt install -y jq
fi



profile=`getarg profile $@`
profile=${profile:-debug}


if [ "$profile" = "release" ]; then

apt -y install neofetch

export MOTD=/etc/motd
echo -e "" > $MOTD
echo -e "\e[31m**********************************\e[0m" >> $MOTD
echo -e "\e[33m\e[05m⚠️⚠️⚠️⚠︎⚠︎⚠︎⚠️⚠️⚠️⚠︎⚠︎⚠︎⚠️⚠️⚠️⚠︎⚠︎⚠︎⚠️⚠️⚠️⚠︎⚠︎⚠︎⚠️⚠️⚠️⚠︎⚠︎⚠︎⚠️⚠️⚠️⚠︎\e[0m" >> $MOTD
echo -e "\e[31m正式环境, 数据无价, 谨慎操作\e[0m" >> $MOTD
echo -e "\e[33m\e[05m⚠️⚠️⚠️⚠︎⚠︎⚠︎⚠️⚠️⚠️⚠︎⚠︎⚠︎⚠️⚠️⚠️⚠︎⚠︎⚠︎⚠️⚠️⚠️⚠︎⚠︎⚠︎⚠️⚠️⚠️⚠︎⚠︎⚠︎⚠️⚠️⚠️⚠︎\e[0m" >> $MOTD
echo -e "\e[31m**********************************\e[0m" >> $MOTD
echo -e "" >> $MOTD


export NEOFETCH=/etc/profile.d/neofetch.sh
echo '' > $NEOFETCH
echo 'echo "" ' >> $NEOFETCH
echo 'neofetch' >> $NEOFETCH
echo 'echo -e "\e[35mIPV4 WAN: \e[36m`curl ifconfig.me --silent`"' >> $NEOFETCH
echo 'echo -e "\e[31m**********************************" ' >> $NEOFETCH
echo 'echo -e "\e[0m" ' >> $NEOFETCH
echo '' >> $NEOFETCH

fi

# swap off
if [ ! -n "`cat /etc/sysctl.conf | grep 'vm.swappiness' | grep '0'`" ]; then
echo "vm.swappiness = 0">> /etc/sysctl.conf
swapoff -a && swapon -a
sysctl -p
fi


# firewalld off
sudo systemctl stop firewalld.service 2>/dev/null
sudo systemctl disable firewalld.service 2>/dev/null
sudo systemctl status firewalld.service 2>/dev/null

#hugepage
echo never > /sys/kernel/mm/transparent_hugepage/enabled
echo never > /sys/kernel/mm/transparent_hugepage/defrag
cat /sys/kernel/mm/transparent_hugepage/enabled

# sysctl
if [ ! -n "`cat /etc/sysctl.conf | grep 'vm.swappiness' | grep '0'`" ]; then
echo "fs.file-max = 1000000">> /etc/sysctl.conf
echo "net.core.somaxconn = 32768">> /etc/sysctl.conf
echo "net.ipv4.tcp_tw_recycle = 0">> /etc/sysctl.conf
echo "net.ipv4.tcp_syncookies = 0">> /etc/sysctl.conf
echo "vm.overcommit_memory = 1">> /etc/sysctl.conf
sysctl -p
fi

#limits

if [ ! -n "`cat /etc/security/limits.conf | grep root | grep nofile | grep '1000000'`" ]; then
cat << EOF >>/etc/security/limits.conf
root           soft    nofile         1000000
root           hard    nofile         1000000
root           soft    stack          32768
root           hard    stack          32768
EOF
fi

modprobe br_netfilter
cat <<EOF >  /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-arptables = 1
net.core.somaxconn = 32768
vm.swappiness = 0
net.ipv4.tcp_syncookies = 0
net.ipv4.ip_forward = 1
fs.file-max = 1000000
fs.inotify.max_user_watches = 1048576
fs.inotify.max_user_instances = 1024
net.ipv4.conf.all.rp_filter = 1
net.ipv4.neigh.default.gc_thresh1 = 80000
net.ipv4.neigh.default.gc_thresh2 = 90000
net.ipv4.neigh.default.gc_thresh3 = 100000
EOF
sysctl --system

# ntp

if [ ! -n "`which ntpd`" ]; then
  apt install -y ntp ntpdate ntpstat 
  sudo systemctl start ntpd.service
  sudo systemctl enable ntpd.service
  sudo systemctl status ntpd.service
fi

if [ ! -n "`which irqbalance`" ]; then
  sudo apt install -y irqbalance
  sudo systemctl enable irqbalance
  sudo systemctl start irqbalance
fi

if [ ! -n "`which cpupower`" ]; then
  sudo apt install -y linux-cpupower
  sudo cpupower frequency-set --governor performance
fi


clean_cri=`getarg clean_cri $@`
if [ "$clean_cri" != "false" ]; then
  sudo apt remove docker docker-engine docker.io containerd runc
  sudo rm -rf /etc/docker
  sudo rm -rf /var/lib/docker
  sudo find / -name *docker* | xargs sudo rm -rf
  sudo rm -rf /etc/containerd
  sudo rm -rf /var/lib/containerd
  sudo rm -rf /run/containerd
  sudo find / -name *containerd* | xargs sudo rm -rf
fi



init_containerd_mirror=`getarg init_containerd_mirror $@`
if [ "$init_containerd_mirror" != "false" ]; then
CONTAINERD_MIRRORS_SH=${TEMP:-.}/container_mirrors.sh
sudo tee $CONTAINERD_MIRRORS_SH <<-'EOF'
export PS4='\[\e[35m\]+ $(basename $0):${FUNCNAME}:$LINENO: \[\e[0m\]'
[ "$debug" == "true" -o "$debug" == "yes" ] && set -x
config_file="/etc/containerd/config.toml"
config_path='/etc/containerd/certs.d'
if [ ! -f "${config_file}" ];then
    [ ! -d "${config_file%/*}" ] && mkdir -p ${config_file%/*}
    lineno="$(containerd config default | grep -n -A 1 -P '(?<=\[plugins.")io.containerd.grpc.v1.cri(?=".registry])'|tail -1)"
    lineno=${lineno/-*}
    containerd config default | sed -e "${lineno}s@config.*@config_path = \"${config_path}\"@" |sed '/SystemdCgroup/s/false/true/' > $config_file
fi
[ ! -d "${config_path}" ] && mkdir -p ${config_path}
# https://github.com/DaoCloud/public-image-mirror
# https://github.com/kubesre/docker-registry-mirrors
crmirrorhost1=kubesre.xyz
crmirrorhost2=m.daocloud.io
params="${@:-\
cr.l5d.io:l5d.${crmirrorhost1},l5d.${crmirrorhost2} \
docker.elastic.co:elastic.${crmirrorhost1},elastic.${crmirrorhost2} \
docker.io:docker.${crmirrorhost1},docker.${crmirrorhost2} \
gcr.io:gcr.${crmirrorhost1},gcr.${crmirrorhost2} \
ghcr.io:ghcr.${crmirrorhost1},ghcr.${crmirrorhost2} \
k8s.gcr.io:k8s-gcr.${crmirrorhost1},k8s-gcr.${crmirrorhost2} \
registry.k8s.io:k8s.${crmirrorhost1},k8s.${crmirrorhost2} \
mcr.microsoft.com:mcr.${crmirrorhost1},mcr.${crmirrorhost2} \
nvcr.io:nvcr.${crmirrorhost1},nvcr.${crmirrorhost2} \
quay.io:quay.${crmirrorhost1},quay.${crmirrorhost2} \
registry.jujucharms.com:jujucharms.${crmirrorhost1},jujucharms.${crmirrorhost2} \
}"
function content(){
    # https://github.com/containerd/containerd/blob/main/docs/hosts.md
    printf 'server = "https://%s"\n'  "${registry}"
    local hosts=$(echo $proxy_server |  tr ',' ' ')
    for host in $hosts   
    do
        printf '[host."https://%s"]\n' "${host}"
        printf '  capabilities = ["pull", "resolve"]\n'
    done
}
for param in ${params}
do
    registry="${param/:*/}"
    proxy_server="${param/*:/}"
    hosts_path="$config_path/$registry"
    [ ! -d "$hosts_path" ] && mkdir -p ${hosts_path}
    content > $hosts_path/hosts.toml
done
ls $config_path
systemctl restart containerd 2>/dev/null
EOF
bash $CONTAINERD_MIRRORS_SH
rm -f $CONTAINERD_MIRRORS_SH
fi



init_docker_config=`getarg init_docker_config $@`
if [ "$init_docker_config" != "false" ]; then
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
sudo systemctl restart docker 2>/dev/null
fi

install_docker=`getarg install_docker $@`
if [ "$install_docker" != "false" ]; then
# 安装docker
if [ ! -n "`which docker`" ]; then
  curl -fsSL https://get.docker.com | bash -s docker --mirror Aliyun
  sudo systemctl start docker
  sudo systemctl enable docker
  fi
  
  if [ ! -n "`which docker-compose`" ]; then
  apt -y install docker-compose-plugin
  DOCKER_COMPOSE=$(find / -name docker-compose | grep "docker" 2>/dev/null)
  echo $DOCKER_COMPOSE
  sudo chmod 777 $DOCKER_COMPOSE
  \rm -rf /usr/bin/docker-compose
  \cp -rf $DOCKER_COMPOSE /usr/bin/docker-compose
  fi

  docker ps
fi

echo "--------------------------------------------------------------------------------------------"
echo "done"
echo "--------------------------------------------------------------------------------------------"


