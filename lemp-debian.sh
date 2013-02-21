#!/bin/bash
function pause(){
   read -p "$*"
}

function check_root() {
	if [ ! "`whoami`" = "root" ]
	then
	    echo "Root previlege required to run this script. Rerun as root."
	    exit 1
	fi
}
check_root

if [ `cat /etc/issue|awk 'NR==1 {print $1}'` != "Ubuntu" ];then
cat > /etc/apt/sources.list.d/dotdeb.list <<END
deb http://packages.dotdeb.org stable all
deb-src http://packages.dotdeb.org stable all
END
wget http://www.dotdeb.org/dotdeb.gpg
cat dotdeb.gpg | apt-key add -
rm dotdeb.gpg
fi
apt-get update && apt-get upgrade
apt-get remove apache2*

apt-get install nginx mysql-server php5 php5-mysql sqlite3 php5-sqlite php5-curl php-pear php5-dev libcurl4-openssl-dev php5-gd php5-imagick php5-imap php5-mcrypt php5-xmlrpc php5-xsl php5-suhosin php5-fpm libpcre3-dev build-essential php-apc

cat > /etc/php5/conf.d/apc.ini <<END
extension=apc.so
apc.enabled=1
apc.shm_size=30M
END

service mysql stop
service nginx stop
service php5-fpm stop

cat > /etc/my.cnf <<END
[client]
port		= 3306
socket		= /var/run/mysqld/mysqld.sock

[mysqld_safe]
socket		= /var/run/mysqld/mysqld.sock
nice		= 0

[mysqld]
user		= mysql
pid-file	= /var/run/mysqld/mysqld.pid
socket		= /var/run/mysqld/mysqld.sock
port		= 3306
basedir		= /usr
datadir		= /var/lib/mysql
tmpdir		= /tmp
lc-messages-dir	= /usr/share/mysql
skip-external-locking
bind-address		= 127.0.0.1
default-storage-engine = myisam
key_buffer = 1M
query_cache_size = 1M
query_cache_limit = 128k
max_connections=25
thread_cache=1
skip-innodb
query_cache_min_res_unit=0
tmp_table_size = 1M
max_heap_table_size = 1M
table_cache=256
concurrent_insert=2 
max_allowed_packet = 1M
sort_buffer_size = 64K
read_buffer_size = 256K
read_rnd_buffer_size = 256K
net_buffer_length = 2K
thread_stack = 64K
expire_logs_days	= 10
max_binlog_size         = 100M
[mysqldump]
quick
quote-names
max_allowed_packet	= 16M
[mysql]
[isamchk]
key_buffer		= 16M
!includedir /etc/mysql/conf.d/
END

cat > /etc/nginx/php <<END
index index.php;
 
        location = /favicon.ico {
                log_not_found off;
                access_log off;
        }
 
        location = /robots.txt {
                allow all;
                log_not_found off;
                access_log off;
        }
 
        location / {
                # This is cool because no php is touched for static content
                try_files \$uri \$uri/ /index.php?q=\$uri&\$args;
        }
 
        location ~ \.php\$ {
                #NOTE: You should have "cgi.fix_pathinfo = 0;" in php.ini
                include fastcgi_params;
        	fastcgi_intercept_errors on;
    		fastcgi_index index.php;
    		fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
    		try_files \$uri =404;
    		fastcgi_pass unix:/var/run/php5-fpm.sock;
    		error_page 404 /404page.html; 
        }
 
        location ~* \.(js|css|png|jpg|jpeg|gif|ico)\$ {
                expires max;
                log_not_found off;
        }
END

cat > /etc/nginx/nginx.conf <<END
user www-data;
worker_processes 1;
pid /var/run/nginx.pid;

events {
	worker_connections 2048;
	# multi_accept on;
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
	access_log /var/log/nginx/access.log;
	error_log /var/log/nginx/error.log;
	gzip on;
	gzip_disable "msie6";
	gzip_proxied any;
	gzip_comp_level 2;
	gzip_types text/plain text/css application/json application/x-javascript text/xml application/xml application/xml+rss text/javascript;
	include /etc/nginx/conf.d/*.conf;
	include /etc/nginx/sites-enabled/*;
} 
END

cat > /etc/nginx/sites-available/default <<END
server {
    listen 80 default;
    server_name _;
    root /var/www/;
    include php;
} 
END


#install php-fpm config
cat > /etc/php5/fpm/pool.d/www.conf <<END
[www]
user = www-data
group = www-data
listen = /var/run/php5-fpm.sock
pm = ondemand
pm.max_children = 5
pm.start_servers = 1
pm.min_spare_servers = 1
pm.max_spare_servers = 1
pm.process_idle_timeout = 3s;
pm.max_requests = 500
chdir = /var/www/
env[HOSTNAME] = \$HOSTNAME
php_admin_value[upload_max_filesize] = 32M
END

echo -n "Install PHPMyAdmin?[y/n][n]:"
read pma_install
if [ "$pma_install" == "y" ];then
	echo Installing PhpMyAdmin
	echo Don\'t select any options and select no to configure with dbcommon.
	pause 'Press [Enter] key to continue after reading the above line ...'
	apt-get install phpmyadmin
	echo -n "Domain for PHPMyAdmin Web Interface? Example:pma.domain.com :"
	read pma_url
	cat > /etc/nginx/sites-available/$pma_url.conf <<END
server {
    server_name $pma_url;
    root /usr/share/phpmyadmin;
    include php;
    access_log  /var/log/nginx/$pma_url-access.log;
    error_log  /var/log/nginx/$pma_url-error.log;
  
}
END
	ln -s /etc/nginx/sites-available/$pma_url.conf /etc/nginx/sites-enabled/$pma_url.conf
else
	echo Skipping PhpMyAdmin Installation
fi

mkdir /var/www
chown -R www-data:www-data /var/www
mkdir /var/log/nginx
sed -i 's/cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/g' /etc/php5/fpm/php.ini
sed -i 's/#cgi.fix_pathinfo=0/cgi.fix_pathinfo=0/g' /etc/php5/fpm/php.ini
service php5-fpm start
service nginx restart
service mysql start

wget https://raw.github.com/aatishnn/lempstack/master/setup-vhost.sh -O /bin/setup-vhost
chmod 755 /bin/setup-vhost

echo Installation done.
echo Use setup-vhost to configure virtual hosts.
echo Running mysql_secure_installation. Use root password if set during install time.
pause 'Press [Enter] key to continue after reading the above line ...'
mysql_secure_installation
exit
