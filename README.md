# Docker-IIO-Oscilloscope

Construit [IIO Oscilloscope](https://github.com/analogdevicesinc/iio-oscilloscope)
(`osc`, Analog Devices) dans une image Docker Debian Bookworm, puis la convertit
en fichier **SIF Apptainer** distribuable par simple copie de fichier.

| Fichier | Rôle |
|---|---|
| `Dockerfile` | Build multi-stage : `libiio` (v1) → `libad9361-iio` → `libad9166-iio` → `iio-oscilloscope`, installés dans `/usr/local` |
| `scripts/smoke-test.sh` | Test sans écran ni matériel (binaires, glade, plugins, `ldd`, `iio_info -V`), installé comme `osc-smoke-test` |
| `Makefile` | `docker`, `sif`, `test`, `publish-docker`, `publish-sif`, `publish`, `clean` |
| `.github/workflows/build.yml` | Build + test sur PR, publication Docker Hub sur `main` |

## Versions des sources

Depuis le 2025‑10‑01, la branche `main` d'iio-oscilloscope utilise **libiio v1**
et nécessite les branches `staging/libiio1-support` de `libad9361-iio` et
`libad9166-iio`. Les quatre dépôts sont figés sur des commits via des `ARG`
du `Dockerfile` :

| ARG | Dépôt | Ref |
|---|---|---|
| `LIBIIO_REF` | `analogdevicesinc/libiio` | `main` |
| `LIBAD9361_REF` | `analogdevicesinc/libad9361-iio` | `staging/libiio1-support` |
| `LIBAD9166_REF` | `analogdevicesinc/libad9166-iio` | `staging/libiio1-support` |
| `OSC_REF` | `analogdevicesinc/iio-oscilloscope` | `main` |

Les commits effectivement compilés sont listés dans
`/usr/local/share/osc-container/versions.txt` à l'intérieur de l'image.
Pour changer de versions (à mettre à jour ensemble, puis retester) :

```sh
make all DOCKER_BUILD_FLAGS="--build-arg OSC_REF=<sha> --build-arg LIBIIO_REF=<sha>"
```

## Prérequis (machine de build)

- Linux, GNU Make
- Docker (utilisable par l'utilisateur courant)
- [Apptainer](https://apptainer.org/docs/admin/main/installation.html) ≥ 1.2,
  par ex. sous Ubuntu :

  ```sh
  sudo add-apt-repository -y ppa:apptainer/ppa
  sudo apt-get update && sudo apt-get install -y apptainer
  ```

## Build local

```sh
make all            # = docker + sif + test
```

Produit :

```
dist/osc-dev-amd64.sif
dist/osc-dev-amd64.sif.sha256
```

Étapes séparées :

```sh
make docker         # image Docker locale local/iio-oscilloscope:dev
make sif            # docker save -> apptainer build ... docker-archive:  (+ sha256)
make test           # apptainer exec dist/osc-dev-amd64.sif osc-smoke-test
make clean          # supprime dist/
```

Variables : `IMAGE` (défaut `local/iio-oscilloscope`), `TAG` (`dev`),
`ARCH` (`amd64`), `JOBS` (`nproc`), `DOCKER`, `APPTAINER`,
`DOCKER_BUILD_FLAGS`, `APPTAINER_BUILD_FLAGS`, `APPTAINER_PUSH_FLAGS`.

La conversion Docker → SIF passe par une archive locale (`docker save`) :
aucun registre n'est nécessaire.

## Exécuter le SIF

```sh
apptainer run osc.sif                       # lance osc (ENTRYPOINT)
apptainer run osc.sif -u ip:192.168.2.1     # arguments passés à osc
apptainer exec osc.sif iio_info -s          # autre commande du conteneur
apptainer exec osc.sif osc-smoke-test       # test sans écran
apptainer shell osc.sif
```

Avec `run`, ne pas répéter `/usr/local/bin/osc` : il serait passé comme
argument à osc. Utiliser `exec` pour lancer une autre commande.

L'interface graphique utilise l'affichage de l'hôte (X11, ou Wayland avec
XWayland) : `DISPLAY` et `$HOME` (donc `~/.Xauthority`) sont transmis par
Apptainer par défaut. Si `~/.Xauthority` est ailleurs :

```sh
apptainer run --env XAUTHORITY="$XAUTHORITY" --bind "$XAUTHORITY" osc.sif
```

## Distribution par fichier (recommandé)

Le SIF est un fichier autonome : il suffit de le copier sur les postes, sans
pull réseau ni Docker sur les machines cibles (seul Apptainer est requis).

1. Obtenir le SIF une seule fois : `make all`, l'artefact du workflow GitHub
   Actions, ou un `apptainer pull oras://...` (voir plus bas).
2. Copier `osc-<tag>-amd64.sif` **et** `osc-<tag>-amd64.sif.sha256` (partage
   réseau interne, outil de déploiement, `scp`/`rsync`, clé USB…), par exemple :

   ```sh
   rsync -av dist/osc-dev-amd64.sif dist/osc-dev-amd64.sif.sha256 poste:/opt/containers/
   ```

3. Sur le poste cible, vérifier l'intégrité puis lancer :

   ```sh
   cd /opt/containers
   sha256sum -c osc-dev-amd64.sif.sha256
   apptainer exec osc-dev-amd64.sif osc-smoke-test
   apptainer run osc-dev-amd64.sif
   ```

Le SHA‑256 détecte une copie corrompue ; ce n'est pas une signature
d'authenticité (voir `apptainer sign` / `apptainer verify` si nécessaire).

## Publication sur Docker Hub

Nom d'image suggéré : `<dockerhub-user>/iio-oscilloscope`. Deux tags par build :

| Tag | Contenu | Utilisation |
|---|---|---|
| `<tag>` | image Docker/OCI | `docker pull` / `docker run` |
| `<tag>-sif` | fichier SIF stocké comme **artefact OCI** (ORAS) | `apptainer pull oras://...` |

> Le tag `-sif` n'est **pas** une image exécutable par Docker : c'est un
> artefact OCI destiné uniquement à Apptainer/ORAS.

Publication manuelle (après `make all` avec les **mêmes** `IMAGE`/`TAG`/`ARCH`,
les cibles `publish-*` ne reconstruisent rien et refusent le nom par défaut
`local/iio-oscilloscope`) :

```sh
make all IMAGE=<user>/iio-oscilloscope TAG=1.0
docker login -u <user>
apptainer registry login --username <user> oras://registry-1.docker.io
make publish IMAGE=<user>/iio-oscilloscope TAG=1.0
```

Récupérer un SIF publié (une seule fois, sur une machine de préparation) :

```sh
apptainer pull osc-1.0-amd64.sif oras://registry-1.docker.io/<user>/iio-oscilloscope:1.0-sif
sha256sum osc-1.0-amd64.sif > osc-1.0-amd64.sif.sha256
```

## GitHub Actions

`.github/workflows/build.yml` (actions officielles GitHub et Docker uniquement) :

- `pull_request`, `push` sur `main`, `workflow_dispatch` ;
- installe Apptainer (PPA officiel), lance `make all`, publie le SIF et son
  SHA‑256 comme artefact du workflow ;
- sur `main` uniquement : `docker/login-action`, `make publish-docker`, puis
  `apptainer registry login` (authfile temporaire, `--password-stdin`) et
  `make publish-sif` avec `--authfile`.

Tags publiés : les 12 premiers caractères du commit (`<sha12>` et `<sha12>-sif`).

Configuration du dépôt GitHub (*Settings → Secrets and variables → Actions*) :

| Type | Nom | Valeur |
|---|---|---|
| Variable | `DOCKERHUB_USERNAME` | identifiant Docker Hub |
| Secret | `DOCKERHUB_TOKEN` | token Docker Hub (droits *Read & Write*) |

## Limites connues

- **GUI** : nécessite un serveur X (X11 ou XWayland) côté hôte ; pas de
  Wayland natif testé. Des avertissements `dconf` peuvent apparaître sans
  conséquence.
- **Matériel IIO** : le smoke test ne vérifie ni l'affichage ni le matériel.
  Les accès USB/série restent soumis aux droits de l'utilisateur hôte (règles
  udev à faire valider par l'administrateur) ; le réseau (`ip:`) fonctionne
  sans configuration particulière. `iiod` n'est pas inclus.
- **Architecture** : `amd64` par défaut. Pour ARM64, construire nativement
  sur une machine ARM64 avec `make all ARCH=arm64` (pas d'émulation configurée).
  Le SIF doit correspondre à l'architecture des postes.
- **Reproductibilité** : les sources ADI sont figées, mais l'image Debian et
  les paquets APT évoluent (build non reproductible bit à bit).
- Apptainer doit être installé et autorisé sur les postes cibles (espaces de
  noms utilisateur ou installation setuid selon la politique du site).
