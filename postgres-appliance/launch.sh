#!/bin/sh

if [ -f /a.tar.xz ]; then
    echo "decompressing spilo image..."
    if tar xpJf /a.tar.xz -C / > /dev/null 2>&1; then
        rm /a.tar.xz
        ln -snf dash /bin/sh
    else
        echo "failed to decompress spilo image"
        exit 1
    fi
fi

if [ "x$1" = "xinit" ]; then
    exec /usr/bin/dumb-init -c --rewrite 1:0 -- /bin/sh /launch.sh
fi

if [ -f /var/secret/azkey ]; then
  export WABS_ACCESS_KEY="$(cat /var/secret/azkey)"
  echo "export WABS_ACCESS_KEY=\"$(cat /var/secret/azkey)\"" >> ~/.bash_profile
  echo "export WABS_ACCESS_KEY=\"$(cat /var/secret/azkey)\"" >> /home/postgres/.bash_profile
else
  echo "Secret not mounted"
fi

if [ -f ~/.bash_profile ]; then
  source ~/.bash_profile
fi

mkdir -p "$PGLOG"

## Ensure all logfiles exist, most appliances will have
## a foreign data wrapper pointing to these files
for i in $(seq 0 7); do
    if [ ! -f "${PGLOG}/postgresql-$i.csv" ]; then
        touch "${PGLOG}/postgresql-$i.csv"
    fi
done
chown -R postgres:postgres "$PGROOT"

if [ "$DEMO" = "true" ]; then
    python3 /scripts/configure_spilo.py patroni patronictl pgqd certificate pam-oauth2
elif python3 /scripts/configure_spilo.py all; then
    su postgres -c "PATH=$PATH /scripts/patroni_wait.sh -t 3600 -- envdir $WALE_ENV_DIR /scripts/postgres_backup.sh $PGDATA $BACKUP_NUM_TO_RETAIN" &
fi

sv_stop() {
    sv -w 86400 stop patroni
    sv -w 86400 stop /etc/service/*
}

trap sv_stop TERM QUIT INT

/usr/bin/runsvdir -P /etc/service &

wait
