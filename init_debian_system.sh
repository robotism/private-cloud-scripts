#!/bin/bash -e

if [ -n "$(echo $REPO | grep ^http)" ]
then
source <(curl -Ls ${REPO}/env_function.sh) 
else
source ${REPO}/env_function.sh
fi

# debian

if [ ! -n "`which apt 2>/dev/null`" ]; then
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
if [ "$sources" = "restore" ]; then
  sudo \cp -rf ${DEBIAN_SOURCE}.old.bak ${DEBIAN_SOURCE} 
fi
if [ "$sources" = "debian" ]; then
  sudo \cp -rf ${DEBIAN_SOURCE}.old.bak ${DEBIAN_SOURCE}
  sudo sed -i 's|mirrors.ustc.edu.cn/debian-security|security.debian.org/debian-security|g' ${DEBIAN_SOURCE}
  sudo sed -i "s|mirrors.ustc.edu.cn|deb.debian.org|g" ${DEBIAN_SOURCE}
  sudo sed -i 's|mirrors.163.com/debian-security|security.debian.org/debian-security|g' ${DEBIAN_SOURCE}
  sudo sed -i "s|mirrors.163.com|deb.debian.org|g" ${DEBIAN_SOURCE}
  sudo sed -i 's|mirrors.tencentyun.com/debian-security|security.debian.org/debian-security|g' ${DEBIAN_SOURCE}
  sudo sed -i "s|mirrors.tencentyun.com|deb.debian.org|g" ${DEBIAN_SOURCE}
  sudo cat ${DEBIAN_SOURCE}
fi
if [ "$sources" = "ustc" ]; then
  sudo \cp -rf ${DEBIAN_SOURCE}.old.bak ${DEBIAN_SOURCE}
  sudo sed -i 's|security.debian.org/debian-security|mirrors.ustc.edu.cn/debian-security|g' ${DEBIAN_SOURCE}
  sudo sed -i "s|deb.debian.org|mirrors.ustc.edu.cn|g" ${DEBIAN_SOURCE}
  sudo sed -i 's|mirrors.163.com/debian-security|mirrors.ustc.edu.cn/debian-security|g' ${DEBIAN_SOURCE}
  sudo sed -i "s|mirrors.163.com|mirrors.ustc.edu.cn|g" ${DEBIAN_SOURCE}
  sudo sed -i 's|mirrors.tencentyun.com/debian-security|mirrors.ustc.edu.cn/debian-security|g' ${DEBIAN_SOURCE}
  sudo sed -i "s|mirrors.tencentyun.com|mirrors.ustc.edu.cn|g" ${DEBIAN_SOURCE}
  sudo cat ${DEBIAN_SOURCE}
fi
if [ "$sources" = "tencent" ]; then
  sudo \cp -rf ${DEBIAN_SOURCE}.old.bak ${DEBIAN_SOURCE}
  sudo sed -i 's|security.debian.org/debian-security|mirrors.tencentyun.com|g' ${DEBIAN_SOURCE}
  sudo sed -i "s|deb.debian.org|mirrors.tencentyun.com|g" ${DEBIAN_SOURCE}
  sudo sed -i 's|mirrors.163.com/debian-security|mirrors.tencentyun.com|g' ${DEBIAN_SOURCE}
  sudo sed -i "s|mirrors.163.com|mirrors.ustc.edu.cn|g" ${DEBIAN_SOURCE}
  sudo sed -i 's|mirrors.ustc.edu.cn/debian-security|mirrors.tencentyun.com/debian-security|g' ${DEBIAN_SOURCE}
  sudo sed -i "s|mirrors.ustc.edu.cn|mirrors.tencentyun.com|g" ${DEBIAN_SOURCE}
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

if [ ! -f "/usr/bin/dnf" ];then
  sudo apt install -y dnf
fi

if [ ! -n "`which snapd 2>/dev/null`" ]; then

    sudo apt -y install snapd

    sudo systemctl enable --now snapd.socket
    sudo systemctl enable snapd
    sudo systemctl start snapd

    if [ ! -n "`cat ~/.profile | grep snap`"]; then
    echo ""
    echo 'export PATH=$PATH:/snap/bin' >> ~/.profile
    echo ""
    fi

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

if [ ! -n "`which ntpd 2>/dev/null`" ]; then
  apt install -y ntp ntpdate ntpstat 
  sudo systemctl start ntpd.service
  sudo systemctl enable ntpd.service
  sudo systemctl status ntpd.service
fi

if [ ! -n "`which irqbalance 2>/dev/null`" ]; then
  sudo apt install -y irqbalance
  sudo systemctl enable irqbalance
  sudo systemctl start irqbalance
fi

if [ ! -n "`which cpupower 2>/dev/null`" ]; then
  sudo apt install -y linux-cpupower
  sudo cpupower frequency-set --governor performance
fi


clean_cri=`getarg clean_cri $@`
if [ "$clean_cri" == "true" ]; then
  sudo apt remove docker docker-engine docker.io containerd runc 2>/dev/null
  sudo rm -rf /etc/docker
  sudo rm -rf /var/lib/docker
  sudo find / -name *docker* | xargs sudo rm -rf
  sudo rm -rf /etc/containerd
  sudo rm -rf /var/lib/containerd
  sudo rm -rf /run/containerd
  sudo find / -name *containerd* | xargs sudo rm -rf
fi



echo "--------------------------------------------------------------------------------------------"
echo "done"
echo "--------------------------------------------------------------------------------------------"


