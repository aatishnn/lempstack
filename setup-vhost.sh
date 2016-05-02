#!/bin/bash
function check_root() {
        if [ ! "`whoami`" = "root" ]
        then
            echo "Root previlege required to run this script. Rerun as root."
            exit 1
        fi
}

check_root

if [ -z "$1" ];then
        echo "Usage: setup-vhost <username> <hostname> (Without the www. prefix)"
        exit
fi


adduser $1

mkdir "/home/$1/www/"
chown -R $1:$1 "/home/$1/www/"

cat > "/etc/nginx/sites-available/$2.conf" <<END
server{
    listen 80;
    listen [::]:80;
    server_name $2;

    # Redirect all HTTP requests to HTTPS with a 301 Moved Permanently response.
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl spdy;
    listen [::]:443 ssl spdy;

    # certs sent to the client in SERVER HELLO are concatenated in ssl_certificate
    ssl_certificate /etc/letsencrypt/live/$2/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$2/privkey.pem;
    ssl_session_timeout 1d;
    ssl_session_cache shared:SSL:50m;
    ssl_session_tickets off;

    # Diffie-Hellman parameter for DHE ciphersuites - openssl dhparam -out /etc/ssl/certs/dhparam.pem 4096
    ssl_dhparam /etc/ssl/certs/dhparam.pem;

    # modern configuration. tweak to your needs.
    ssl_protocols TLSv1.2;

    # taken from https://mozilla.github.io/server-side-tls/ssl-config-generator/
    ssl_ciphers 'ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA384:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA256';
#    ssl_ciphers "HIGH:!eNULL:!aNULL:!SHA1:!AES128";

    ssl_prefer_server_ciphers on;

    # HSTS (ngx_http_headers_module is required) (15768000 seconds = 6 months)
#    add_header Strict-Transport-Security max-age=15768000;
    # taken from https://cipherli.st/
    add_header Strict-Transport-Security "max-age=63072000; includeSubdomains; preload";

    # OCSP Stapling ---
    # fetch OCSP records from URL in ssl_certificate and cache them
    ssl_stapling on;
    ssl_stapling_verify on;

    ## verify chain of trust of OCSP response using Root CA and Intermediate certs
#    ssl_trusted_certificate /path/to/root_CA_cert_plus_intermediates;

    resolver 8.8.8.8 8.8.4.4 valid=300s;
    resolver_timeout 5s;

    ssl_ecdh_curve secp384r1;

    add_header X-Frame-Options DENY;
    add_header X-Content-Type-Options nosniff;



    server_name $2;
    root /home/$1/www/;
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
                fastcgi_pass unix:/var/run/php5-fpm-$1.sock;
                error_page 404 /404page.html;
        }

        location ~* \.(js|css|png|jpg|jpeg|gif|ico)\$ {
                expires max;
                log_not_found off;
        }

    access_log  /var/log/nginx/$2-access.log;
    error_log  /var/log/nginx/$2-error.log;
}
END

cat > /etc/php5/fpm/pool.d/$1.conf <<END
[$1]
listen = /var/run/php5-fpm-$1.sock
user = $1
group = $1
listen.owner = www-data
listen.group = www-data
listen.mode = 0666
pm = dynamic
pm.max_children = 5
pm.start_servers = 3
pm.min_spare_servers = 2
pm.max_spare_servers = 4
pm.max_requests = 200
listen.backlog = -1
request_terminate_timeout = 120s
rlimit_files = 131072
rlimit_core = unlimited
catch_workers_output = yes
env[HOSTNAME] = \$HOSTNAME
env[TMP] = /tmp
env[TMPDIR] = /tmp
env[TEMP] = /tmp
END

ln -s /etc/nginx/sites-available/$2.conf /etc/nginx/sites-enabled/$2.conf

service nginx reload
service php5-fpm restart

echo Virtual Host Created. Upload Files to /home/$1/www .
echo -n "Create MySQL database for user?[y/n][n]:"
read mysql_db_create
if [ "$mysql_db_create" == "y" ];then
        echo -n "MySQL Root Password: "
        read mysql_root_password
        echo -n "MySQL Username: "
        read mysql_user
        echo -n "Password: "
        read mysql_password
        echo -n "MySQL Database Name: "
        read mysql_db_name
        mysql -u root -p"$mysql_root_password" mysql -e "CREATE DATABASE $mysql_db_name; GRANT ALL ON  $mysql_db_name.* TO $mysql_user@localhost IDENTIFIED BY '$mysql_password';FLUSH PRIVILEGES;"
        echo Database Created.
        echo -n "Import SQL File to this database?[y/n][n]:"
        read mysql_import_sql
        if [ "$mysql_import_sql" == "y" ];then
                echo -n "SQL File (Absolute Path)?:"
                read mysql_import_location
                mysql -u root -p"$mysql_root_password" "$mysql_db_name" < "$mysql_import_location";
        fi
fi
