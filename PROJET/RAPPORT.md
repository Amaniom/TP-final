# Projet final — Portail de suivi

srv-core = `192.168.56.101` (SSH 2242, `admin_trake` puis `sudo -i`).

Rendu **partiel**. Fait : prérequis, E1, E2, E3 (sans unit), E5, E7, E8.1-8.2.
Pas fait : E4, E6, E8.3-8.5, E9, E10.

Sorties complètes dans `preuves/` (`sortie-projet.txt`, `sortie-e3.txt`, `sortie-e5-e7.txt`).
Captures : `preuves/Captures_PROJET.pdf` (18). Ce sont les sorties du terminal mises en image, pas des copies d'écran.

---

## Prérequis

Les 5 contrôles passent : `helios-collect` active, `helios.target` existe, zone par défaut `drop`, `bond0 bond0.42` en `internal`, `sshd -T` → 2242 / ssh-admins / no, `helios-watch-auth.timer` active.

Pas de snapshot `03-fin-TP3` chez moi. J'ai pris `04-debut-projet` en live (VBoxManage, 12:16).

**Problème :** uid 5104 déjà pris par `sysops` (TP3).
```
sysops:x:5104:5104:Administrateur TP3:/home/sysops:/bin/bash
```
→ lea créée en **5105**. Je n'ai pas touché à sysops.

*Captures 1–2*

---

## 1. Tableau de conformité

| Exig. | État | Preuve (sortie) | Cap. |
|---|---|---|---|
| E1 | partiel (uid) | `id lea` → `uid=5105(lea) gid=5003(suivi) groupes=5003(suivi)` · `chage -l lea` → min 1 / max 90 / warning 14 / inactive févr. 11 2027 (expire févr. 04) · pas wheel ni ssh-admins · `helios-suivi:x:994:993:...:/srv/helios/suivi:/sbin/nologin`, pas de `/home/helios-suivi` | 5, 6 |
| E2 | OK | `drwxrws---+ root suivi www` · `user:helios-suivi:rwx` `user:zabbix:--x` · index.html de lea (umask 077) → `-rw-rw----+ lea suivi` · nadia `cat` → Permission non accordée · zabbix `ls` refusé rc=2, `stat` OK | 7, 8, 9 |
| E3 | OK sauf E3.4 | rc=0 (JSON valide `json.tool`) · rc=2 verrou · rc=3 nadia · journal `-t helios-suivi-publish` 3 lignes · pas de fichier temp dans www. Pas testé dans une unit | 10–13 |
| E4 | non fait | — | |
| E5 | OK | `visudo -c` → analyse réussie · `-r--r-----. root root` · `sudo -l -U lea /usr/bin/systemctl restart sshd` → rien rc=1 · `--vacuum-time=1s` rc=1 · essai lea : journalctl OK, `restart sshd` → « lea n'est pas autorisé » | 14–16 |
| E6 | non fait | — | |
| E7 | OK | `sshd -T` → 2242 / no / no / ssh-admins · lea : `Permission denied (publickey)` + journal `User lea from 192.168.56.1 not allowed because none of user's groups are listed in AllowGroups` · timer active · `Storage=persistent` | 17, 18 |
| E8 | 8.1-8.2 OK, reste non fait | `zabbix-agent2-7.0.32` · `Server=127.0.0.1` · active/enabled · `agent.ping` → `1` · `sysstat-collect.timer` active/enabled. Pas de helios-suivi.conf | 3, 4 |
| E9 | non fait | — | |
| E10 | non fait (bonus) | — | |

Pas d'EPEL sur le serveur → exclusion `zabbix*` inutile.

---

## 2. Justifications

**(a) durcissement helios-suivi.service** : pas fait (pas d'E4).

**(b) `--x` et pas `r-x` pour zabbix**
`x` = traverser le dossier, `r` = lister. L'agent doit juste faire `stat` sur etat.json.
Vu : `ls` → Permission non accordée, `stat` → OK.
Il a fallu aussi `--x` sur `/srv/helios/suivi`.
Pas testé sans l'entrée.

**(c) joker `*` derrière journalctl**
lea pourrait ajouter `--vacuum-time=1s` → efface les journaux en root.
Ma règle = commande complète `journalctl -u <unit> -n 100 --no-pager`, donc pas d'option en plus.
Testé : avec `--vacuum-time=1s` en plus → refusé, rc=1.

---

## 3. Restauration (E9.5)

Pas faite.

## 4. Mesure sous charge

Pas faite (pas de portail). sysstat collecte depuis 12:29.

---

## 5. Limites

- uid lea = 5105 (conflit sysops).
- E3 : `/var/lib/helios` est en 750 helios:helios → helios-suivi ne pouvait pas lire la télémétrie. J'ai **ajouté** `setfacl -m u:helios-suivi:--x /var/lib/helios`.
- E3 : `mktemp` crée en 0600 → masque ACL à `---`. Ajout d'un `chmod 0660` avant le `mv`.
- E3 : code 1 dans le script mais pas provoqué. Pas testé avec systemd.
- E5 : units pas créées, donc restart du portail pas testé en vrai.
- `visudo -c` : warning sur `90-helios-ops` (alias DANGEREUX non utilisé), ancien fichier TP2, pas touché.
- refus SSH de lea fait depuis mon PC, pas depuis srv-edge.
- pas de reboot fait pour revérifier.
- Avec une journée de plus : E4, E6, E8.3, E9.
