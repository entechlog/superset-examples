#!/bin/sh
#
cd /usr/src/
#
echo "===> Create superset user"
sleep 1
docker exec --tty -it apache-superset superset fab create-admin --username admin --firstname Superset --lastname Admin --email admin@superset.com --password admin
#
echo "===> Migrate superset local DB to latest"
sleep 1
docker exec --tty -it apache-superset superset db upgrade
#
echo "===> Setup superset roles"
sleep 1
docker exec --tty -it apache-superset superset init
#
echo "===> Import Data Sources"
sleep 1
docker exec --tty -it apache-superset superset import_datasources -r -p /usr/src/configs/datasources
#
echo "===> Import Dashbaords"
sleep 1
docker exec --tty -it apache-superset superset import-dashboards -r -p /usr/src/configs/dashboards
#
echo "===> Finished Running the startup scripts !!! Have fun with Superset !!!"
sleep 1
#