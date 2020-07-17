#!/bin/bash
echo -n "domen: "
read DOMEN
echo -n "IP: "
read IP
echo -n "you login: "
read LOGIN
echo -n "CF email: "
read cfmail
echo -n "CF token: "
read cftok
mailhost=mail.$DOMEN
hostnamectl set-hostname $mailhost
phpfpmcfg=/etc/php-fpm.d/$LOGIN.conf
eximcfg=/etc/exim/exim.conf
nginxmailcfg=/etc/nginx/conf.d/$mailhost.conf
nginxmailadmincfg=/etc/nginx/conf.d/$mailhost.conf
nginxpostfixadmincfg=/etc/nginx/conf.d/admin.$DOMEN.conf
echo "$IP $mailhost" >> /etc/hosts 
yum -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
yum -y install https://rpms.remirepo.net/enterprise/remi-release-7.rpm
yum-config-manager --enable remi-php74
yum update -y
yum install mariadb-server mariadb python2-certbot-dns-cloudflare certbot yum-utils dovecot dovecot-mysql unzip exim exim-mysql jq php-fpm php-mysql php-imap php-mbstring php-common php-pdo php-xml -y
mkdir -p /etc/letsencrypt/
mkdir /var/vmail
mkdir /etc/exim/dkim
mkdir /var/www/$LOGIN/tmp -p
chown exim:exim -R /var/vmail/
chown -R exim:exim /var/spool/exim/
wget -P /etc/yum.repos.d/ https://raw.githubusercontent.com/rlavrinenko/mail/master/nginx/nginx.repo
yum install nginx
wget -P /etc/exim/ https://raw.githubusercontent.com/rlavrinenko/mail/master/exim/exim.conf
wget -P /var/www/$LOGIN/ https://sourceforge.net/projects/postfixadmin/files/postfixadmin/postfixadmin-3.2/postfixadmin-3.2.4.tar.gz
mkdir /var/www/$LOGIN/mail
wget -P /var/www/$LOGIN/mail http://www.rainloop.net/repository/webmail/rainloop-latest.zip
cd /var/www/$LOGIN/ 
tar zxvf postfixadmin-3.2.4.tar.gz
mv postfixadmin-3.2.4 mailadmin
cd /var/www/$LOGIN/mail
unzip rainloop-latest.zip
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

chown $LOGIN:$LOGIN -R /var/www/$LOGIN/	
sed -e s/mailhostname/$mailhost/ $eximcfg
sed -e s/maildomen/$DOMEN/ $eximcfg
SYMBOLS=""
for symbol in {A..Z} {a..z} {0..9}; do SYMBOLS=$SYMBOLS$symbol; done
PWD_LENGTH=16  
PASSWORD=""    
RANDOM=256     
for i in `seq 1 $PWD_LENGTH`
do
MAILPASS=$PASSWORD${SYMBOLS:$(expr $RANDOM % ${#SYMBOLS}):1}
done
sed -e s/DBpass/$MAILPASS $eximcfg

systemctl restart nginx
systemctl enable nginx
systemctl start dovecot
systemctl enable dovecot
systemctl enable exim
systemctl start exim
		