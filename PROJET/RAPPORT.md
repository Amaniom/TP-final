# Projet final — Portail de suivi des tournées — Rapport

Amziane Tarek (MTP). srv-core = 192.168.56.101 (SSH port 2242, compte admin_trake puis `sudo -i`).

**Rendu partiel.** Faute de temps je n'ai fait que : les prérequis, E8.1 (agent Zabbix), E1, E2 E3 (sans unit), E5 et E7.
E4, E6, E8.3-8.5, E9, E10 ne sont pas commencés, je le dis clairement dans le tableau. Je n'ai rien mis de faux.

Tout a été lancé en une fois avec le script `configs/projet-e8-e1-e2.sh` (en root), le 06/11/2026 entre 12:27:19 et 12:29:31 (heure du serveur).
La sortie complète copiée du terminal est dans `preuves/sortie-projet.txt`. Les captures sont dans `preuves/Captures_PROJET.pdf` (18 captures, 10 à 13 pour E3, 14 à 16 pour E5, 17-18 pour E7 : ce sont les vraies sorties du terminal srv-core, mises en image depuis `sortie-projet.txt`, pas des copies d'écran de fenêtre).

## 0. Prérequis

| Contrôle | Ce que j'ai eu | OK ? |
|---|---|---|
| `systemctl is-active helios-collect.service` | `active`, telemetry.csv modifié à 12:27 (1599 o) | OK |
| `systemctl cat helios.target` | la cible existe (`/etc/systemd/system/helios.target`) | OK |
| `firewall-cmd --get-default-zone` / `--get-active-zones` | `drop` ; `internal: bond0 bond0.42` | OK |
| `sshd -T` | `port 2242`, `allowgroups ssh-admins`, `passwordauthentication no` (+ `permitrootlogin no`) | OK |
| `systemctl is-active helios-watch-auth.timer` | `active` | OK |

**Captures 1 et 2.**

Instantanés : il n'y a pas de `03-fin-TP3` chez moi (j'ai `00-socle-propre`, `01-fin-TP1.`, `02b-fin-M1`). Mon srv-core était déjà dans l'état fin TP3 (les 5 contrôles passent) donc je n'ai rien restauré. J'ai lancé `VBoxManage snapshot srv-core take 04-debut-projet --live` depuis Windows à 12:16 (en live, la VM tournait).

**Écart à signaler au formateur** : l'uid **5104** imposé pour lea est **déjà pris** par `sysops` (compte admin créé au TP3, `getent passwd 5104` → `sysops:x:5104:5104:Administrateur TP3`). Je n'ai pas voulu changer sysops (il est dans ssh-admins, ça casserait mon accès / le TP3). Donc **lea a l'uid 5105**. Le reste (gid 5003, commentaire, mot de passe de lab) est comme demandé.

## 1. Tableau de conformité

| Exig. | État | Commande de preuve | Sortie utile |
|---|---|---|---|
| E1.1 | **Partiel** (uid) — cap. 5 | `getent group suivi` ; `id lea` ; `getent passwd lea` | `suivi:x:5003:` ; `uid=5105(lea) gid=5003(suivi) groupes=5003(suivi)` ; `lea:x:5105:5003:Lea Fabre - responsable suivi des tournees:/home/lea:/bin/bash` → uid 5105 au lieu de 5104 (voir écart) |
| E1.2 | OK | `chage -l lea` | Minimum 1, Maximum 90, warning 14, Password inactive févr. 11 2027 = 7 j après l'expiration (févr. 04 2027) |
| E1.3 | OK | `id -nG lea \| grep -wE 'wheel\|ssh-admins'` | rien trouvé → `lea ni wheel ni ssh-admins` |
| E1.4 | OK — cap. 6 | `getent passwd helios-suivi` ; `ls -ld /home/helios-suivi` | `helios-suivi:x:994:993:Service portail suivi:/srv/helios/suivi:/sbin/nologin` ; `/home/helios-suivi` : Aucun fichier ou dossier |
| E2.1 | OK — cap. 7 | `ls -ld .../www` | `drwxrws---+ 2 root suivi ... /srv/helios/suivi/www` (2770, autres = rien) |
| E2.2 | OK | `getfacl -p www` | `user:helios-suivi:rwx` (mask rwx) |
| E2.3 | OK — cap. 9 | `runuser -u zabbix -- ls www` / `-- stat .../index.html` | ls : `Permission non accordée` rc=2 ; stat : `lea:suivi 660` rc=0 (testé sur index.html car etat.json n'existe pas encore, E3 pas fait) |
| E2.4 | OK — cap. 8 | fichier créé par lea **avec umask 077** + `ls -l` + `getfacl` | `-rw-rw----+ 1 lea suivi` ; `user:helios-suivi:rwx #effective:rw-` ; `other::---` ; helios-suivi `cat` rc=0 ; nadia `cat` → `Permission non accordée` rc=1 |
| E2.5 | OK | `su - lea -c "... > www/index.html"` | propriétaire `lea`, contenu : `<h1>Portail de suivi des tournees Helios</h1><p>Page deposee par Lea Fabre.</p>` |
| E3.1-3.3 | OK — cap. 10, 11 + `preuves/sortie-e3.txt` | `runuser -u helios-suivi -- helios-suivi-publish.sh` ; `python3 -m json.tool` ; `journalctl -t helios-suivi-publish` | rc=0, JSON valide : `"genere": "2026-11-06T12:41:04+01:00"`, `"hote": "srv-core"`, `"derniere_mesure": "2026-11-06T12:40:59+01:00"`, `"charge_1min": 1.11`, `"mem_dispo_ko": 1356728`, `"mesures": 179` ; journal : `etat.json publie (179 mesures)` |
| E3.2 | OK (0, 2, 3 provoqués ; 1 pas provoqué) — cap. 12 | verrou tenu par `flock -n script sleep 5` puis 2e lancement ; lancement par nadia | rc=2 + journal `une autre instance tourne deja` ; rc=3 + journal `telemetrie illisible : /var/lib/helios/telemetry.csv` |
| E3.3 | OK | `ls -la www` après publication | seulement `etat.json` et `index.html`, pas de `.etat.json.XXXXXX` qui traîne (mktemp dans www puis `mv`) |
| E3.4 | **Partiel** | — | marche lancé en helios-suivi, mais pas testé dans une unit (E4 pas fait) |
| E4 | **Non réalisé** | — | aucune unit créée (helios-suivi.service, publish .service/.timer) |
| E5 | OK — `preuves/sortie-e5-e7.txt` | `visudo -c` ; `ls -l /etc/sudoers.d/92-helios-suivi` ; `sudo -l -U lea [...]` ; essai réel en lea | `92-helios-suivi : analyse réussie` ; `-r--r-----. 1 root root` ; lea liste exactement les 5 commandes (restart/status helios-suivi, start publish, journalctl -u ... -n 100 --no-pager x2) ; `restart sshd` rc=1 ; `journalctl --vacuum-time=1s` rc=1 ; même commande + `--vacuum-time=1s` rc=1 ; essai réel : journalctl OK (`-- No entries --`, unit pas encore créée), `restart sshd` → `l'utilisateur lea n'est pas autorisé` rc=1. Pas de NOPASSWD (lea a dû taper son mot de passe) |
| E6 | **Non réalisé** | — | 8080 pas ouvert (normal, rien n'écoute) |
| E7 | OK — `preuves/sortie-e5-e7.txt` | `sshd -T` ; `ssh -p 2242 lea@192.168.56.101` depuis le PC ; `journalctl -u sshd \| grep lea` ; timer ; journald | `port 2242`, `permitrootlogin no`, `passwordauthentication no`, `allowgroups ssh-admins` ; lea : `Permission denied (publickey)` rc=255, journal : `12:48:39 ... User lea from 192.168.56.1 not allowed because none of user's groups are listed in AllowGroups` ; `helios-watch-auth.timer` active (dernier passage 12:50:04) ; `Storage=persistent` (50-helios.conf), `/var/log/journal` existe, 2 boots listés ; firewalld active, SELinux Enforcing |
| E8.1 | OK — cap. 3, 4 | `rpm -q` ; `getent passwd zabbix` ; `systemctl is-active/is-enabled` ; `zabbix_get -k agent.ping` | `zabbix-agent2-7.0.32-release2.el9`, `zabbix-get-7.0.32-release2.el9`, `sysstat-12.5.4-11.el9` ; `zabbix:x:995:994` ; agent `active`/`enabled` ; `Server=127.0.0.1` ; `agent.ping` → `1` |
| E8.2 | OK — cap. 4 | `systemctl is-active sysstat-collect.timer; is-enabled` | `active` / `enabled` |
| E8.3–E8.5 | **Non réalisé** | — | pas de `helios-suivi.conf` (il faut le portail E4 et etat.json E3 avant) |
| E9 | **Non réalisé** | — | pas de /srv/helios/archives, pas de script de sauvegarde |
| E10 | **Non réalisé** (bonus) | — | — |

Pas d'EPEL sur mon srv-core (`/etc/yum.repos.d/` ne contient que les dépôts rocky*), donc l'exclusion `excludepkgs=zabbix*` du guide était sans objet : le paquet vient bien du dépôt `zabbix` en 7.0.32.

## 2. Justifications

(a) durcissement de helios-suivi.service : **pas fait** (E4 non réalisé), pas de score.

(b) pourquoi `--x` et pas `r-x` pour zabbix sur www :
- `x` sur un dossier = droit de le traverser, donc d'atteindre un fichier dont on connaît le nom (`stat` marche). `r` = lister le contenu. L'agent n'a besoin que de l'âge de etat.json, pas de savoir ce qu'il y a d'autre dans www → moindre privilège.
- Observé : avec `--x`, `runuser -u zabbix -- ls www` → `Permission non accordée` (rc=2), et `stat` sur index.html → OK (rc=0).
- Il faut aussi `--x` pour zabbix sur `/srv/helios/suivi` (0750 root:suivi), sinon il ne peut même pas arriver jusqu'à www. Je l'ai mis.
- Je n'ai **pas** testé le cas « sans cette entrée » (manque de temps). En théorie stat donnerait Permission non accordée, mais je ne l'ai pas vu.
- SELinux : `ausearch -m AVC -ts recent` → `<no matches>`.

(c) joker `*` dans la règle sudo journalctl : avec `journalctl *`, lea pourrait ajouter n'importe quelle option en root, par ex. `--vacuum-time=1s` / `--vacuum-size=1` qui **supprime les journaux archivés** (on efface les traces), ou `--rotate`, ou lire tous les journaux du système. Ma règle donne la commande complète `journalctl -u <unit> -n 100 --no-pager` : quand une règle sudo a des arguments, sudo exige exactement ceux-là. Vérifié : `sudo -l -U lea /usr/bin/journalctl -u helios-suivi.service -n 100 --no-pager --vacuum-time=1s` → rien, rc=1.

## 3. Test de restauration (E9.5)

Non réalisé.

## 4. Mesure sous charge

Non réalisée (le portail n'existe pas encore). sysstat collecte quand même depuis 12:29, donc `sar -u` sera utilisable.

## 5. Limites connues

- uid de lea = 5105 et pas 5104 (conflit avec sysops du TP3, voir plus haut). Avec plus de temps : en parler au formateur avant de toucher à sysops.
- E3.4 pas testé sous systemd (pas d'unit). Le code 1 (ligne invalide) existe dans le script mais je ne l'ai pas provoqué.
- E4, E6, E8.3-8.5, E9, E10 pas faits, E7 seulement en partie. Je n'ai pas réussi à gérer le temps sur les deux jours.
- L'ACL par défaut donne aussi `rwx` à helios-suivi sur les nouveaux fichiers (`#effective:rw-` à cause du masque), ça suffit pour E2.4.
- Pas de reboot fait après les modifs (tout est fait avec des commandes persistantes : useradd, chage, setfacl, systemctl enable, mais pas re-vérifié après un boot).
- Avec une journée de plus : E4 (units + `systemd-analyze security`), E5, E6 (`--zone=internal --add-port=8080/tcp` runtime + permanent), puis E8.3 et E9.

## 6. E3 — notes (fait à la fin, 12:41)

- Script : `configs/helios-suivi-publish.sh`, installé par `configs/projet-e3.sh` (0755 root:root dans /usr/local/sbin). Sortie : `preuves/sortie-e3.txt`.
- Les 5 règles : `set -Eeuo pipefail` ; verrou `flock -n` sur le script lui-même ouvert en lecture (`exec 9<"$0"`), donc pas besoin d'écrire un fichier de verrou (ça passera avec ProtectSystem=strict) ; `trap cleanup EXIT` qui supprime le fichier temporaire ; `logger -t helios-suivi-publish` ; codes 0/1/2/3.
- Atomicité : `mktemp` dans www (même système de fichiers) puis `mv` = rename, un lecteur voit l'ancien ou le nouveau fichier, jamais la moitié. `chmod 0660` avant le mv sinon mktemp crée en 0600 et le masque ACL tombe à `---` (lea ne pourrait plus lire).
- Problème rencontré : `/var/lib/helios` est en 750 helios:helios (TP1), helios-suivi ne pouvait pas lire telemetry.csv. J'ai **ajouté** une ACL `u:helios-suivi:--x` sur `/var/lib/helios` (rien retiré, le fichier lui-même est déjà 644). `getfacl` dans `sortie-e3.txt`.
- zabbix peut faire `stat` sur etat.json (`/srv/helios/suivi/www/etat.json 184 2026-11-06 12:41:04`), donc E2.3 est vérifié aussi sur le vrai fichier. Pas d'AVC.

## 7. E5 / E7 — notes (12:48 - 12:51)

- Fichier : `configs/92-helios-suivi` (validé `visudo -cf` avant `install -m 0440 -o root -g root`), script `configs/projet-e5-e7.sh`.
- `visudo -c` affiche un avertissement sur `90-helios-ops` (Cmnd_Alias DANGEREUX non utilisé) : c'est l'ancien fichier du TP2, je n'y ai pas touché.
- Les units helios-suivi n'existent pas encore (E4 pas fait), donc l'essai réel a été fait avec journalctl (autorisé, `-- No entries --`) et le refus avec `restart sshd`. Le restart du portail n'a pas pu être testé pour de vrai.
- Le refus SSH de lea a été fait depuis mon PC Windows (192.168.56.1), pas depuis srv-edge.
