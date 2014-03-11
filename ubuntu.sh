# Ubuntu 13.10

# new user
sudo useradd -d /home/ubuntu -m ubuntu -g users -s /bin/bash
echo "ubuntu ALL=(ALL:ALL) NOPASSWD: ALL" | sudo tee -a /etc/sudoers
su - ubuntu
mkdir .ssh && chmod 700 .ssh
echo "ssh-rsa AAAAAAAAAAA" >> ~/.ssh/authorized_keys

# ssh
sudo sed -ie 's/Port.*[0-9]$/Port 9922/gI' /etc/ssh/sshd_config
sudo sed -ie 's/#ListenAddress 0.0.0.0$/ListenAddress 0.0.0.0/gI' /etc/ssh/sshd_config
sudo sed -ie 's/PermitRootLogin\s*yes\s*$/PermitRootLogin no/gI' /etc/ssh/sshd_config
sudo sed -ie 's/#PasswordAuthentication yes$/PasswordAuthentication no/gI' /etc/ssh/sshd_config
sudo restart ssh

# motd
sudo rm /etc/motd
echo "Welcome to" | sudo tee /etc/motd

# timezone
echo "UTC" | sudo tee /etc/timezone
sudo dpkg-reconfigure --frontend noninteractive tzdata

# swap
sudo fallocate -l 4G /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
echo " /swapfile       none    swap    sw      0       0" | sudo tee -a /etc/fstab
echo vm.swappiness = 10 | sudo tee -a /etc/sysctl.conf
sudo sysctl -p
sudo chown root:root /swapfile 
sudo chmod 0600 /swapfile

# update
sudo apt-get update
sudo apt-get dist-upgrade -y
sudo apt-get autoremove -y

# misc utilities
sudo apt-get install screen tmux htop unzip -y

# firewall
apt-get install iptables-persistent -y
sudo iptables -I INPUT 1 -i lo -j ACCEPT
sudo iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
sudo iptables -A INPUT -p icmp --icmp-type 8 -s 0/0 -d 1.2.3.4 -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 9922 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 1234 -s 1.2.3.4 -j ACCEPT
sudo iptables -A INPUT -j REJECT
sudo iptables-save > /etc/iptables/rules.v4

# node.js source install
sudo apt-get install g++ curl pkg-config libv4l-dev libjpeg-dev build-essential libssl-dev vim cmake git-core
curl https://raw.github.com/creationix/nvm/master/install.sh | sh
source ~/.profile
nvm install -s 0.10
npm update npm -g
nvm install -s 0.11
npm update npm -g

# nginx
sudo add-apt-repository ppa:nginx/development -y # stable
sudo apt-get update 
sudo apt-get install nginx -y

# mysql
sudo add-apt-repository ppa:ondrej/mysql-5.6 -y
sudo apt-get update 
sudo apt-get install mysql-server -y
sudo mysqladmin -u root password XXXXXXX

# php5
sudo add-apt-repository ppa:ondrej/php5 -y
sudo apt-get update 
sudo apt-get install php5-fpm php5-cli php5-mysql php5-xcache -y

# mono
sudo apt-get install build-essential autoconf automake libtool zlib1g-dev pkg-config gettext -y
wget http://download.mono-project.com/sources/mono/mono-3.2.8.tar.bz2
tar xf  mono-3.2.8.tar.bz2
cd mono-3.2.8
./autogen.sh --prefix=/usr/local
make -j4
sudo make install
rm -rf mono-3.2.8*

# pypy & python modules
sudo apt-get install python-software-properties software-properties-common -y -f
sudo add-apt-repository ppa:pypy/ppa -y
sudo apt-get update
sudo apt-get install pypy -y
sudo apt-get install python-pip python-dev build-essential -y
sudo pip install boto configobj --upgrade 
sudo apt-get install libmysqlclient-dev python-dev -y
sudo pip install mysql-python --upgrade
