# 10-ibn-dev.fish — ibn-dev's fish hook. From the ibn-dev image (placed here at
# every shell start, a change is overwritten); your own config: a file of your own.
# pip and uv (pip install --user) in ~/.local/bin
fish_add_path -g ~/.local/bin
# the C/C++ libraries in IBN_DIST_PREFIX (CMAKE_PREFIX_PATH, CPLUS_INCLUDE_PATH,
# LIBRARY_PATH, ACE_ROOT/TAO_ROOT/DDS_ROOT, GDAL_DATA, …), once build-dist.sh
# has installed them
if set -q IBN_DIST_PREFIX; and test -f $IBN_DIST_PREFIX/bin/ibn-dist-env.fish
    source $IBN_DIST_PREFIX/bin/ibn-dist-env.fish
end
