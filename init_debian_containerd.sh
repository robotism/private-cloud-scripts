#/bin/bash -e

if [ -n "$(echo $REPO | grep ^http)" ]
then
source <(curl -Ls ${REPO}/env_function.sh) 
else
source ${REPO}/env_function.sh
fi

export crmirrorhost1=`getarg mirror1 $@`
export crmirrorhost2=`getarg mirror2 $@`

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
# crmirrorhost1=kubesre.xyz
# crmirrorhost2=m.daocloud.io
crmirrorhost1=${crmirrorhost1:-noproxy.top}
crmirrorhost2=${crmirrorhost2:-kubesre.xyz}

# [INFO] 别名仓库列表如下:
# [INFO] 原仓库: cr.l5d.io 别名仓库:l5d.noproxy.top
# [INFO] 原仓库: docker.elastic.co 别名仓库:elastic.noproxy.top
# [INFO] 原仓库: docker.io 别名仓库:docker.noproxy.top
# [INFO] 原仓库: gcr.io 别名仓库:gcr.noproxy.top
# [INFO] 原仓库: ghcr.io 别名仓库:ghcr.noproxy.top
# [INFO] 原仓库: k8s.gcr.io 别名仓库:k8s-gcr.noproxy.top
# [INFO] 原仓库: registry.k8s.io 别名仓库:k8s.noproxy.top
# [INFO] 原仓库: mcr.microsoft.com 别名仓库:mcr.noproxy.top
# [INFO] 原仓库: nvcr.io 别名仓库:nvcr.noproxy.top
# [INFO] 原仓库: quay.io 别名仓库:quay.noproxy.top
# [INFO] 原仓库: registry.jujucharms.com 别名仓库:jujucharms.noproxy.top
# [INFO] 原仓库: rocks.canonical.com 别名仓库:rocks-canonical.noproxy.top
# [INFO]
# [INFO] 代码仓库: https://github.com/kubesre/docker-registry-mirrors

p0arams="${@:-\
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



echo "--------------------------------------------------------------------------------------------"
echo "done"
echo "--------------------------------------------------------------------------------------------"


