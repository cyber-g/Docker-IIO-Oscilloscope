# Docker-IIO-Oscilloscope
This repository builds a Docker image for installing and running the Analog Devices IIO Oscilloscope

The image (Debian Trixie) is also converted into an [Apptainer](https://apptainer.org) SIF file,
which can be copied to Linux machines and run without Docker or network pulls.

Uses the libiio v1 stack required by iio-oscilloscope `main` (set in the `Dockerfile`):
libiio `v1.0.0`, libad9361-iio and libad9166-iio `staging/libiio1-support`,
iio-oscilloscope `main`. Branches move over time; override with e.g.
`make all DOCKER_BUILD_FLAGS="--build-arg OSC_VERSION=<tag-or-branch>"`.

## Build

Requires Linux, Docker, Apptainer and Make.

```sh
make all     # docker build -> docker save -> apptainer build -> smoke test
```

Output: `dist/osc-dev-<arch>.sif` and its `.sha256` (`<arch>` = host architecture, e.g. `x86_64`).
Variables: `IMAGE`, `TAG`, e.g. `make all TAG=1.0`.

## Run

On a Linux machine with Apptainer installed, download the image and convert it to a SIF file:

```sh
apptainer pull osc.sif docker://drdpham/iio-oscilloscope:c05bd325dd48
```

This command saves `osc.sif` locally in the directory where you run the command.
The image download is currently about 385 MB.

From that same directory, start the application (requires X11 / XWayland):

```sh
apptainer run osc.sif /usr/local/bin/osc
```

Once downloaded, the local SIF file can be reused without pulling the image again.
Additional commands:

```sh
apptainer run osc.sif                     # starts osc (needs X11 / XWayland)
apptainer run osc.sif -u ip:192.168.2.1   # arguments are passed to osc
apptainer exec osc.sif osc-smoke-test     # headless check
```

## Distribute

Copy the `.sif` and `.sha256` files to the target machines (shared drive, rsync,
USB stick...), then check and run:

```sh
sha256sum -c osc-dev-x86_64.sif.sha256
apptainer run osc-dev-x86_64.sif
```

## Publish to Docker Hub

```sh
make all     IMAGE=<user>/iio-oscilloscope TAG=1.0
make publish IMAGE=<user>/iio-oscilloscope TAG=1.0   # after docker login / apptainer registry login
```

This pushes the Docker image as `<tag>` and the SIF as `<tag>-sif`. The `-sif` tag is an
OCI artifact for Apptainer only (not runnable by Docker):

```sh
apptainer pull osc.sif oras://registry-1.docker.io/<user>/iio-oscilloscope:1.0-sif
```

The GitHub Actions workflow builds and tests every PR, and publishes on `main`
(tags = commit SHA). Configure in *Settings → Secrets and variables → Actions*:

| Type | Name | Example |
|---|---|---|
| Variable | `DOCKERHUB_IMAGE` | `drdpham/iio-oscilloscope` (destination repository) |
| Variable | `DOCKERHUB_USERNAME` | `drdpham` (account owning the token) |
| Secret | `DOCKERHUB_TOKEN` | Docker Hub access token (Read & Write) |

## Limitations

- GUI needs an X11 (or XWayland) display on the host.
- USB/serial device access depends on the host user's permissions (udev rules).
- The image targets the build machine's architecture; build on an ARM64 machine for ARM64 targets.
