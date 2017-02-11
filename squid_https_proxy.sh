echo "Go to home directory..."
cd ~

echo "Please type the domain name to use for certification request:"
read domain_name
echo "Please type the your certification contact email address(used for certification release/renew/expiry notification etc): "
read email_address
echo "Please type the proxy user name:"
read proxy_user
echo "Please type the proxy user password:"
read proxy_password

echo "Insatll Squid3 and Utilities..."

apt-get -qq update
apt-get -qq install apache2-utils vim wget software-properties-common -y
add-apt-repository ppa:brightbox/squid-ssl -y
apt-get -qq update
apt-get -qq install squid3-ssl -y

echo "Download EFF certbot..."
wget -O certbot-auto https://dl.eff.org/certbot-auto
chmod a+x certbot-auto

echo "Run EFF certbot to get a Free Letsencrypt certification..."
./certbot-auto certonly -n --standalone --agree-tos -d $domain_name -m $email_address --quiet --no-self-upgrade
if [ $? -ne 0 ]; then
  echo "Certification fetch failed!"
  exit
fi

echo "Generate Squid Password..."
touch /etc/squid3/passwords
htpasswd -b /etc/squid3/passwords $proxy_user $proxy_password

echo "Copy Squid3 Configuration file..."
cat > /etc/squid3/squid.conf << END
acl SSL_ports port 443
acl Safe_ports port 80		# http
acl Safe_ports port 21		# ftp
acl Safe_ports port 443		# https
acl Safe_ports port 70		# gopher
acl Safe_ports port 210		# wais
acl Safe_ports port 1025-65535	# unregistered ports
acl Safe_ports port 280		# http-mgmt
acl Safe_ports port 488		# gss-http
acl Safe_ports port 591		# filemaker
acl Safe_ports port 777		# multiling http
acl CONNECT method CONNECT
http_access deny !Safe_ports
http_access deny CONNECT !SSL_ports

auth_param basic program /usr/lib/squid3/basic_ncsa_auth /etc/squid3/passwords
auth_param basic realm proxy
acl authenticated proxy_auth REQUIRED

via off
forwarded_for off
request_header_access X-Forwarded-For deny all

http_access allow authenticated
http_access deny all

https_port 111 cert=/etc/letsencrypt/live/$domain_name/fullchain.pem key=/etc/letsencrypt/live/$domain_name/privkey.pem

access_log none
cache_log none
END

echo "Restart Squid3..."
echo "Setup Done!"