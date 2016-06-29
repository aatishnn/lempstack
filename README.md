## Introduction
This repository hosts a setup script that simplies the installation of LEMP stack suitable for Debian Jessie environments. It is a fork of https://github.com/aatishnn/lempstack.

Any questions or issues? Feel free to open an issue or suggest new features.

Read more over at the original author's blog:
http://linuxdo.blogspot.com/2012/08/optimized-lemp-installer-for.html

## What has changed
* modified for Debian 8 Jessie
* updated configuration
* removed unnecessary packages
* changed [php-suhosin](https://suhosin.org) installation to not use dotdeb.org
* enabled OPcache
* added IPv6
* added SPDY (will be changed to http2 as soon as a fitting nginx is available in the stable repo)
* added TLS via letsencrypt (installs certbot, automates renewal, adds new certificate at virtual host creation)
* creation of (bigger) dhparam.pem

## Quick Install
Run these commands as root:

1. add `deb http://ftp.debian.org/debian jessie-backports main` to your `sources.list` or ` /etc/apt/sources.list.d/backports.list` for [certbot](https://certbot.eff.org/#debianjessie-nginx)
2. `wget https://github.com/mdPlusPlus/lempstack/raw/master/lemp-debian.sh`
3. `chmod +x lemp-debian.sh`
4. `wget https://github.com/mdPlusPlus/lempstack/raw/master/setup-vhost.sh`
5. `chmod +x setup-vhost.sh`
6. `./lemp-debian.sh`
7. `./setup-vhost.sh`
