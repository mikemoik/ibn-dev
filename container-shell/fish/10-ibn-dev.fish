# 10-ibn-dev.fish — ibn-dev's fish hook. From the ibn-dev image (placed here at
# every shell start, a change is overwritten); your own config: a file of your own.
# pip and uv (pip install --user) in ~/.local/bin
fish_add_path -g ~/.local/bin
# your prod projects, installed to IBN_OPT_PREFIX (/workspace/opt; cmake
# installs there by default via CMAKE_INSTALL_PREFIX): found by CMake,
# pkg-config, the compiler and linker and at run time, after the dist libraries
# below (which go in front of them) and before RHEL's
if set -q IBN_OPT_PREFIX
    set -l p $IBN_OPT_PREFIX
    # VAR DIR…: the DIRs at the front of the path variable VAR, each once
    function __ibn_opt_prepend -a var
        set -l dirs $argv[2..]
        set -l rest
        for d in $$var
            contains -- $d $dirs; or set -a rest $d
        end
        set -gx $var $dirs $rest
    end
    __ibn_opt_prepend PATH $p/bin
    __ibn_opt_prepend CMAKE_PREFIX_PATH $p
    __ibn_opt_prepend PKG_CONFIG_PATH $p/lib64/pkgconfig $p/lib/pkgconfig
    __ibn_opt_prepend CPLUS_INCLUDE_PATH $p/include
    __ibn_opt_prepend LIBRARY_PATH $p/lib64 $p/lib
    __ibn_opt_prepend LD_LIBRARY_PATH $p/lib64 $p/lib
    set -q CMAKE_INSTALL_PREFIX; or set -gx CMAKE_INSTALL_PREFIX $p
    functions -e __ibn_opt_prepend
end
# the C/C++ libraries in IBN_DIST_PREFIX (CMAKE_PREFIX_PATH, CPLUS_INCLUDE_PATH,
# LIBRARY_PATH, ACE_ROOT/TAO_ROOT/DDS_ROOT, GDAL_DATA, …), once build-dist.sh
# has installed them
if set -q IBN_DIST_PREFIX; and test -f $IBN_DIST_PREFIX/bin/ibn-dist-env.fish
    source $IBN_DIST_PREFIX/bin/ibn-dist-env.fish
end
