# syntax=docker/dockerfile:1

# ---------------------------------------------------------------------------
# runtime: shared libraries needed to run osc (GTK3 GUI + IIO backends)
# ---------------------------------------------------------------------------
FROM debian:bookworm-slim AS runtime

RUN apt-get update && apt-get install -y --no-install-recommends \
      adwaita-icon-theme \
      ca-certificates \
      fonts-dejavu-core \
      hicolor-icon-theme \
      libavahi-client3 \
      libavahi-common3 \
      libcurl4 \
      libfftw3-double3 \
      libgtk-3-0 \
      libgtkdatabox1 \
      libjansson4 \
      libmatio11 \
      librsvg2-common \
      libserialport0 \
      libusb-1.0-0 \
      libxml2 \
      libzstd1 \
    && rm -rf /var/lib/apt/lists/*

# ---------------------------------------------------------------------------
# build: libiio (v1) -> libad9361-iio -> libad9166-iio -> iio-oscilloscope
# ---------------------------------------------------------------------------
FROM runtime AS build

# Pinned sources (osc main uses libiio v1; libad9361/libad9166 must come from
# their "staging/libiio1-support" branches). Update together and retest.
ARG LIBIIO_REF=b26d040b2c70426a99ef5d1f2690c7e5cad2e5ea
ARG LIBAD9361_REF=6b69b5e6c1eb0ffa1a61f07e74d30ecd4e5db328
ARG LIBAD9166_REF=6c5924c50ba527b5f40f9c19d38289eedad585c2
ARG OSC_REF=d8552c293185fc545b4ad6fcdf4d54bf2b9537a0
ARG JOBS=2

RUN apt-get update && apt-get install -y --no-install-recommends \
      build-essential \
      cmake \
      git \
      pkg-config \
      libavahi-client-dev \
      libavahi-common-dev \
      libcurl4-openssl-dev \
      libfftw3-dev \
      libgtk-3-dev \
      libgtkdatabox-dev \
      libjansson-dev \
      libmatio-dev \
      libserialport-dev \
      libusb-1.0-0-dev \
      libxml2-dev \
      libzstd-dev \
    && rm -rf /var/lib/apt/lists/*

ENV PKG_CONFIG_PATH=/usr/local/lib/pkgconfig
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN set -eux; \
    build_project() { \
      local repo="$1" ref="$2"; shift 2; \
      local src="/tmp/src/$repo" build="/tmp/build/$repo"; \
      git init -q "$src"; \
      git -C "$src" remote add origin "https://github.com/analogdevicesinc/$repo.git"; \
      git -C "$src" fetch -q --depth=1 origin "$ref"; \
      git -C "$src" checkout -q --detach FETCH_HEAD; \
      git -C "$src" submodule update --init --recursive --depth=1; \
      echo "$repo $(git -C "$src" rev-parse HEAD)" >> /usr/local/share/osc-container/versions.txt; \
      cmake -S "$src" -B "$build" \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=/usr/local \
        -DCMAKE_INSTALL_LIBDIR=lib \
        -DCMAKE_PREFIX_PATH=/usr/local \
        "$@"; \
      cmake --build "$build" --parallel "$JOBS"; \
      cmake --install "$build"; \
      ldconfig; \
    }; \
    mkdir -p /usr/local/share/osc-container; \
    build_project libiio "$LIBIIO_REF" \
      -DWITH_IIOD=OFF -DWITH_UTILS=ON -DWITH_EXAMPLES=OFF -DWITH_MAN=OFF \
      -DWITH_USB_BACKEND=ON -DWITH_NETWORK_BACKEND=ON -DWITH_SERIAL_BACKEND=ON \
      -DWITH_LOCAL_BACKEND=ON -DWITH_XML_BACKEND=ON -DHAVE_DNS_SD=ON; \
    build_project libad9361-iio "$LIBAD9361_REF" \
      -DWITH_DOC=OFF -DPYTHON_BINDINGS=OFF -DENABLE_PACKAGING=OFF; \
    build_project libad9166-iio "$LIBAD9166_REF" \
      -DWITH_DOC=OFF -DPYTHON_BINDINGS=OFF -DENABLE_PACKAGING=OFF; \
    build_project iio-oscilloscope "$OSC_REF"; \
    rm -rf /tmp/src /tmp/build

# ---------------------------------------------------------------------------
# final: runtime libs + /usr/local only (no compilers, no sources)
# ---------------------------------------------------------------------------
FROM runtime AS final

COPY --from=build /usr/local/ /usr/local/
COPY --chmod=0755 scripts/smoke-test.sh /usr/local/bin/osc-smoke-test

RUN ldconfig && /usr/local/bin/osc-smoke-test

WORKDIR /tmp
ENTRYPOINT ["/usr/local/bin/osc"]
