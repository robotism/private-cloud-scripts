#!/bin/bash -e

if [ -n "$(echo $REPO | grep ^http)" ]
then
source <(curl -Ls ${REPO}/env_function.sh) 
else
source ${REPO}/env_function.sh
fi



if [ ! -n "`which sshpass 2>/dev/null`" ]; then
eval apt install -y sshpass
fi

if [ ! -n "`which ansible 2>/dev/null`" ]; then
eval apt install -y ansible
fi

ips=`getarg ips $@`
ips=$(echo $ips |  tr ',' ' ')
hostname=`getarg hostname $@`
password=`getarg password $@`
release=`getrelease`

if [ ! -n "${ips}" ]; then
echo "missing ips"
exit 0
fi

if [ ! -n "${password}" ]; then
echo "missing password"
exit 0
fi

echo "------- ssh key gen ---------"
idx=0
for ip in $ips   
do  
  idx=`expr $idx + 1`
  hst=${hostname:-${release:-node}}-${idx}
  sshpass -p ${password} ssh -o stricthostkeychecking=no root@${ip} "hostnamectl set-hostname $hst"
  sshpass -p ${password} ssh -o stricthostkeychecking=no root@${ip} "echo -e '#\n127.0.0.1 localhost $hst\n#\n' >> /etc/hosts"
  sshpass -p ${password} ssh -o stricthostkeychecking=no root@${ip} 'rm -rf ~/.ssh/id_rsa'
  sshpass -p ${password} ssh -o stricthostkeychecking=no root@${ip} 'ssh-keygen -t rsa -f ~/.ssh/id_rsa -N "" -C "ansible cluster"'
  echo "------- ssh key gen $hst $ip"
done  

echo "------- ssh copy id ---------"
for ip in $ips   
do  
  sshpass -p ${password} ssh-copy-id -o stricthostkeychecking=no root@${ip}
done  


echo "------- reset ansible cfg ---------"
mkdir -p /etc/ansible/

if [ ! -f "/etc/ansible/ansible.cfg" ]; then
echo "[defaults]" > /etc/ansible/ansible.cfg
echo "host_key_checking = False" >> /etc/ansible/ansible.cfg
echo "vars_plugins_enabled = host_group_vars" >> /etc/ansible/ansible.cfg
echo "[vars_host_group_vars]" >> /etc/ansible/ansible.cfg
echo "stage = inventory" >> /etc/ansible/ansible.cfg
cat /etc/ansible/ansible.cfg
fi

echo "------- reset ansible hosts --------"
echo "[hosts]" > /etc/ansible/hosts
for ip in $ips   
do  
echo "$ip ansible_ssh_user='root' ansible_ssh_pass='${password}' " >> /etc/ansible/hosts
done  
echo "" >> /etc/ansible/hosts
cat /etc/ansible/hosts

echo "------------  print test ------------"
ansible all -m command -a "uname -a"



echo "---------------------------------------------"
echo "done"
echo "---------------------------------------------"

