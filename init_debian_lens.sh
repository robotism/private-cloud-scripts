

DATA=${DATA:-/opt/data}

# install lens ------------------------
# https://k8slens.dev/download
if [ ! -f "${DATA}/Lens/Lens.AppImage" ]; then 
mkdir -p ${DATA}/Lens
wget -t 0 -c https://downloads.k8slens.dev/ide/Lens-2024.10.171859-latest.x86_64.AppImage -O ${DATA}/Lens/Lens.AppImage
chmod u+x  ${DATA}/Lens/Lens.AppImage
fi

if [ ! -f "./Lens.desktop" ]; then
LENS_LAUNCHEWR="
[Desktop Entry]
Version=1.0
Type=Application
Name=Lens
Comment=Lens - The way the world runs Kubernetes
Exec= ${DATA}/Lens/Lens.AppImage --no-sandbox %U
Icon=lens-desktop
Path=
Terminal=false
StartupNotify=false
"
sudo echo "$LENS_LAUNCHEWR" > ./Lens.desktop
sudo chmod u+x ./Lens.desktop
fi

echo "---------------------------------------------"
echo "done"
echo "---------------------------------------------"

