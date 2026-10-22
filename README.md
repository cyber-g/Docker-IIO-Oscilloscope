# Docker-IIO-Oscilloscope
This repository builds a Docker image for installing and running the Analog Devices IIO Oscilloscope

The image (Debian Trixie) is also converted into an [Apptainer](https://apptainer.org) SIF file,
which can be copied to Linux machines and run without Docker or network pulls.

Versions (git tags, set in the `Dockerfile`): libiio `v0.26`, libad9361-iio `v0.4.0`,
libad9166-iio `v0.3.0`, iio-oscilloscope `v0.18.1`.

## Build

Requires Linux, Docker, Apptainer and Make.

```sh
make all     # docker build -> docker save -> apptainer build -> smoke test
```

Output: `dist/osc-dev-amd64.sif` and `dist/osc-dev-amd64.sif.sha256`.
Variables: `IMAGE`, `TAG`, `ARCH`, e.g. `make all TAG=1.0`.

## Run

```sh
apptainer run osc.sif                     # starts osc (needs X11 / XWayland)
apptainer run osc.sif -u ip:192.168.2.1   # arguments are passed to osc
apptainer exec osc.sif osc-smoke-test     # headless check
```

## Distribute

Copy the `.sif` and `.sha256` files to the target machines (shared drive, rsync,
USB stick...), then check and run:

```sh
sha256sum -c osc-dev-amd64.sif.sha256
apptainer run osc-dev-amd64.sif
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
(tags = commit SHA). It needs the repository variable `DOCKERHUB_USERNAME` and the
secret `DOCKERHUB_TOKEN`.

## Limitations

- GUI needs an X11 (or XWayland) display on the host.
- USB/serial device access depends on the host user's permissions (udev rules).
- `amd64` only by default; build natively with `ARCH=arm64` for ARM machines.
