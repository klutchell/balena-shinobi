#!/bin/sh
set -e

if [ ! -f /config/conf.json ]
then
    echo "Creating conf.json ..."
    cp /opt/shinobi/conf.sample.json /config/conf.json
    jq '.cron.key = $val' --arg val "$(head -c 64 < /dev/urandom | sha256sum | awk '{print substr($1,1,60)}')" /config/conf.json > /tmp/$$.json && mv /tmp/$$.json /config/conf.json
fi

rm /opt/shinobi/conf.json 2>/dev/null || true
ln -s /config/conf.json /opt/shinobi/conf.json

if [ ! -f /config/super.json ]
then
    echo "Creating super.json ..."
    cp /opt/shinobi/super.sample.json /opt/shinobi/super.json
fi

rm /opt/shinobi/super.json 2>/dev/null || true
ln -s /config/super.json /opt/shinobi/super.json

echo "Updating configuration ..."

ADMIN_EMAIL="${ADMIN_EMAIL:-admin@shinobi.video}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-admin}"
ADMIN_PASSWORD_MD5="$(echo -n "${ADMIN_PASSWORD}" | md5sum | sed -e 's/  -$//')"

MYSQL_HOST="${MYSQL_HOST:-mariadb}"
MYSQL_USER="${MYSQL_USER:-shinobi}"
MYSQL_PASSWORD="${MYSQL_PASSWORD:-}"
MYSQL_DATABASE="ccio"
MYSQL_PORT=3306

# MYSQL_JSON="{host: ${MYSQL_HOST},user:${MYSQL_USER},password:${MYSQL_PASSWORD},database:${MYSQL_DATABASE},port:${MYSQL_PORT}}"
# jq '.db = $val' --arg val "${MYSQL_JSON}" /config/conf.json > /tmp/$$.json && mv /tmp/$$.json /config/conf.json

# https://gitlab.com/Shinobi-Systems/Shinobi/-/blob/master/libs/health.js
# CUSTOM_CPU_COMMAND="top -b -n 2 | awk '{IGNORECASE = 1} /^.?Cpu/ {gsub(\"id,\",\"100\",\$8); gsub(\"%\",\"\",\$8); print 100-\$8}' | tail -n 1"
# jq '.customCpuCommand = $val' --arg val "${CUSTOM_CPU_COMMAND}" /config/conf.json > /tmp/$$.json && mv /tmp/$$.json /config/conf.json

# workaround: paste this into the config via super console
# "customCpuCommand": "top -b -n 2 | awk '{IGNORECASE = 1} /^.?Cpu/ {gsub(\"id,\",\"100\",$8); gsub(\"%\",\"\",$8); print 100-$8}' | tail -n 1",

jq '.[0].mail = $val' --arg val "${ADMIN_EMAIL}" /config/super.json > /tmp/$$.json && mv /tmp/$$.json /config/super.json
jq '.[0].pass = $val' --arg val "${ADMIN_PASSWORD_MD5}" /config/super.json > /tmp/$$.json && mv /tmp/$$.json /config/super.json

jq '.db.host = $val' --arg val "${MYSQL_HOST}" /config/conf.json > /tmp/$$.json && mv /tmp/$$.json /config/conf.json
jq '.db.user = $val' --arg val "${MYSQL_USER}" /config/conf.json > /tmp/$$.json && mv /tmp/$$.json /config/conf.json
jq '.db.password = $val' --arg val "${MYSQL_PASSWORD}" /config/conf.json > /tmp/$$.json && mv /tmp/$$.json /config/conf.json
jq '.db.database = $val' --arg val "${MYSQL_DATABASE}" /config/conf.json > /tmp/$$.json && mv /tmp/$$.json /config/conf.json
jq '.db.port = $val' --arg val "${MYSQL_PORT}" /config/conf.json > /tmp/$$.json && mv /tmp/$$.json /config/conf.json

# TODO: backup/restore plugin configurations

while ! mysqladmin ping -h"${MYSQL_HOST}" 2>/dev/null
do
    echo "Waiting for connection to mysql server ${MYSQL_HOST} ..."
    sleep 5
done

echo "Initializing database ..."

cat > /opt/shinobi/sql/user.sql <<EOSQL
CREATE USER '${MYSQL_USER}'@'%' IDENTIFIED BY '${MYSQL_PASSWORD}' ;
GRANT ALL PRIVILEGES ON ccio.* TO '${MYSQL_USER}'@'%' ;
FLUSH PRIVILEGES ;
EOSQL

mysql -u root -p"${MYSQL_ROOT_PASSWORD}" -h"${MYSQL_HOST}" -e "source /opt/shinobi/sql/user.sql" || true
mysql -u root -p"${MYSQL_ROOT_PASSWORD}" -h"${MYSQL_HOST}" -e "source /opt/shinobi/sql/framework.sql" || true

for uuid in $(blkid -tLABEL=VIDEOS -sUUID -ovalue)
do
    echo "Mounting ${uuid} ..."
    mkdir /media/${uuid} 2>/dev/null || true
    mount UUID=${uuid} /media/${uuid}
done

echo "Starting Shinobi ..."
exec "$@"
