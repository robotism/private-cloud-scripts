
if [ -n "$(echo $REPO | grep ^http)" ]
then
source <(curl -Ls ${REPO}/env_function.sh) 
else
source ${REPO}/env_function.sh
fi

export crmirrorhost1=`getarg mirror1 $@`
export crmirrorhost2=`getarg mirror2 $@`

DOMAIN1=${crmirrorhost1:-kubesre.xyz}
DOMAIN2=${crmirrorhost2:-kubesre.xyz}

mkdir -p /etc/rancher/k3s/
k3s_mirrors_config="/etc/rancher/k3s/registries.yaml"

rm -rf ${k3s_mirrors_config}
cat << EOF >> ${k3s_mirrors_config}
mirrors:
  cr.l5d.io:
    endpoint:
      - https://l5d.${DOMAIN1}
      - https://l5d.${DOMAIN2}
  docker.elastic.co:
    endpoint:
      - https://elastic.${DOMAIN1}
      - https://elastic.${DOMAIN2}
  registry-1.docker.io:
    endpoint:
      - https://dhub.${DOMAIN1}
      - https://dhub.${DOMAIN2}
  docker.io:
    endpoint:
      - https://dhub.${DOMAIN1}
      - https://dhub.${DOMAIN2}
  gcr.io:
    endpoint:
      - https://gcr.${DOMAIN1}
      - https://gcr.${DOMAIN2}
  ghcr.io:
    endpoint:
      - https://ghcr.${DOMAIN1}
      - https://ghcr.${DOMAIN2}
  k8s.gcr.io:
    endpoint:
      - https://k8s-gcr.${DOMAIN1}
      - https://k8s-gcr.${DOMAIN2}
  registry.k8s.io:
    endpoint:
      - https://k8s.${DOMAIN1}
      - https://k8s.${DOMAIN2}
  mcr.microsoft.com:
    endpoint:
      - https://mcr.${DOMAIN1}
      - https://mcr.${DOMAIN2}
  nvcr.io:
    endpoint:
      - https://nvcr.${DOMAIN1}
      - https://nvcr.${DOMAIN2}
  quay.io:
    endpoint:
      - quay://nvcr.${DOMAIN1}
      - quay://nvcr.${DOMAIN2}
  registry.jujucharms.com:
    endpoint:
      - quay://jujucharms.${DOMAIN1}
      - quay://jujucharms.${DOMAIN2}
EOF
cat ${k3s_mirrors_config}

# systemctl restart k3s 2>/dev/null
# systemctl restart k3s-agent 2>/dev/null



# ansible all -m raw -a "mkdir -p /etc/rancher/k3s/"
# ansible all -m raw -a "rm -rf ${k3s_mirrors_config}"
# ansible all -m copy -a "src=$(pwd)/registries.yaml dest=${k3s_mirrors_config}"
# ansible all -m raw -a "cat ${k3s_mirrors_config}"

# ansible all -m systemd -a "name=k3s state=restarted"
# ansible all -m systemd -a "name=k3s-agent state=restarted"