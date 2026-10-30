# container-shell/load.fish — the same file in the ibn-dev and kide repos: keep
# them in step. Sourced from ~/.config/fish/config.fish (IBNDEV_USER and root):
# places the image's hooks in /workspace/.container/fish/ (sync.sh), then
# sources every *.fish there in name order — the image's (10-ibn-dev.fish,
# 20-kide.fish) and your own. /workspace not writable: the image's hooks
# straight from the image.
set -l dir /workspace/.container/fish
sh /usr/local/share/container-shell/sync.sh; or set dir /usr/local/share/container-shell/fish
for f in $dir/*.fish
    source $f
end
# no proxy at runtime (fallback for podman run without --http-proxy=false;
# podman build passes them to the RUN steps, so dnf/pip may use them)
set -e http_proxy https_proxy ftp_proxy all_proxy no_proxy HTTP_PROXY HTTPS_PROXY FTP_PROXY ALL_PROXY NO_PROXY
