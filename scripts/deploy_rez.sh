mkdir -p /opt/rez/current
python -m pip install rez==3.5.0     --target /opt/rez/3.5.0
ln -sfn /opt/rez/3.3.0 /opt/rez/current
export REZ_ROOT=/opt/rez/current
export PATH=$PATH;/opt/rez/current
export REZ_CONFIG_FILE=/mnt/packages/.config/linux_rezconfig.py
rez-search python-3