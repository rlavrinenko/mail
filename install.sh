#!/bin/bash
echo -n "domen: "
read DOMEN
echo -n "IP: "
read IP
echo -n "CF email: "
read cfmail
echo -n "CF token: "
read cftok
hostnamectl set-hostname mail.$DOMEN
mhost=mail.$DOMEN
echo "$IP mail.$DOMEN" >> /etc/hosts 
yum -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
yum -y install https://rpms.remirepo.net/enterprise/remi-release-7.rpm
yum install mariadb-server mariadb python2-certbot-dns-cloudflare certbot yum-utils dovecot dovecot-mysql exim exim-mysql jq
yum-config-manager --enable remi-php74
yum update
mkdir -p /etc/letsencrypt/
mkdir /var/vmail
mkdir /etc/exim/dkim
chown exim:exim -R /var/vmail/
chown -R exim:exim /var/spool/exim/
wget -P /etc/yum.repos.d/ ЛИНК
yum install nginx
wget -P /etc/conf.d/
systemctl restart nginx
systemctl enable nginx
systemctl start dovecot
systemctl enable dovecot
systemctl enable exim
systemctl start exim
openssl genrsa -out /etc/exim/dkim/$DOMEN.key 2048
openssl rsa -in /etc/exim/dkim/$DOMEN.key -pubout > /etc/exim/dkim/$DOMEN.pub
echo "dns_cloudflare_email =$cfmail" > /etc/letsencrypt/cloudflareapi.cfg
echo "dns_cloudflare_api_key =$cftok" >>/etc/letsencrypt/cloudflareapi.cfg
certbot certonly --cert-name $DOMEN --dns-cloudflare --dns-cloudflare-credentials /etc/letsencrypt/cloudflareapi.cfg --server https://acme-v02.api.letsencrypt.org/directory -d "*.$DOMEN" -d $DOMEN
#Опередлить если есть   (Thanks Tras2 https://gist.github.com/Tras2 )
zoneid=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=$zone&status=active" \
  -H "X-Auth-Email: $cfmail" \
  -H "X-Auth-Key: $cftok" \
  -H "Content-Type: application/json" | jq -r '{"result"}[] | .[0] | .id')
# Определить ИД записи
recordid=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$zoneid/dns_records?type=A&name=mail.$DOMEN" \
  -H "X-Auth-Email: $cfmail" \
  -H "X-Auth-Key: $cftok" \
  -H "Content-Type: application/json" | jq -r '{"result"}[] | .[0] | .id')
# Удалить запись
curl -X DELETE "https://api.cloudflare.com/client/v4/zones/$zoneid/dns_records/$recordid" \
     -H "X-Auth-Email: $cfmail" \
     -H "X-Auth-Key: $cftok" \
     -H "Content-Type: application/json" | jq
# Добавить
curl -X POST "https://api.cloudflare.com/client/v4/zones/$zoneid/dns_records/" \
        -H "X-Auth-Email: $cfmail" \
        -H "X-Auth-Key: $cftok" \
        -H "Content-Type: application/json" \
        --data "{\"type\":\"A\",\"name\":\"mail.$DOMEN\",\"content\":\"$IP\",\"ttl\":1,\"proxied\":false}" | jq
		