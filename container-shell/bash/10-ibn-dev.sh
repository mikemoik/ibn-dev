# 10-ibn-dev.sh — ibn-dev's bash hook. From the ibn-dev image (placed here at
# every shell start, a change is overwritten); your own config: a file of your own.
# pip and uv (pip install --user) in ~/.local/bin
case ":$PATH:" in
  *":$HOME/.local/bin:"*) ;;
  *) PATH="$HOME/.local/bin:$PATH" ;;
esac
# the C/C++ libraries in IBN_DIST_PREFIX (CMAKE_PREFIX_PATH, CPLUS_INCLUDE_PATH,
# LIBRARY_PATH, ACE_ROOT/TAO_ROOT/DDS_ROOT, GDAL_DATA, …), once build-dist.sh
# has installed them
if [ -n "${IBN_DIST_PREFIX:-}" ] && [ -f "$IBN_DIST_PREFIX/bin/ibn-dist-env.sh" ]; then
  . "$IBN_DIST_PREFIX/bin/ibn-dist-env.sh"
fi
