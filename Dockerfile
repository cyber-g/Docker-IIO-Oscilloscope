FROM debian:trixie-slim

# libiio v1 stack, as required by iio-oscilloscope main since 2025-10-01:
# https://github.com/analogdevicesinc/iio-oscilloscope/blob/main/README.md
# Only libiio has a v1 release tag; the others are branch names (moving refs).
ARG LIBIIO_VERSION=v1.0.0
ARG LIBAD9361_VERSION=staging/libiio1-support
ARG LIBAD9166_VERSION=staging/libiio1-support
ARG OSC_VERSION=main

# Build dependencies, taken from the upstream build files:
# - libiio (libxml2, libusb, avahi):
#   https://github.com/analogdevicesinc/libiio/blob/v1.0.0/README_BUILD.md
# - osc (gtk3, gtkdatabox, fftw3, matio, curl, jansson; libxml2 above):
#   https://github.com/analogdevicesinc/iio-oscilloscope/blob/main/CMakeLists.txt#L113-L124
# - libad9361-iio / libad9166-iio: nothing beyond libiio.
# Runtime libraries come along as dependencies of the -dev packages.
RUN apt-get update && apt-get install -y --no-install-recommends \
      build-essential cmake git pkg-config ca-certificates \
      libxml2-dev libusb-1.0-0-dev libavahi-client-dev \
      libgtk-3-dev libgtkdatabox-dev libfftw3-dev libmatio-dev \
      libcurl4-openssl-dev libjansson-dev \
      librsvg2-common \
    && rm -rf /var/lib/apt/lists/*

# Build and install into /usr/local, in dependency order.
# libiio: iiod (the daemon that runs on the target board) is not needed here.
RUN set -e; \
    build() { \
      git clone --depth 1 --branch "$2" "https://github.com/analogdevicesinc/$1.git" /tmp/src; \
      cmake -S /tmp/src -B /tmp/src/build $3; \
      cmake --build /tmp/src/build -j "$(nproc)"; \
      cmake --install /tmp/src/build; \
      rm -rf /tmp/src; \
    }; \
    build libiio           "$LIBIIO_VERSION" -DWITH_IIOD=OFF; \
    build libad9361-iio    "$LIBAD9361_VERSION"; \
    build libad9166-iio    "$LIBAD9166_VERSION"; \
    build iio-oscilloscope "$OSC_VERSION"; \
    ldconfig

COPY --chmod=0755 scripts/smoke-test.sh /usr/local/bin/osc-smoke-test
RUN osc-smoke-test

WORKDIR /tmp
ENTRYPOINT ["/usr/local/bin/osc"]
