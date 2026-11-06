#!/bin/bash
# Projet final - E3 : installation + tests du script de publication (en root)
S=/usr/local/sbin/helios-suivi-publish.sh
W=/srv/helios/suivi/www
t() { echo; echo "### $*"; eval "$@"; echo "[rc=$?]"; }
echo "===== E3 $(hostname) - $(date '+%F %T') ====="
install -o root -g root -m 0755 ~admin_trake/helios-suivi-publish.sh $S
# helios-suivi doit traverser /var/lib/helios (750 helios:helios) pour lire telemetry.csv : ACL ajoutee, rien retire
setfacl -m u:helios-suivi:--x /var/lib/helios
t ls -l $S
t getfacl -p /var/lib/helios
t tail -n 1 /var/lib/helios/telemetry.csv
echo; echo "--- code 0 : lance en helios-suivi ---"
t runuser -u helios-suivi -- $S
t ls -l $W/etat.json
t getfacl -p $W/etat.json
t python3 -m json.tool $W/etat.json
echo; echo "--- code 2 : une autre instance tient le verrou ---"
runuser -u helios-suivi -- flock -n $S sleep 5 &
sleep 1
t runuser -u helios-suivi -- $S
wait
echo; echo "--- code 3 : lance par nadia (www non inscriptible / telemetrie illisible) ---"
t runuser -u nadia -- $S
echo; echo "--- ecriture atomique : pas de fichier temporaire qui traine ---"
t "ls -la $W"
t runuser -u zabbix -- stat -c "'%n %s %y'" $W/etat.json
t journalctl -t helios-suivi-publish -n 10 --no-pager
t "ausearch -m AVC -ts recent 2>&1 | tail -3"
echo "===== fin $(date '+%F %T') ====="
