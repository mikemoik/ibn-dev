# 10-ibn-dev.sh — ibn-dev's bash hook. From the ibn-dev image (placed here at
# every shell start, a change is overwritten); your own config: a file of your own.
# pip and uv (pip install --user) in ~/.local/bin
case ":$PATH:" in
  *":$HOME/.local/bin:"*) ;;
  *) PATH="$HOME/.local/bin:$PATH" ;;
esac
# your prod projects, installed to IBN_OPT_PREFIX (/workspace/opt; cmake
# installs there by default via CMAKE_INSTALL_PREFIX): found by CMake,
# pkg-config, the compiler and linker and at run time, after the dist libraries
# below (which go in front of them) and before RHEL's
if [ -n "${IBN_OPT_PREFIX:-}" ]; then
  _ibn_opt_prepend() { # VAR DIR: DIR at the front of the :-list VAR, once
    local val=":${!1-}:"
    val=${val//:$2:/:}
    val=${val#:}
    val=${val%:}
    export "$1=$2${val:+:$val}"
  }
  _ibn_opt_prepend PATH "$IBN_OPT_PREFIX/bin"
  _ibn_opt_prepend CMAKE_PREFIX_PATH "$IBN_OPT_PREFIX"
  _ibn_opt_prepend PKG_CONFIG_PATH "$IBN_OPT_PREFIX/lib/pkgconfig"
  _ibn_opt_prepend PKG_CONFIG_PATH "$IBN_OPT_PREFIX/lib64/pkgconfig"
  _ibn_opt_prepend CPLUS_INCLUDE_PATH "$IBN_OPT_PREFIX/include"
  _ibn_opt_prepend LIBRARY_PATH "$IBN_OPT_PREFIX/lib"
  _ibn_opt_prepend LIBRARY_PATH "$IBN_OPT_PREFIX/lib64"
  _ibn_opt_prepend LD_LIBRARY_PATH "$IBN_OPT_PREFIX/lib"
  _ibn_opt_prepend LD_LIBRARY_PATH "$IBN_OPT_PREFIX/lib64"
  export CMAKE_INSTALL_PREFIX="${CMAKE_INSTALL_PREFIX:-$IBN_OPT_PREFIX}"
  unset -f _ibn_opt_prepend
fi
# the C/C++ libraries in IBN_DIST_PREFIX (CMAKE_PREFIX_PATH, CPLUS_INCLUDE_PATH,
# LIBRARY_PATH, ACE_ROOT/TAO_ROOT/DDS_ROOT, GDAL_DATA, …), once build-dist.sh
# has installed them
if [ -n "${IBN_DIST_PREFIX:-}" ] && [ -f "$IBN_DIST_PREFIX/bin/ibn-dist-env.sh" ]; then
  . "$IBN_DIST_PREFIX/bin/ibn-dist-env.sh"
fi
