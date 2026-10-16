# ibn-dev

The RHEL9 build environment for C/C++ and Python projects, as a podman
image: the RHEL toolchain and libraries, plus the C/C++ libraries dnf does not
have (CMake 4, onnxruntime, ACE+TAO, OpenDDS, GDAL with GTiff and its PROJ
and GEOS), built
**offline from source** out of the upstream release tarballs in `dist/`. Your
projects are built in the container, installed to the mounted `~/workspace`,
and run on the host against those libraries.

The terminal IDE kide is a separate repo (`kreatos/kide`); its image can be
built on top of this one (see [kide on top](#kide-on-top)).

| Path | Content |
|---|---|
| `podman/Containerfile.ibn-dev` | the image |
| `podman/base.conf`, `podman/conf/` | base image, repo setup, user, pip/uv config ([Another base image](#another-base-image)) |
| `build-dist.sh` | builds the C/C++ libraries from `dist/` (run in the container) |
| `dist/`, `manifest/dist.tsv` | upstream release tarballs kept as shipped, pinned + sha256-checked |
| `dist-env/` | `ibn-dist-env.sh`/`.fish`, installed by `build-dist.sh` |
| `container-shell/` | the shells' hooks: loader, `10-ibn-dev.sh`/`.fish` ([Shell hooks](#shell-hooks-workspacecontainer)) |
| `devcontainer/` | `ibn-devcontainer`: the image as a VS Code dev container |
| `test/` | `run.sh` (offline UBI9 build), `prodsim/` (the workflow end to end) |
| `scripts/dist-update.sh` | the only step that downloads: refreshes `dist/` and `VERSIONS` |
| `VERSIONS` | every component with upstream URL and version |

## The image

Built on top of a base image (`BASE` in `podman/base.conf`, default Rocky
Linux 9, RHEL9-compatible; UBI9 lacks packages the EPEL ones depend on: Qt5,
gdal-libs, protobuf for opencv, GL libraries for glew/glfw):

- the RHEL packages (from AppStream/CRB/EPEL): gcc/g++, make, cmake,
  clangd/clang-format/clang-tidy, gdb, lldb, git, perl + perl-Dumpvalue,
  Python 3.12 with numpy and pybind11, opencv, glew, glfw, gdal-libs (for opencv),
  Qt5 (`qt5`, and `qt5-qtbase-devel` for its CMake configs), Qt5 Charts
  (`qt5-qtcharts-devel`, from EPEL; `qt5` does not include it), libtiff + libtiff-devel, and what the PROJ/GEOS/GDAL build
  needs (sqlite, and the -devel packages of sqlite, libcurl, expat, zlib; all
  BaseOS/AppStream, no CRB)
- `build-dist.sh` with `dist/` in `/opt/ibn-dev/dist` (`build-dist.sh` on
  `PATH`), not the built libraries ([Libraries](#libraries-built-into-workspaceibn-dist))
- pip (newest) and uv for Python 3.12, pip-installed by the image's user
  (`KIDE_USER`) into its `~/.local`; root installs nothing with pip, it only
  sets up their config and certificate system-wide
- `safe.directory = *` for git; bash is the shell

### Build

From the repo root (a checkout or an unpacked tarball; the last argument of
`podman build` is the directory copied into the build), a few minutes, mostly
dnf:

    podman build --build-arg-file podman/base.conf -t ibn-dev -f podman/Containerfile.ibn-dev .

Straight from the GitLab (podman clones the repo itself; public project
only; the arg file is local, so its values are given directly):

    podman build --build-arg BASE=docker.io/rockylinux/rockylinux:9 --build-arg CONF_DIR=podman/conf --build-arg KIDE_USER=default --build-arg KIDE_UID=1001 --build-arg KIDE_GID=1001 --build-arg PIP_INDEX_URL=https://pypi.org/simple -t ibn-dev -f podman/Containerfile.ibn-dev https://gitlab.com/kreatos/ibn-dev.git

The `dnf install` steps need the base's repos (Rocky + CRB + EPEL by
default) and the `pip install` step the pip repo, so the build needs internet
or a mirror. Offline box: build on a connected machine and carry the image
over (`podman save -o ibn-dev.tar ibn-dev`, then `podman load -i ibn-dev.tar`).

### Run

    podman run --rm -it --http-proxy=false --userns=keep-id:uid=1001,gid=1001 -v "$HOME/workspace:/workspace:Z" ibn-dev

- `-v "$HOME/workspace:/workspace:Z"`: your `~/workspace` (create it once:
  `mkdir -p ~/workspace`) on `/workspace`, the container's working directory.
  `:Z` relabels it for SELinux (needed on RHEL).
- `--userns=keep-id:uid=1001,gid=1001`: the container runs as `KIDE_USER`
  (`default`, uid/gid 1001, `podman/base.conf`), not root. With rootless
  podman (your normal user, not `sudo podman`) this maps your host user to
  it, so the files it writes stay yours (podman 4.3+).
- `--http-proxy=false`: the host's proxy variables stay out (the build still
  gets them, so dnf and pip can use the proxy). As a fallback, the shells'
  hook loader unsets them too.
- Root inside for a one-off (e.g. `dnf install` to try a package): add
  `--user root` and leave out `--userns=…`. Not kept: the next container
  starts from the image again.

### Shell hooks: /workspace/.container

The shells' config is not baked into `~/.bashrc` (or a fish `config.fish`);
those only source a loader (`/usr/local/share/container-shell/load.{sh,fish}`,
from `container-shell/`). At every shell start the loader places the hooks
every image layer ships (`/usr/local/share/container-shell/{bash,fish}/`) in
the mounted workspace's `.container/{bash,fish}/` (host:
`~/workspace/.container/`), then sources every `*.sh` (bash) or `*.fish`
(fish) there in name order. This image's hooks are `10-ibn-dev.sh` and
`10-ibn-dev.fish`: `~/.local/bin` (pip, uv) on `PATH`, and `ibn-dist-env.*`
once `build-dist.sh` has installed it. The fish one is for an image with
fish on top (kide, whose hooks are `20-kide.*`).

- The image's hooks are the image's: a changed one is overwritten at the next
  shell start. Your own config goes into files of your own, e.g. `50-my.sh`.
- Each image only ships its own hooks; the number orders them (base images
  low). `container-shell/{sync.sh,load.*}` are the same files in ibn-dev and
  kide: keep them in step.
- `/workspace` not writable: the hooks are sourced straight from the image.
  A root shell places them too, owned by the workspace's owner.

### Libraries: built into /workspace/ibn-dist

Run once in the container (~8–9 min on 24 cores):

    build-dist.sh

It builds the libraries into `/workspace/ibn-dist/{bin,include,lib,lib64,share}`
(its default `PREFIX` is `IBN_DIST_PREFIX=/workspace/ibn-dist`), which is the
host's `~/workspace/ibn-dist`, so the result stays there for every later
container; `rm -rf ~/workspace/ibn-dist` removes it completely. Run it again
after an image update that changes `dist/`.

| What | From | In `PREFIX` |
|---|---|---|
| CMake 4.4.4 | upstream's prebuilt Linux x86_64 tarball | `bin/cmake`, `ctest`, `cpack`: first on `PATH`, ahead of RHEL's cmake 3.31 |
| onnxruntime 1.30.0 (CPU) | upstream's prebuilt Linux x64 tarball | `include/onnxruntime`, `lib64`; `find_package(onnxruntime)` → `onnxruntime::onnxruntime`, `pkg-config libonnxruntime` |
| ACE 8.0.8 + TAO 4.0.8 | source, compiled by `build-dist.sh` | `lib/libACE*`, `libTAO*`, `include/{ace,tao,orbsvcs}`, `bin/tao_idl`; TAO_IDL's headers in `share/tao/TAO_IDL/{include,be_include}` |
| OpenDDS 3.34.0 (+ RapidJSON headers) | source, compiled by `build-dist.sh` with OpenDDS's `configure` | `lib/libOpenDDS_*`, `include/dds`, `bin/opendds_idl`; `find_package(OpenDDS)` with `opendds_target_sources()` |
| PROJ 9.6.0, GEOS 3.13.1 | source, compiled by `build-dist.sh` with CMake | `lib64/libproj.so.25`, `libgeos_c.so.1`, `include/proj*.h`, `geos*.h`, `bin/projinfo` etc., `share/proj` (`proj.db`); `find_package(PROJ)`, `find_package(GEOS)` |
| GDAL 3.10.3 (with GTiff/COG) | source, compiled by `build-dist.sh` with CMake | `lib64/libgdal.so.36`, `include/gdal*.h` etc., `bin/gdalinfo` etc., `share/gdal`; `find_package(GDAL)` → `GDAL::GDAL`, `pkg-config gdal` |

ACE+TAO, OpenDDS, PROJ, GEOS and GDAL compile (release builds, no tests);
their libraries find each other through `$ORIGIN`-relative RPATHs. GDAL is
built because RHEL9's `gdal-libs` (AppStream) is a minimal build whose only
raster drivers are VRT and MEM, without GTiff. This build has the GTiff/COG
driver and GDAL's other built-in drivers. PROJ and GEOS are built because
RHEL9 has their libraries in AppStream but `proj-devel`/`geos-devel` only in
CRB, which RHEL hosts usually do not have; they are the same versions as
RHEL's (same sonames). GDAL uses its internal json-c (`json-c-devel` is CRB
only too) and libgeotiff (EPEL only), and RHEL's sqlite, libcurl, expat,
zlib and libtiff. It has the same soname as RHEL's (`libgdal.so.36`):
libraries linked against RHEL's GDAL (opencv) use this one in programs that
load it. PROJ finds `share/proj` next to its library, so it needs no
environment variable. `NO_GDAL=1 build-dist.sh` skips PROJ, GEOS and GDAL. `build-dist.sh` removes the build-tree paths OpenDDS leaves in
its installed `share/cmake/OpenDDS/config.cmake`, so the package resolves to
`PREFIX`.

`build-dist.sh` also installs `PREFIX/bin/ibn-dist-env.sh` (bash) and
`ibn-dist-env.fish` (fish). Sourced, they set the environment for building
against the libraries and running what links them: `PREFIX/bin` first on
`PATH`, `CMAKE_PREFIX_PATH=PREFIX`, `PKG_CONFIG_PATH`,
`CPLUS_INCLUDE_PATH=PREFIX/include`, `LIBRARY_PATH` and `LD_LIBRARY_PATH`
(`PREFIX/lib`, `lib64`), `ACE_ROOT`, `TAO_ROOT`, `DDS_ROOT`
(`PREFIX/share/{ace,tao,dds}`, for `opendds_idl` or MPC by hand), and
`GDAL_DATA=PREFIX/share/gdal` (GDAL's compiled-in data path is the `PREFIX`
it was built in). They find `PREFIX` from their own path, so the same file
works wherever `PREFIX` is seen, and sourcing one twice adds nothing twice.
New shells in the container source it themselves (hook `10-ibn-dev.*`); in
the shell `build-dist.sh` ran in, source it once by hand. On the host:

    . ~/workspace/ibn-dist/bin/ibn-dist-env.sh          # bash
    source ~/workspace/ibn-dist/bin/ibn-dist-env.fish   # fish

The image also sets, for programs not started from a shell:
`PATH` (`/workspace/ibn-dist/bin` first), `PKG_CONFIG_PATH` and
`LD_LIBRARY_PATH=/workspace/ibn-dist/lib:/workspace/ibn-dist/lib64`, so every
program in the container finds the libraries, also binaries built without an
RPATH (an `ld.so.conf.d` entry would not work: the libraries only show up in
the mount at run time, too late for `ldconfig`).

### Your projects: built in the container, run on the host

Build and install them to `/workspace` (`cmake --install build --prefix
/workspace`: `bin/`, `lib/` next to `ibn-dist/`); the host then runs them
against those libraries. Two conditions:

- **The host must find the libraries.** On the host they are in
  `~/workspace/ibn-dist/lib` and `lib64`, not `/workspace/…`, so link your
  programs with an RPATH relative to the binary:

      set(CMAKE_INSTALL_RPATH "$ORIGIN/../lib;$ORIGIN/../ibn-dist/lib;$ORIGIN/../ibn-dist/lib64")

  ACE, TAO, OpenDDS and GDAL are already built this way (within `ibn-dist`).
  The alternative is sourcing `ibn-dist-env.sh` on the host, which sets
  `LD_LIBRARY_PATH`.
- **The container must not be newer than the host.** Use a base image
  (`podman/base.conf`) whose RHEL9 minor version is not newer than the host's,
  because a binary built against a newer glibc or libstdc++ may not start on an
  older host. The RHEL packages the software uses (opencv, gdal-libs, Qt5, …)
  must be installed on the host too.

Gotcha: `onnxruntime_c_api.h` defines a macro `NO_EXCEPTION`, which breaks
TAO's `CORBA::exception_type` enum (`tao/Exception.h`). Keep onnxruntime and
TAO/OpenDDS headers in separate `.cpp` files (as `test/devlibs` does).

### Another base image

The Containerfile names no base image and sets up no repos itself;
`podman/base.conf` and the files in its `CONF_DIR` do, and only they change
for another base (e.g. a company RHEL9 image with its own dnf repos):

- `BASE=<image>`, read with `--build-arg-file` (podman ≥ 4.7). Default:
  `docker.io/rockylinux/rockylinux:9`. Without the file,
  `--build-arg BASE=<image>`; with neither, the build stops (no default).
- `CONF_DIR` (default `podman/conf`, relative to the repo root; it has to be
  inside the build context): files copied into the image —
  - `repos.sh`: runs as root before any `dnf install`. Default: enables CRB
    and EPEL (Rocky's stand-in for the target repos). Replace it with
    whatever the base needs so dnf finds every package the Containerfile
    installs (e.g. copying `.repo` files into `/etc/yum.repos.d/`), or with
    an empty script if the base is ready as is.
  - `ubi.repo` to `/etc/yum.repos.d/` (the repo has an empty one)
  - `pip.conf` to `/etc/pip.conf`: `index-url` (the pip package repo) and
    `cert = /etc/pki/tls/certs/ca-bundle.crt` (the system trust store)
  - `uv.toml` to `/etc/uv/uv.toml`; uv does not read `pip.conf`, so the repo
    goes here too (`[[index]]` with `default = true`), plus
    `system-certs = true`, `python-preference = "only-system"`,
    `python-downloads = "never"` and `link-mode = "copy"` (uv's cache and the
    install target are on different filesystems in the container, so
    hardlinks fail with "Failed to hardlink files")
  - `pip-server.crt`: the pip server's certificate, or the company CA that
    signed it (PEM, `BEGIN CERTIFICATE`; the build stops on anything else or
    on a private key in it). It goes into the system trust store
    (`/etc/pki/ca-trust/source/anchors/`, `update-ca-trust`), so every pip
    and uv call trusts the repo, at build time and at runtime. The repo has
    a self-signed dummy; replace it with the real one on prod.
- `PIP_INDEX_URL` (default `https://pypi.org/simple`): the pip package repo.
  `pip.conf` and `uv.toml` are templates; the build replaces
  `@PIP_INDEX_URL@` in both with it (and stops if it is empty). On prod set
  the company repo here, nothing else changes. Then `KIDE_USER` runs
  `/usr/bin/python3.12 -m pip install --user --upgrade pip uv` (the dnf
  Python by full path: pip refuses `--user` in a venv, which some base images
  put first on `PATH`).
- `KIDE_USER`, `KIDE_UID`, `KIDE_GID` (default `default`, 1001, 1001): the
  user the image runs as. Every install step runs as root; the last step
  switches to `KIDE_USER`. A base image that already has that user (e.g.
  `default` in Red Hat's application images, or kide) keeps it; set
  `KIDE_UID`/`KIDE_GID` to its uid/gid then (`podman run --rm <base> id
  default`). Otherwise it is created with them. Change the numbers in
  `--userns=keep-id:uid=…,gid=…` too if you change them here.

### kide on top

The kide repo's `podman/Containerfile.kide` adds the terminal IDE (nvim, fish,
tmux, yazi, lazygit, …) on top of any base, this image included; together
they are the complete environment. Build ibn-dev first, then, in the kide
checkout:

    podman build --build-arg-file podman/base.conf --build-arg BASE=localhost/ibn-dev -t kide -f podman/Containerfile.kide .

What the two repos share, and must keep in step:

- `KIDE_USER`/`KIDE_UID`/`KIDE_GID`: the same values in both `base.conf`
  files (kide reuses the user ibn-dev created; its fish becomes the login
  shell)
- `container-shell/{sync.sh,load.sh,load.fish}`: the same files in both
  repos. Otherwise kide knows nothing of ibn-dev: ibn-dev's hooks
  `10-ibn-dev.{sh,fish}` set its environment in kide's fish and bash, next to
  kide's `20-kide.*` ([Shell hooks](#shell-hooks-workspacecontainer))
- this file works on top of kide too: every step may run on a base that
  already has it (the user, the loader lines, `safe.directory`)

## VS Code dev container

`ibn-devcontainer` is this image as a VS Code dev container (Dev Containers
extension with podman): a thin layer adding `~/.vscode-server`, and a
`devcontainer.json` template. See [devcontainer/README.md](devcontainer/README.md).

## Testing

- `test/run.sh` builds a clean `registry.access.redhat.com/ubi9/ubi` image
  with only RPMs from its own repos (no CRB/EPEL, like the RHEL hosts), then
  runs `build-dist.sh` in it
  with `--network=none` and a read-only copy of the files git tracks (`git
  add` new files first). `test/devlibs`: the bundled cmake is 4.x and builds
  a project that finds onnxruntime and OpenDDS, generates code from an IDL
  file (tao_idl + opendds_idl) and links both; it runs, and `tao_idl` and
  `opendds_idl` still start once the build directory is gone. GDAL has GTiff,
  links the dist's PROJ/GEOS (UBI has neither) and finds `proj.db`
  (`gdalsrsinfo EPSG:25832`). The RHEL/EPEL packages (opencv etc.) are not in
  the UBI image; the next test covers them and a program using GDAL.
- `test/prodsim/run.sh` tests the workflow with a stand-in for the prod
  software (`test/prodsim`): IDL compiler on TAO's front end, CORBA, DDS,
  GDAL (GeoTIFF), onnxruntime, RapidJSON and an OpenGL viewer. It builds the
  dist libraries and the project in the ibn-dev image into a test workspace,
  then runs the pipeline in `prodsim-host`, a RHEL9 container with only the
  runtime RPMs, and checks the report and a screenshot of the viewer. See
  [test/prodsim/README.md](test/prodsim/README.md).

## Updating the pins (on a connected machine)

1. Edit `manifest/dist.tsv` (version, file, url, sha256).
2. `scripts/dist-update.sh` — the only step that downloads (curl,
   sha256sum); refreshes `dist/` and `VERSIONS`.
3. `test/run.sh` and `test/prodsim/run.sh` (after rebuilding the image) must
   pass before committing.
4. Update the table below for a new component, review `git status`, commit.

## Checksums

Every tarball in `dist/` is pinned by sha256 in `manifest/dist.tsv`.
`build-dist.sh` (offline) and `scripts/dist-update.sh` check those pins
before use. The pins themselves were checked against what upstream
publishes, where it publishes something. To repeat a check by hand, run from
the repo root (the upstream ones need network):

    # pins (offline, what build-dist.sh does first)
    awk -F'\t' '!/^#/ && NF { print $6 "  " $4 }' manifest/dist.tsv | (cd dist && sha256sum -c -)

    # cmake: upstream's SHA-256 list (signed: cmake-4.4.4-SHA-256.txt.asc)
    curl -fsSL https://github.com/Kitware/CMake/releases/download/v4.4.4/cmake-4.4.4-SHA-256.txt |
      grep ' cmake-4.4.4-linux-x86_64.tar.gz$' | (cd dist && sha256sum -c -)

    # onnxruntime: no checksum file; GitHub's asset digest of the release
    curl -fsSL https://api.github.com/repos/microsoft/onnxruntime/releases/tags/v1.30.0 |
      grep -A30 '"name": "onnxruntime-linux-x64-1.30.0.tgz"' | grep -m1 '"digest"'
    sha256sum dist/onnxruntime-linux-x64-1.30.0.tgz

    # ACE+TAO: upstream's md5 (the file names the packager's path, compare the hash)
    curl -fsSL 'https://github.com/DOCGroup/ACE_TAO/releases/download/ACE%2BTAO-8_0_8/ACE%2BTAO-src-8.0.8.tar.bz2.md5'
    md5sum dist/ACE+TAO-src-8.0.8.tar.bz2

    # OpenDDS: upstream's sha256 list
    curl -fsSL https://github.com/OpenDDS/OpenDDS/releases/download/v3.34.0/OpenDDS-3.34.0.sha256 |
      grep ' OpenDDS-3.34.0.tar.gz$' | (cd dist && sha256sum -c -)

    # RapidJSON: GitHub's archive of the pinned commit, no upstream checksum;
    # the pin is the commit id plus the sha256 recorded when it was fetched

    # PROJ: upstream's md5
    curl -fsSL https://github.com/OSGeo/PROJ/releases/download/9.6.0/proj-9.6.0.tar.gz.md5
    md5sum dist/proj-9.6.0.tar.gz

    # GEOS: no upstream checksum; the GitHub release asset and the copy on
    # download.osgeo.org are identical
    curl -fsSL https://download.osgeo.org/geos/geos-3.13.1.tar.bz2 | sha256sum
    sha256sum dist/geos-3.13.1.tar.bz2

    # GDAL: upstream's md5 (signed: gdal-3.10.3.tar.gz.sig)
    curl -fsSL https://github.com/OSGeo/gdal/releases/download/v3.10.3/gdal-3.10.3.tar.gz.md5
    md5sum dist/gdal-3.10.3.tar.gz

For a new pin, run the matching upstream check before committing.

## Moving the repo to an on-prem GitLab

The repo is plain git (no LFS, no submodules; most of its size is `dist/`,
~126 MB, largest file 65 MB). Create an **empty** project in the GitLab
(e.g. `gitlab.example.com/kreatos/ibn-dev`), then push from a clone, or carry
a git bundle over when the GitLab is only reachable from the internal network:

    git clone --mirror https://gitlab.com/kreatos/ibn-dev.git
    git -C ibn-dev.git bundle create "$PWD/ibn-dev.bundle" --branches --tags
    # inside, after copying ibn-dev.bundle over
    git clone --mirror ibn-dev.bundle ibn-dev.git
    git -C ibn-dev.git push git@gitlab.example.com:kreatos/ibn-dev.git --all
    git -C ibn-dev.git push git@gitlab.example.com:kreatos/ibn-dev.git --tags

If a push over HTTPS fails with `413` / `RPC failed`, push over SSH. Build
the image from a clone of the GitLab project; building straight from the URL
only works for a project readable without login.

## Third-party software

Everything in `dist/`, with the pinned upstream version and its license.

| Component | Upstream | Version | License |
|---|---|---|---|
| dist/ace-tao | <https://github.com/DOCGroup/ACE_TAO/releases/download/ACE%2BTAO-8_0_8/ACE%2BTAO-src-8.0.8.tar.bz2> | `8.0.8 (source)` | DOC (`ACE_wrappers/COPYING`) |
| dist/cmake | <https://github.com/Kitware/CMake/releases/download/v4.4.4/cmake-4.4.4-linux-x86_64.tar.gz> | `4.4.4 (prebuilt)` | BSD-3-Clause (`Copyright.txt`; the binary tarball bundles its third-party notices in `doc/cmake`) |
| dist/geos | <https://github.com/libgeos/geos/releases/download/3.13.1/geos-3.13.1.tar.bz2> | `3.13.1 (source)` | LGPL-2.1-or-later (`COPYING`; shared libraries, linked dynamically) |
| dist/gdal | <https://github.com/OSGeo/gdal/releases/download/v3.10.3/gdal-3.10.3.tar.gz> | `3.10.3 (source)` | MIT (`LICENSE.TXT`, which lists the few differently licensed parts, none of them built here) |
| dist/onnxruntime | <https://github.com/microsoft/onnxruntime/releases/download/v1.30.0/onnxruntime-linux-x64-1.30.0.tgz> | `1.30.0 (prebuilt)` | MIT (`LICENSE`, `ThirdPartyNotices.txt` next to it) |
| dist/opendds | <https://github.com/OpenDDS/OpenDDS/releases/download/v3.34.0/OpenDDS-3.34.0.tar.gz> | `3.34.0 (source)` | LicenseRef-OpenDDS (`LICENSE`: permissive OCI license, no SPDX id) |
| dist/proj | <https://github.com/OSGeo/PROJ/releases/download/9.6.0/proj-9.6.0.tar.gz> | `9.6.0 (source)` | MIT (`COPYING`) |
| dist/rapidjson | <https://github.com/Tencent/rapidjson/archive/fd3dc29a5c2852df569e1ea81dbde2c412ac5051.tar.gz> | `fd3dc29a5c28` | MIT (`license.txt`; `bin/jsonchecker` is under the JSON license, not used) |
