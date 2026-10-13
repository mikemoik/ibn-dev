#!/usr/bin/env bash
# test/run.sh — prove the offline dist build on a clean RHEL9 (UBI9) container.
# The image only gets the toolchain RPMs; build-dist.sh and the devlibs test
# run with --network=none and the repo mounted read-only.
#
# It builds from the files git tracks (as in the working tree), copied to a
# temp dir. Untracked or git-ignored files are left out: `git add` new files
# first. GDAL reading/writing a GeoTIFF from a program is covered by
# test/prodsim/run.sh, in ibn-dev.
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
IMAGE=ibn-dev-test
SRC=$(mktemp -d)
trap 'rm -rf "$SRC"' EXIT
git -C "$ROOT" ls-files -z | tar -C "$ROOT" --null -T - -cf - | tar -C "$SRC" -xf -

docker build -q -t "$IMAGE" -f "$ROOT/test/Containerfile" "$ROOT/test" >/dev/null
docker run --rm --network=none -v "$SRC:/src:ro" "$IMAGE" bash -euc '
  /src/build-dist.sh /opt/ibn-dist
  echo "==> C/C++ libraries (cmake 4, onnxruntime, ACE+TAO, OpenDDS, PROJ, GEOS, GDAL)"
  . /opt/ibn-dist/bin/ibn-dist-env.sh
  test "$IBN_DIST_PREFIX" = /opt/ibn-dist
  cmake --version | grep -q "^cmake version 4\\."
  cmake -S /src/test/devlibs -B /tmp/devlibs -D CMAKE_BUILD_TYPE=Release >/tmp/devlibs.log ||
    { cat /tmp/devlibs.log; exit 1; }
  cmake --build /tmp/devlibs -j "$(nproc)" >>/tmp/devlibs.log || { tail -40 /tmp/devlibs.log; exit 1; }
  /tmp/devlibs/devlibs
  # the installed tools run from PREFIX alone ($ORIGIN-relative RPATH)
  rm -rf "${IBN_BUILD_DIR:-/tmp/ibn-build}"
  tao_idl -V 2>&1 | grep -m1 "TAO_IDL_FE"
  opendds_idl --version
  # GDAL on the dist PROJ/GEOS (UBI9 has neither), proj.db found next to libproj
  ldd /opt/ibn-dist/lib64/libgdal.so.36 | grep -E "lib(proj|geos_c)\.so" | grep -v /opt/ibn-dist/ &&
    { echo "libgdal links PROJ/GEOS outside the dist" >&2; exit 1; }
  gdalinfo --version
  gdalinfo --formats | grep -q "^ *GTiff "
  gdalsrsinfo -o proj4 EPSG:25832 | grep -q "+proj=utm +zone=32"
  geos-config --version
'
echo "ibn-dev test: ok"
