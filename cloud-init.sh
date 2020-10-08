#!/bin/sh

# Function to grab SSM parameters
aws_get_parameter() {
    aws ssm --region ${REGION} get-parameter \
        --name "${PARAMETER_PATH}/$1" \
        --with-decryption \
        --output text \
        --query Parameter.Value 2>/dev/null
}

# Setup database
echo "Setting up Kong database"
PGPASSWORD=$(aws_get_parameter "db/password/master")
DB_HOST=$(aws_get_parameter "db/host")
DB_NAME=$(aws_get_parameter "db/name")
DB_PASSWORD=$(aws_get_parameter "db/password")
export PGPASSWORD


# Setup Configuration file
cat <<EOF > /etc/kong/kong.conf
# kong.conf, Kong configuration file
# Written by <tidwell@zebedee.io>
#

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


chmod 744 /etc/sv/kong/run /etc/sv/kong/log/run
chown root:kong /usr/local/kong
chmod 2775 /usr/local/kong

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
  create 640 kong kong
  sharedscripts

  postrotate
    /usr/bin/sv 1 /etc/sv/kong
  endscript
}
EOF

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