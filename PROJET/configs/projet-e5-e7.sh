#!/bin/bash
# Projet final - E5 (sudo) + E7 (non-regression) - en root
t() { echo; echo "### $*"; eval "$@"; echo "[rc=$?]"; }
echo "===== E5/E7 $(hostname) - $(date '+%F %T') ====="
echo; echo "################ E5 ################"
t visudo -cf ~admin_trake/92-helios-suivi
if visudo -cf ~admin_trake/92-helios-suivi >/dev/null; then
  install -o root -g root -m 0440 ~admin_trake/92-helios-suivi /etc/sudoers.d/92-helios-suivi
fi
t ls -l /etc/sudoers.d/92-helios-suivi
t visudo -c
t sudo -l -U lea
t sudo -l -U lea /usr/bin/systemctl restart sshd
t sudo -l -U lea /usr/bin/systemctl restart helios-suivi.service
t sudo -l -U lea /usr/bin/journalctl -u helios-suivi.service -n 100 --no-pager
t sudo -l -U lea /usr/bin/journalctl --vacuum-time=1s
t sudo -l -U lea /usr/bin/journalctl -u helios-suivi.service -n 100 --no-pager --vacuum-time=1s
echo; echo "--- essai reel en lea ---"
t "su - lea -c \"echo 'Helios-Suivi-2026' | sudo -S -p '' /usr/bin/journalctl -u helios-suivi-publish.service -n 100 --no-pager\""
t "su - lea -c \"echo 'Helios-Suivi-2026' | sudo -S -p '' /usr/bin/systemctl restart sshd\""
echo; echo "################ E7 ################"
t "sshd -T | grep -E '^(port|permitrootlogin|passwordauthentication|allowgroups) '"
t "journalctl -u sshd --since '-15min' --no-pager | grep -i lea"
t systemctl is-active helios-watch-auth.timer
t "systemctl list-timers helios-watch-auth.timer --no-pager"
t "grep -rE '^\s*Storage' /etc/systemd/journald.conf /etc/systemd/journald.conf.d/ 2>/dev/null"
t "ls -ld /var/log/journal; journalctl --disk-usage"
t "journalctl --list-boots --no-pager | tail -3"
t systemctl is-active firewalld
t getenforce
echo "===== fin $(date '+%F %T') ====="
