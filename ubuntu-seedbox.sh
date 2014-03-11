# Outdated: 2011-10-21

apt-get update
apt-get -y dist-upgrade
apt-get --purge -y remove apache2 apache2-doc apache2-mpm-prefork apache2-utils apache2.2-bin apache2.2-common
apt-get --purge -y remove bind9 bind9utils 
apt-get --purge -y remove fontconfig fontconfig-config gcc-4.5-base 
apt-get --purge -y remove samba samba-common samba-common-bin 
apt-get --purge -y remove sendmail sendmail-base sendmail-bin sendmail-cf sendmail-doc
apt-get --purge -y remove xinetd logrotate sysklogd klogd
apt-get --purge -y autoremove
apt-get -y install nano

ln -sf /usr/share/zoneinfo/Europe/Rome /etc/localtime

useradd -d /home/user -m user -g users -s /bin/bash
passwd user
echo "user ALL=(ALL) ALL" >> /etc/sudoers

sed -ie 's/Port.*[0-9]$/Port 9922/gI' /etc/ssh/sshd_config
sed -ie 's/PermitRootLogin\s*yes\s*$/PermitRootLogin no/gI' /etc/ssh/sshd_config
restart ssh

iptables -I INPUT 1 -i lo -j ACCEPT
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A INPUT -p tcp --dport 9922 -j ACCEPT
iptables -A INPUT -p tcp --dport 443 -j ACCEPT
iptables -A INPUT -p tcp --dport 9999 -j ACCEPT
iptables -A INPUT -j DROP

echo "pre-up iptables-restore < /etc/iptables.rules" >> /etc/network/interfaces.tail
echo "post-down iptables-save > /etc/iptables.rules" >> /etc/network/interfaces.tail

sudo apt-get -y install build-essential

export X_BUILD=/home/user/build
export X_PREFIX=/usr/local

sudo apt-get -y install build-essential zlib1g-dev
mkdir -p $X_BUILD/openssl && cd $X_BUILD/openssl
export OPENSSL_VERSION_TARBALL=openssl-SNAP-`date +%Y%m%d`
wget ftp://ftp.openssl.org/snapshot/$OPENSSL_VERSION_TARBALL.tar.gz
tar xf $OPENSSL_VERSION_TARBALL.tar.gz
rm -f openssl && ln -s $OPENSSL_VERSION_TARBALL openssl
cd $OPENSSL_VERSION_TARBALL
./Configure

sudo apt-get -y install libpcre3-dev zlib1g-dev libgeoip-dev
mkdir -p $X_BUILD/nginx && cd $X_BUILD/nginx
export NGINX_VERSION=1.0.8
wget http://nginx.org/download/nginx-$NGINX_VERSION.tar.gz
tar xf nginx-$NGINX_VERSION.tar.gz
cd nginx-$NGINX_VERSION
./configure \
	--prefix=/usr/local \
	--sbin-path=/usr/local/sbin/nginx \
	--conf-path=/etc/nginx/nginx.conf \
	--error-log-path=/var/log/nginx/error.log \
	--http-client-body-temp-path=/var/lib/nginx/body \
	--http-fastcgi-temp-path=/var/lib/nginx/fastcgi \
	--http-log-path=/var/log/nginx/access.log \
	--http-proxy-temp-path=/var/lib/nginx/proxy \
	--http-scgi-temp-path=/var/lib/nginx/scgi \
	--http-uwsgi-temp-path=/var/lib/nginx/uwsgi \
	--lock-path=/var/lock/nginx.lock \
	--pid-path=/var/run/nginx.pid \
	--with-http_addition_module \
	--with-http_geoip_module \
	--with-http_gzip_static_module \
	--with-http_realip_module \
	--with-http_stub_status_module \
	--with-http_ssl_module \
	--with-http_sub_module \
	--with-openssl=$X_BUILD/openssl
make
sudo make install

sudo usermod www-data -s /bin/false
sudo mkdir -p /var/www
sudo mkdir -p /var/lib/nginx

sudo nano /etc/init.d/nginx
#!/bin/sh

### BEGIN INIT INFO
# Provides:          nginx
# Required-Start:    $local_fs $remote_fs $network $syslog
# Required-Stop:     $local_fs $remote_fs $network $syslog
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: starts the nginx web server
# Description:       starts nginx using start-stop-daemon
### END INIT INFO

PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
DAEMON=/usr/local/sbin/nginx
NAME=nginx
DESC=nginx

# Include nginx defaults if available
if [ -f /etc/default/nginx ]; then
        . /etc/default/nginx
fi

test -x $DAEMON || exit 0

set -e

. /lib/lsb/init-functions

test_nginx_config() {
        if $DAEMON -t $DAEMON_OPTS >/dev/null 2>&1; then
                return 0
        else
                $DAEMON -t $DAEMON_OPTS
                return $?
        fi
}

case "$1" in
        start)
                echo -n "Starting $DESC: "
                test_nginx_config
                # Check if the ULIMIT is set in /etc/default/nginx
                if [ -n "$ULIMIT" ]; then
                        # Set the ulimits
                        ulimit $ULIMIT
                fi
                start-stop-daemon --start --quiet --pidfile /var/run/$NAME.pid \
                    --exec $DAEMON -- $DAEMON_OPTS || true
                echo "$NAME."
                ;;

        stop)
                echo -n "Stopping $DESC: "
                start-stop-daemon --stop --quiet --pidfile /var/run/$NAME.pid \
                    --exec $DAEMON || true
                echo "$NAME."
                ;;

        restart|force-reload)
                echo -n "Restarting $DESC: "
                start-stop-daemon --stop --quiet --pidfile \
                    /var/run/$NAME.pid --exec $DAEMON || true
                sleep 1
                test_nginx_config
                start-stop-daemon --start --quiet --pidfile \
                    /var/run/$NAME.pid --exec $DAEMON -- $DAEMON_OPTS || true
                echo "$NAME."
                ;;

        reload)
                echo -n "Reloading $DESC configuration: "
                test_nginx_config
                start-stop-daemon --stop --signal HUP --quiet --pidfile /var/run/$NAME.pid \
                    --exec $DAEMON || true
                echo "$NAME."
                ;;

        configtest|testconfig)
                echo -n "Testing $DESC configuration: "
                if test_nginx_config; then
                        echo "$NAME."
                else
                        exit $?
                fi
                ;;

        status)
                status_of_proc -p /var/run/$NAME.pid "$DAEMON" nginx && exit 0 || exit $?
                ;;
        *)
                echo "Usage: $NAME {start|stop|restart|reload|force-reload|status|configtest}" >&2
                exit 1
                ;;
esac

exit 0
sudo chmod +x /etc/init.d/nginx
sudo update-rc.d nginx defaults

sudo mkdir -p /etc/nginx/ssl/
cd /etc/nginx/ssl/
sudo openssl genrsa -des3 -out server.key 4096
sudo openssl req -new -key server.key -out server.csr
sudo cp server.key server.key.org
sudo openssl rsa -in server.key.org -out server.key
sudo openssl x509 -req -days 1825 -in server.csr -signkey server.key -out server.crt

sudo nano /etc/nginx/nginx.conf
user www-data;
worker_processes 1;
pid /var/run/nginx.pid;

events {
	worker_connections 1024;
}

http {
	sendfile on;
	tcp_nopush on;
	tcp_nodelay on;
	keepalive_timeout 65;
	types_hash_max_size 2048;
	server_tokens off;

	include /etc/nginx/mime.types;
	default_type application/octet-stream;

	access_log off;
	error_log /var/log/nginx/error.log crit;

	server {
		listen 443;
		server_name _;
		
		root /var/www;
		index index.html index.htm;
		autoindex on;

		allow 127.0.0.1;
		allow 172.30.3.120; # unicity
		allow 46.137.176.127; # self
		allow 46.18.27.4; # unibz
		deny all;

		ssl                       on;
		ssl_ciphers               AES256-SHA;
		ssl_prefer_server_ciphers on;
		ssl_certificate           /etc/nginx/ssl/server.crt;
		ssl_certificate_key       /etc/nginx/ssl/server.key;
		ssl_protocols             TLSv1;
		
		location /gui {
			proxy_pass http://localhost:8080/gui;
		}
	}
}

sudo mkdir -p /opt/utorrent
sudo chown user /opt/utorrent
cd /opt/utorrent
wget http://download.utorrent.com/linux/utorrent-server-3.0-25053.tar.gz
tar xf utorrent-server-3.0-25053.tar.gz
cd utorrent-server-v3_0/
# http://forum.utorrent.com/viewtopic.php?id=58156
wget "https://sites.google.com/site/ultimasites/files/utorrent-webui.2011090319521148.zip?attredirects=0" -o utorrent-webui.2011090319521148.zip
mv webui.zip webui.zip.orig
ln -s utorrent-webui.2011090319521148.zip webui.zip

sudo nano /etc/init.d/utorrent
sudo chmod +x /etc/init.d/utorrent
sudo /etc/init.d/utorrent start

ps aux
netstat -an