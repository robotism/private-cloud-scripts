#/bin/bash -e

[ "$debug" == "true" -o "$debug" == "yes" ] && set -x

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
apt -y update
apt -y upgrade
apt -y autoremove
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

# init tools


if [ ! -f "/usr/bin/git" ];then
  apt install -y git
fi

if [ ! -f "/usr/sbin/ifconfig" ];then
  apt install -y net-tools
fi

if [ ! -f "/usr/bin/nslookup" ];then
  apt install -y dnsutils
fi

if [ ! -f "/usr/bin/wget" ];then
  apt install -y wget
fi

if [ ! -f "/usr/bin/curl" ];then
  apt install -y curl
fi

if [ ! -f "/usr/bin/vim" ];then
  apt install -y vim
fi




# swap off
if [ ! -n "`cat /etc/sysctl.conf | grep 'vm.swappiness' | grep '0'`" ]; then
echo "vm.swappiness = 0">> /etc/sysctl.conf
swapoff -a && swapon -a
sysctl -p
fi


# firewalld off
sudo systemctl stop firewalld.service
sudo systemctl disable firewalld.service
sudo systemctl status firewalld.service

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


# ntp

if [ ! -n "`which ntpd`" ]; then
apt install -y ntp ntpdate ntpstat 
sudo systemctl start ntpd.service
sudo systemctl enable ntpd.service
sudo systemctl status ntpd.service
fi


init_containerd_config=`getarg init_docker_config $@`
if [ "$init_containerd_config" != "false" ]; then
export PS4='\[\e[35m\]+ $(basename $0):${FUNCNAME}:$LINENO: \[\e[0m\]'
 
config_file="/etc/containerd/config.toml"
config_path='/etc/containerd/certs.d'
 
if [ ! -f "${config_file}" ];then
    [ ! -d "${config_file%/*}" ] && mkdir -p ${config_file%/*}
    lineno="$(containerd config default | grep -n -A 1 -P '(?<=\[plugins.")io.containerd.grpc.v1.cri(?=".registry])'|tail -1)"
    lineno=${lineno/-*}
    containerd config default | sed -e "${lineno}s@config.*@config_path = \"${config_path}\"@" |sed '/SystemdCgroup/s/false/true/' > $config_file
fi
 
[ ! -d "${config_path}" ] && mkdir -p ${config_path}
params="${@:-registry.k8s.io:k8s.m.daocloud.io docker.io:docker.m.daocloud.io gcr.io:gcr.m.daocloud.io k8s.gcr.io:k8s.m.daocloud.io quay.io:quay.m.daocloud.io}"
 
function content(){
    printf 'server = "https://%s"\n'  "${registry}"
    printf '[host."https://%s"]\n' "${proxy_server}"
    printf '  capabilities = ["pull", "resolve"]'
}
 
for param in ${params}
do
    registry="${param/:*/}"
    proxy_server="${param/*:/}"
    hosts_path="$config_path/$registry"
    [ ! -d "$hosts_path" ] && mkdir -p ${hosts_path}
    content > $hosts_path/hosts.toml
done
systemctl restart containerd
fi



init_docker_config=`getarg init_docker_config $@`
if [ "$init_docker_config" != "false" ]; then
sudo mkdir -p /etc/docker
sudo tee /etc/docker/daemon.json <<-'EOF'
{
    "registry-mirrors": [
        "https://1nj0zren.mirror.aliyuncs.com",
        "https://mirror.ccs.tencentyun.com",
        "https://docker.mirrors.ustc.edu.cn",
        "http://f1361db2.m.daocloud.io",
        "https://registry.docker-cn.com"
    ],
    "log-driver": "json-file",
    "log-opts": {"max-size":"16m", "max-file":"1"}
}
EOF
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


