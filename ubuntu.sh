# Ubuntu 14.04

# hostname
HOSTNAME=hostname
sudo sed -i "s/127.0.1.1\t`hostname`/127.0.1.1\t$HOSTNAME/" /etc/hosts
echo $HOSTNAME | sudo tee /etc/hostname
sudo hostname $HOSTNAME
bash

# new user
USER=ubuntu
sudo useradd -d /home/$USER -m $USER -g users -s /bin/bash
echo "$USER ALL=(ALL:ALL) NOPASSWD: ALL" | sudo tee -a /etc/sudoers
su - $USER
mkdir .ssh && chmod 700 .ssh
echo "ssh-rsa AAAAAAAAAAA" >> ~/.ssh/authorized_keys

# ssh
sudo rm -rf /etc/ssh/ssh_host_*
sudo dpkg-reconfigure openssh-server
sudo sed -ie 's/Port.*[0-9]$/Port 9922/gI' /etc/ssh/sshd_config
sudo sed -ie 's/#ListenAddress 0.0.0.0$/ListenAddress 0.0.0.0/gI' /etc/ssh/sshd_config
sudo sed -ie 's/PermitRootLogin\s*yes\s*$/PermitRootLogin no/gI' /etc/ssh/sshd_config
sudo sed -ie 's/#PasswordAuthentication yes$/PasswordAuthentication no/gI' /etc/ssh/sshd_config
sudo restart ssh

# motd
sudo rm /etc/motd
echo "Welcome to my server" | sudo tee /etc/motd

# timezone
echo "UTC" | sudo tee /etc/timezone
sudo dpkg-reconfigure --frontend noninteractive tzdata

# ntp
sudo apt-get install ntp -y
echo "NTPD_OPTS='-4 -g'" | sudo tee /etc/default/ntp
sudo sed -ie 's/restrict -6/#restrict -6/gI' /etc/ntp.conf
sudo sed -ie 's/restrict ::1/#restrict ::1/gI' /etc/ntp.conf
sudo service ntp restart

# swap
sudo fallocate -l 4G /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
echo " /swapfile       none    swap    sw      0       0" | sudo tee -a /etc/fstab
echo vm.swappiness = 10 | sudo tee -a /etc/sysctl.conf
sudo sysctl -p
sudo chown root:root /swapfile 
sudo chmod 0600 /swapfile

# disable ipv6
echo "net.ipv6.conf.all.disable_ipv6 = 1" | sudo tee -a /etc/sysctl.conf
echo "net.ipv6.conf.default.disable_ipv6 = 1" | sudo tee -a /etc/sysctl.conf
echo "net.ipv6.conf.lo.disable_ipv6 = 1" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p

# todo: ulimits

# update
sudo sed -i "s/us\.archive\.ubuntu/mirrors.digitalocean/g" /etc/apt/sources.list
sudo apt-get update
sudo apt-get dist-upgrade -y
sudo apt-get autoremove -y

# misc utilities
sudo apt-get install screen tmux htop unzip git -y

# firewall
sudo apt-get install iptables-persistent -y
sudo iptables -I INPUT 1 -i lo -j ACCEPT
sudo iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
sudo iptables -A INPUT -p icmp --icmp-type 8 -s 0/0 -d 1.2.3.4 -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 9922 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 1234 -s 1.2.3.4 -j ACCEPT
sudo iptables -A INPUT -j REJECT
sudo iptables-save > /etc/iptables/rules.v4

# node.js source install
sudo apt-get -y install g++ curl pkg-config libv4l-dev libjpeg-dev build-essential libssl-dev cmake git-core
curl https://raw.githubusercontent.com/creationix/nvm/master/install.sh | bash
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
curl -s http://download.mono-project.com/repo/xamarin.gpg | sudo apt-key add -
echo "deb http://download.mono-project.com/repo/debian wheezy main" | sudo tee /etc/apt/sources.list.d/xamarin.list
sudo apt-get update
sudo apt-get -y install mono-complete
sudo mozroots --import --sync --machine
echo "y\n\y\n" | sudo certmgr -ssl -m https://nuget.org

# pypy & python modules
sudo apt-get install python-software-properties software-properties-common -y -f
sudo add-apt-repository ppa:pypy/ppa -y
sudo apt-get update
sudo apt-get install pypy -y
sudo apt-get install python-pip python-dev build-essential -y
sudo pip install boto configobj --upgrade 
sudo apt-get install libmysqlclient-dev python-dev -y
sudo pip install mysql-python --upgrade

# docker
curl -s https://get.docker.io/ubuntu/ | sudo sh
