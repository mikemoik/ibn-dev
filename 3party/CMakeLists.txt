# Superbuild: installs the 3rd-party packages a prod repo ships to
# CMAKE_INSTALL_PREFIX (default /workspace/opt from the image's environment),
# before the project's own build, which then finds them with find_package:
#
#   cmake -S 3party -B build-3party && cmake --build build-3party
#
# ExternalProject installs at build time, so no `cmake --install` is needed.
# It must be a configure of its own: the project's find_package runs at
# configure time, before anything could be built. Linux and Visual Studio alike.
#
# THIRDPARTY_DIR holds the shipped packages (default: this directory):
#   sqlite/              sources with their own CMakeLists (needs install() rules)
#   eigen/{include,lib}  header-only, already in installed layout: copied as is
#   gcem/{include,lib}   ditto
# Consumers: find_package(SQLite3) -> SQLite::SQLite3 (CMake's FindSQLite3),
# find_package(Eigen3 CONFIG) -> Eigen3::Eigen, find_package(gcem CONFIG).
cmake_minimum_required(VERSION 3.24)
project(prod-3party NONE)
include(ExternalProject)

set(THIRDPARTY_DIR ${CMAKE_CURRENT_SOURCE_DIR} CACHE PATH "directory with the shipped 3rd-party packages")
set(dst ${CMAKE_INSTALL_PREFIX})

# sqlite: built and installed with its own CMakeLists; $ORIGIN: finds its own
# libraries in lib/ on the host
ExternalProject_Add(sqlite
  SOURCE_DIR ${THIRDPARTY_DIR}/sqlite
  CMAKE_ARGS -DCMAKE_INSTALL_PREFIX=${dst} -DCMAKE_BUILD_TYPE=Release
             "-DCMAKE_INSTALL_RPATH=$ORIGIN")

# eigen, gcem: copied unchanged, keeping their structure (eigen: include/eigen3/…);
# their *Targets.cmake are prefix-relative, but check shipped *.pc files for an
# absolute prefix= line
foreach(lib eigen gcem)
  ExternalProject_Add(${lib}
    SOURCE_DIR ${THIRDPARTY_DIR}/${lib}
    CONFIGURE_COMMAND "" BUILD_COMMAND ""
    INSTALL_COMMAND ${CMAKE_COMMAND} -E copy_directory <SOURCE_DIR>/include ${dst}/include
            COMMAND ${CMAKE_COMMAND} -E copy_directory <SOURCE_DIR>/lib ${dst}/lib)
endforeach()
