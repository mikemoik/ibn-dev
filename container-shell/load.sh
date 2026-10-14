# container-shell/load.sh — the same file in the ibn-dev and kide repos: keep
# them in step. Sourced from ~/.bashrc (KIDE_USER and root): places the
# image's hooks in /workspace/.container/bash/ (sync.sh), then sources every
# *.sh there in name order — the image's (10-ibn-dev.sh, 20-kide.sh) and your
# own. /workspace not writable: the image's hooks straight from the image.
if sh /usr/local/share/container-shell/sync.sh; then
  _cs_dir=/workspace/.container/bash
else
  _cs_dir=/usr/local/share/container-shell/bash
fi
for _cs_f in "$_cs_dir"/*.sh; do
  [ -f "$_cs_f" ] && . "$_cs_f"
done
unset _cs_dir _cs_f
# no proxy at runtime (fallback for podman run without --http-proxy=false;
# podman build passes them to the RUN steps, so dnf/pip may use them)
unset http_proxy https_proxy ftp_proxy all_proxy no_proxy HTTP_PROXY HTTPS_PROXY FTP_PROXY ALL_PROXY NO_PROXY
