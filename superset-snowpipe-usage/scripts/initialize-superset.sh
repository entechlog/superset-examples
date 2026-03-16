#!/bin/sh
# ---------------------------------------------------------------------------
# initialize-superset.sh – helper that bootstraps Superset 
# (admin user, db upgrade, init, import assets)
# ---------------------------------------------------------------------------

# give Superset container a few seconds to start accepting exec commands
sleep 5

cd /usr/src/

# Read the secret key from the file (now mounted in openssh-client container)
SECRET_KEY=$(cat /usr/src/configs/superset_key)

echo "===> Create superset admin user"
sleep 1
docker exec --tty -it -e SUPERSET_SECRET_KEY="$SECRET_KEY" apache-superset superset fab create-admin \
  --username admin \
  --firstname Superset \
  --lastname Admin \
  --email admin@superset.com \
  --password admin

echo "===> Migrate Superset metadata DB to latest"
sleep 1
docker exec --tty -it -e SUPERSET_SECRET_KEY="$SECRET_KEY" apache-superset superset db upgrade

echo "===> Initialise Superset roles & perms"
sleep 1
docker exec --tty -it -e SUPERSET_SECRET_KEY="$SECRET_KEY" apache-superset superset init

echo "===> Finished running startup scripts – have fun with Superset!"
sleep 1