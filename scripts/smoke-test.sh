#!/bin/sh
# Headless runtime check: binaries, resources, plugins and shared libraries.
# Needs neither a display nor IIO hardware. Exits non-zero on failure.
set -eu

PREFIX=${PREFIX:-/usr/local}
fail=0

check() {
    if test "$1" "$2"; then
        echo "ok:      $2"
    else
        echo "MISSING: $2" >&2
        fail=1
    fi
}

check -x "$PREFIX/bin/osc"
check -x "$PREFIX/bin/iio_info"
check -s "$PREFIX/share/osc/glade/osc.glade"
# Plugins that depend on libad9361-iio / libad9166-iio
check -s "$PREFIX/lib/osc/fmcomms2.so"
check -s "$PREFIX/lib/osc/cn0511.so"

"$PREFIX/bin/iio_info" -V || fail=1

report=$(mktemp)
trap 'rm -f "$report"' EXIT

for f in "$PREFIX/bin/osc" "$PREFIX/bin/iio_info" \
         $(find "$PREFIX/lib" -type f -name '*.so*'); do
    ldd "$f" 2>&1 | sed "s|^|$f: |"
done > "$report"

if grep -F 'not found' "$report" >&2; then
    echo "ERROR: unresolved shared libraries" >&2
    fail=1
fi

if [ "$fail" -ne 0 ]; then
    echo "Runtime smoke test FAILED" >&2
    exit 1
fi
echo "Runtime smoke test passed"
