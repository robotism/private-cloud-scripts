# 

if [ ! -n "`which snapd`" ]; then

    if [ -n "`which yum`" ]; then
    sudo yum -y update
    sudo yum -y install snapd
    fi

    if [ -n "`which apt`" ]; then
    sudo apt -y update
    sudo apt -y install snapd
    fi

fi


sudo systemctl enable --now snapd.socket
sudo systemctl enable snapd
sudo systemctl start snapd


if [ ! -n "`cat ~/.profile | grep snap`"]; then
echo ""
echo 'export PATH=$PATH:/snap/bin' >> ~/.profile
echo ""
fi