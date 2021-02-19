#!/usr/bin/bash -ex

source /etc/environment
status_log=/var/log/sandbox/status.log

setenforce 0

mkdir /opt/sandbox
mkdir /var/log/sandbox
ln -s /var/log/cloud-init.log /var/log/sandbox/cloud-init-output.log
echo "$(date +"%T %Z"): 1/7 The control site is being deployed ... " > $status_log
chown -R apache:centos /var/log/sandbox
chmod 664 /var/log/sandbox/*.log
touch /var/log/ansible.log
chown centos:apache /var/log/ansible.log
ln -s /var/log/ansible.log /var/log/sandbox/ansible.log
curl -s "$BUCKET_URI"/tungsten_fabric_sandbox.tar.gz -o /tmp/tungsten_fabric_sandbox.tar.gz
tar -xzf /tmp/tungsten_fabric_sandbox.tar.gz -C /tmp
curl -s "https://raw.githubusercontent.com/TheAshwanik/tungsten_sandbox/main/deploy_tf.sh" -o /tmp/sandbox/scripts/modified_deploy_tf.sh
mv /tmp/sandbox/scripts/modified_deploy_tf.sh /tmp/sandbox/scripts/deploy_tf.sh
chmod +x /tmp/sandbox/scripts/*
cp -r /tmp/sandbox/site /var/www/html/sandbox
cp -r /tmp/sandbox/scripts /opt/sandbox/scripts
cp -f /tmp/sandbox/templates/ssl.conf /etc/httpd/conf.d/ssl.conf
ln -s /var/log/sandbox/ /var/www/html/sandbox/debug/logs
chown centos /var/www/html/sandbox/dns /var/www/html/sandbox/stage /var/www/html/sandbox/wp_pass
chown apache:apache /var/www/html/sandbox/upload/ /var/www/html/sandbox/settings.json
usermod -aG apache centos
chmod 664 /var/www/html/sandbox/settings.json
echo "SetEnv AWS_REG ${AWS_DEFAULT_REGION}" >> /var/www/html/sandbox/.htaccess
echo "SetEnv AWS_USERKEY ${AWS_USERKEY}" >> /var/www/html/sandbox/.htaccess
htpasswd -bc /etc/httpd/.htpasswd admin "$1"
service httpd restart
yum -y install epel-release
yum -y install python-pip git unzip python-urllib3 python-boto pystache python-daemon jq moreutils python-paramiko python2-cryptography sshpass
rpm -i https://releases.ansible.com/ansible/rpm/release/epel-7-x86_64/ansible-2.7.18-1.el7.ans.noarch.rpm
curl -s "https://s3.amazonaws.com/aws-cli/awscli-bundle.zip" -o "/tmp/awscli-bundle.zip"
unzip /tmp/awscli-bundle.zip -d/tmp
/tmp/awscli-bundle/install -i /usr/local/aws -b /usr/bin/aws

echo "apache ALL=(ALL) NOPASSWD:SETENV: /opt/sandbox/scripts/*.sh" > /etc/sudoers.d/777-sandbox
# workaround(epel dependencies broken )
sudo -H -u centos sudo pip install boto3
sudo -H -u centos /opt/sandbox/scripts/deploy_tf.sh &>> /var/log/sandbox/deployment.log || { echo 99 > /var/www/html/sandbox/stage; curl -s "$BUCKET_URI"/failed-installation.htm; } >> /var/log/sandbox/deployment.log
