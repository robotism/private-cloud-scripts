#!/bin/bash -e

if [ -n "$(echo $REPO | grep ^http)" ]
then
source <(curl -Ls ${REPO}/env_function.sh) 
else
source ${REPO}/env_function.sh
fi

domains=`getarg domains $@`
domains=$(echo $domains | tr ',' ' ')
domain=$(echo $domains | tr " " "\n" | grep -v "\*" | sed -n 1p) 

dns=`getarg dns $@`
dnssleep=`getarg dnssleep $@`
apikey=`getarg apikey $@`
apisecret=`getarg apisecret $@`

if [ ! -n "$domains" ]; then
echo 'missing domains => xx.xx,*.xx.xx,xx1.xx '
exit 0
fi

if [ ! -n "$dns" ]; then
echo 'missing dns provider => Ali_Keydns_ali / dns_dp '
exit 0
fi

if [ ! -n "$apikey" ]; then
echo 'missing apikey => Ali_Secret="xxx" / DP_Key="xxxx"'
exit 0
fi

if [ ! -n "$apisecret" ]; then
echo "missing apisecret"
exit 0
fi

if [ ! -n "$domain" ]; then
echo 'missing main domain => set a xx.xx as main domain'
exit 0
fi

email=`getarg email $@`
email=${email:-"webadmin@${domain}"}
server=`getarg server $@`
server=${server:-"zerossl"}  # [zerossl,letsencrypt]
output=`getarg output $@`
output=${output:-"$(pwd)/acme.sh"}

daemon=`getarg daemon $@`
daemon=${daemon:-true}

CONTAINER_NAME=acme
docker rm -f $CONTAINER_NAME 2>/dev/null

if [ "$daemon" = "true" ]; then
docker run --rm -itd \
  -v ${output}:/acme.sh \
  -e $apikey \
  -e $apisecret \
  --name=${CONTAINER_NAME} \
  neilpang/acme.sh daemon
CMD=" docker exec ${CONTAINER_NAME} "
fi

if [ "$daemon" != "true" ]; then
CMD=" \
docker run --rm -it \
  -v ${output}:/acme.sh \
  -e $apikey \
  -e $apisecret \
  --name=${CONTAINER_NAME} \
  neilpang/acme.sh \
"
fi

CMD="$CMD\
  --register-account -m $email \
  --server $server \
  --set-default-ca \
  --issue --force --debug \
  --dns ${dns} \
  --dnssleep ${dnssleep:-30} \
"

for d in $domains   
do  
CMD="$CMD -d $d "
done  

echo "eval $CMD"
eval $CMD

echo "----------------------------------------"
echo "done! output dir: ${output}"
echo "----------------------------------------"
