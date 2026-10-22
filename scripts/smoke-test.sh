#!/bin/sh
# Headless check (no display, no hardware): files, plugins, shared libraries.
set -eu

for f in /usr/local/bin/osc \
         /usr/local/share/osc/glade/osc.glade \
         /usr/local/lib/osc/fmcomms2.so \
         /usr/local/lib/osc/cn0511.so; do
    test -s "$f" || { echo "MISSING: $f" >&2; exit 1; }
done

iio_info -V

if ldd /usr/local/bin/osc /usr/local/lib/osc/*.so "$(command -v iio_info)" | grep 'not found'; then
    echo "ERROR: unresolved shared libraries" >&2
    exit 1
fi

echo "Runtime smoke test passed"
