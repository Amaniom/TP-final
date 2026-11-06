#!/bin/bash
# Projet final - prerequis + E8.1 + E1 + E2 sur srv-core
# a lancer en root : bash ~/projet-e8-e1-e2.sh 2>&1 | tee ~/sortie-projet.txt
# (pas de set -e : on veut voir toutes les sorties meme si un test echoue)

W=/srv/helios/suivi/www
t() { echo; echo "### $*"; eval "$@"; echo "[rc=$?]"; }

echo "===== $(hostname) - $(date '+%F %T') ====="

echo; echo "################ PREREQUIS ################"
t systemctl is-active helios-collect.service
t ls -l /var/lib/helios/telemetry.csv
t systemctl cat helios.target
t firewall-cmd --get-default-zone
t firewall-cmd --get-active-zones
t "sshd -T | grep -E '^(port|allowgroups|passwordauthentication|permitrootlogin) '"
t systemctl is-active helios-watch-auth.timer

echo; echo "################ E8.1 agent zabbix ################"
# pas de depot EPEL sur ce srv-core -> exclusion seulement si le fichier existe
if [ -f /etc/yum.repos.d/epel.repo ]; then
  grep -q '^excludepkgs=zabbix' /etc/yum.repos.d/epel.repo || sed -i '/^\[epel\]/a excludepkgs=zabbix*' /etc/yum.repos.d/epel.repo
else
  echo "pas de /etc/yum.repos.d/epel.repo -> exclusion EPEL sans objet"
fi
rpm -q zabbix-release || rpm -Uvh https://repo.zabbix.com/zabbix/7.0/rocky/9/x86_64/zabbix-release-latest-7.0.el9.noarch.rpm
dnf clean all
dnf -y install zabbix-agent2 zabbix-get sysstat
systemctl enable --now zabbix-agent2 sysstat.service sysstat-collect.timer sysstat-summary.timer
t rpm -q zabbix-agent2 zabbix-get sysstat
t getent passwd zabbix
t "grep -E '^(Server|ServerActive)=' /etc/zabbix/zabbix_agent2.conf"
t "systemctl is-active zabbix-agent2; systemctl is-enabled zabbix-agent2"
t "systemctl is-active sysstat-collect.timer; systemctl is-enabled sysstat-collect.timer"
sleep 2
t zabbix_get -s 127.0.0.1 -k agent.ping

echo; echo "################ E1 comptes ################"
getent group suivi >/dev/null || groupadd -g 5003 suivi
# uid 5104 deja pris par sysops (TP3) -> lea en 5105, ecart signale dans le rapport
if ! id lea >/dev/null 2>&1; then
  if getent passwd 5104 >/dev/null; then LEA_UID=5105; else LEA_UID=5104; fi
  useradd -u $LEA_UID -g suivi -c "Lea Fabre - responsable suivi des tournees" -m -s /bin/bash lea
  echo 'lea:Helios-Suivi-2026' | chpasswd
fi
chage -M 90 -m 1 -W 14 -I 7 lea
if ! id helios-suivi >/dev/null 2>&1; then
  useradd -r -d /srv/helios/suivi -M -s /sbin/nologin -c "Service portail suivi" helios-suivi
fi
t getent group suivi
t getent passwd 5104
t id lea
t getent passwd lea
t chage -l lea
t "id -nG lea | grep -wE 'wheel|ssh-admins' || echo 'lea ni wheel ni ssh-admins'"
t id helios-suivi
t getent passwd helios-suivi
t "ls -ld /home/helios-suivi 2>&1"

echo; echo "################ E2 setgid + ACL ################"
mkdir -p $W
chown root:suivi /srv/helios/suivi && chmod 0750 /srv/helios/suivi
setfacl -m u:helios-suivi:r-x,u:zabbix:--x /srv/helios/suivi
chown root:suivi $W && chmod 2770 $W
setfacl -m u:helios-suivi:rwx,u:zabbix:--x,o::--- $W
setfacl -d -m u::rwx,g::rwx,u:helios-suivi:rwx,o::--- $W
t ls -ld /srv/helios /srv/helios/suivi $W
t getfacl -p /srv/helios/suivi
t getfacl -p $W

# E2.5 index.html depose par lea (umask 077 force pour prouver E2.4)
su - lea -c "umask 077; echo '<h1>Portail de suivi des tournees Helios</h1><p>Page deposee par Lea Fabre.</p>' > $W/index.html"
t ls -l $W/index.html
t getfacl -p $W/index.html
t "runuser -u helios-suivi -- cat $W/index.html"
t "runuser -u nadia -- cat $W/index.html"
t "runuser -u zabbix -- ls $W"
t "runuser -u zabbix -- stat -c '%n %U:%G %a' $W/index.html"
t "ausearch -m AVC -ts recent 2>&1 | tail -5"

echo; echo "===== fin $(date '+%F %T') ====="
