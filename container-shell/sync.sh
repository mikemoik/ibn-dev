# container-shell/sync.sh — the same file in the ibn-dev and kide repos: keep
# them in step. Run by load.sh/load.fish at every shell start.
# Copies the hooks every image layer ships in /usr/local/share/container-shell/
# {bash,fish}/NN-name.{sh,fish} (ibn-dev 10-ibn-dev.*, kide 20-kide.*) to the
# mounted workspace's /workspace/.container/{bash,fish}/, where the shells
# source them. They belong to the image: a changed one is overwritten. Your
# own config goes into files of your own there (other names, e.g. 50-my.fish).
# Exit 1 (nothing copied) when /workspace is not writable.
src=/usr/local/share/container-shell
[ -w /workspace ] || exit 1
for sh in bash fish; do
  for f in "$src/$sh"/*; do
    [ -f "$f" ] || continue
    mkdir -p "/workspace/.container/$sh"
    cp -f "$f" "/workspace/.container/$sh/"
  done
done
# a root shell: the files belong to the workspace's owner (KIDE_USER, i.e. you
# on the host), not to a subuid of root
[ "$(id -u)" -ne 0 ] || chown -R --reference=/workspace /workspace/.container
exit 0
