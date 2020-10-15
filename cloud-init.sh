#!/bin/sh

# Function to grab SSM parameters
aws_get_parameter() {
  aws ssm --region ${REGION} get-parameter \
    --name "${PARAMETER_PATH}/$1" \
    --with-decryption \
    --output text \
    --query Parameter.Value 2>/dev/null
}

# yummy
yum update -y
wget https://bintray.com/kong/kong-rpm/rpm -O bintray-kong-kong-rpm.repo
sed -i -e 's/baseurl.*/&\/amazonlinux\/amazonlinux2'/ bintray-kong-kong-rpm.repo
mv bintray-kong-kong-rpm.repo /etc/yum.repos.d/
yum update -y
yum install -y kong-${KONG_VERSION}

# permissions

chgrp -R kong /usr/local/kong
chmod -R 770 /usr/local/kong
chown root:kong /usr/local/kong
chmod 2775 /usr/local/kong

# limits
cat <<'EOF' >> /etc/security/limits.conf
kong         hard    nofile          65536
kong         soft    nofile          65536
EOF

# Setup database vars
echo "Setting up Kong database"
PGPASSWORD=$(aws_get_parameter "db/password/master")
DB_HOST=$(aws_get_parameter "db/host")
DB_NAME=$(aws_get_parameter "db/name")
DB_PASSWORD=$(aws_get_parameter "db/password")

export PGPASSWORD

RESULT=$(psql --host $DB_HOST --username root \
    --tuples-only --no-align postgres \
    <<EOF
SELECT 1 FROM pg_roles WHERE rolname='${DB_USER}'
EOF
)

if [ $? != 0 ]; then
    echo "Error: Database connection failed, please configure manually"
    exit 1
fi

echo $RESULT | grep -q 1
if [ $? != 0 ]; then
    psql --host $DB_HOST --username root postgres <<EOF
CREATE USER ${DB_USER} WITH PASSWORD '$DB_PASSWORD';
GRANT ${DB_USER} TO root;
CREATE DATABASE $DB_NAME OWNER = ${DB_USER};
EOF
fi
unset PGPASSWORD



# Setup Configuration file
cat <<EOF > /etc/kong/kong.conf
# kong.conf, Kong configuration file
# Written by <tidwell@zebedee.io>

# Database settings
database = postgres 
pg_host = $DB_HOST
pg_user = ${DB_USER}
pg_password = $DB_PASSWORD
pg_database = $DB_NAME

# Kong Injected Headers
headers = off

# Kong Reporting
anonymous_reports = false

# Load balancer headers
real_ip_header = X-Forwarded-For
trusted_ips = 0.0.0.0/0

# SSL terminiation is performed by load balancers
proxy_listen = 0.0.0.0:8000
# For /status to load balancers
admin_listen = 0.0.0.0:8001
EOF

chmod 640 /etc/kong/kong.conf
chgrp kong /etc/kong/kong.conf

# Initialize Kong
echo "Initializing Kong"

# Log rotation
cat <<'EOF' > /etc/logrotate.d/kong
/usr/local/kong/logs/*.log {
  rotate 14
  daily
  compress
  missingok
  notifempty
  create 640 kong  kong 
  sharedscripts

  postrotate
    /usr/bin/sv 1 /etc/sv/kong
  endscript
}
EOF

# start kong
/usr/local/bin/kong migrations bootstrap [-c /etc/kong/kong.conf]
/usr/local/bin/kong migrations up
/usr/local/bin/kong migrations finish

runuser -l kong -c '/usr/local/bin/kong start [-c /etc/kong/kong.conf]'

# Verify Admin API is up
RUNNING=0
for I in 1 2 3 4 5 6 7 8 9; do
  curl -s -I http://localhost:8001/upstreams/my_upstream/targets/healthy | grep -q "200 OK"
  if [ $? = 0 ]; then
    RUNNING=1
    break
  fi
  sleep 1
done

if [ $RUNNING = 0 ]; then
  echo "Cannot connect to admin API, avoiding further configuration."
  exit 1
fi