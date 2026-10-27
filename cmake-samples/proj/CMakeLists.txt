# Sample library project: builds libfoo, installs it as package "proj" with
# GNUInstallDirs, consumers use find_package(proj CONFIG) -> proj::foo.
# Linux and Visual Studio alike:
#
#   cmake -S proj -B build-proj && cmake --build build-proj && cmake --install build-proj
#
# The three steps: configure (-S source dir, -B build dir: CMake reads this
# file and writes Makefiles/Ninja files/a VS solution into build-proj/), build
# (compiles into build-proj/), install (copies the results into the prefix).
# The prefix is CMAKE_INSTALL_PREFIX (/workspace/opt from the image's
# environment); under Visual Studio pass it with -DCMAKE_INSTALL_PREFIX=….
# Dependencies: Eigen3 (public, in foo's headers) and SQLiteCpp (private, only
# in foo.cpp), both installed by 3party/ first.

# Oldest CMake this file works with; also switches on the behavior (policies)
# of that version, so newer CMakes don't change how the file is understood
cmake_minimum_required(VERSION 3.24)
# Project name (also ${PROJECT_NAME}), version (${PROJECT_VERSION}, split into
# ${PROJECT_VERSION_MAJOR} etc.) and language: C++ only, so CMake looks for a
# C++ compiler and nothing else
project(proj VERSION 1.0.0 LANGUAGES CXX)

# Standard install directory names as variables: CMAKE_INSTALL_LIBDIR (lib64
# on RHEL, lib elsewhere), CMAKE_INSTALL_BINDIR (bin), CMAKE_INSTALL_INCLUDEDIR
# (include), CMAKE_INSTALL_DATADIR (share). Paths relative to the prefix
include(GNUInstallDirs)
# Helpers for writing a package config: configure_package_config_file and
# write_basic_package_version_file, used at the end of this file
include(CMakePackageConfigHelpers)

# IDE solution folders (VS, Xcode): targets are grouped by their FOLDER
# property instead of one flat list. No effect on Makefiles/Ninja. The default
# from CMake 3.26 on (CMP0143); needed here because the minimum is 3.24
set_property(GLOBAL PROPERTY USE_FOLDERS ON)

# Where the build puts its results inside the build dir. Without these they
# land next to each CMakeLists in the build dir, scattered. Same layout as the
# install tree (lib64 on RHEL), so the relative RPATH works in both.
# ARCHIVE: static libraries (.a; on Windows .lib, also a DLL's import .lib)
set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/${CMAKE_INSTALL_LIBDIR})
# LIBRARY: shared libraries (.so; on Windows only MODULE libraries)
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/${CMAKE_INSTALL_LIBDIR})
# RUNTIME: executables, and on Windows the .dll files.
# All three under the build dir (CMAKE_BINARY_DIR), never the install prefix:
# only install() writes there
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/${CMAKE_INSTALL_BINDIR})

# Find the installed dependencies. CONFIG: use the package's own
# <Name>Config.cmake (shipped by Eigen/SQLiteCpp), searched in every directory
# of CMAKE_PREFIX_PATH (here /workspace/opt). REQUIRED: stop with an error if
# it is missing, instead of continuing without it. Each defines imported
# targets: Eigen3::Eigen, SQLiteCpp
find_package(Eigen3 CONFIG REQUIRED)
find_package(SQLiteCpp CONFIG REQUIRED)

# A target: the library foo, built from src/foo.cpp. SHARED: libfoo.so
# (foo.dll on Windows); STATIC would give libfoo.a. The file name gets the
# platform's prefix/suffix automatically
add_library(foo SHARED src/foo.cpp)
# Second name for the same target. Consumers of the installed package see
# proj::foo (the NAMESPACE below), so code in this same source tree
# (add_subdirectory) can use the same name. :: names also give an error when
# misspelled, plain names are silently taken as a file name to link
add_library(proj::foo ALIAS foo)
# Properties of the target:
set_target_properties(foo PROPERTIES
  # libfoo.so.1.0.0 (VERSION) with the link libfoo.so.1 (SOVERSION, what
  # programs record and load at run time) and libfoo.so (used when linking)
  VERSION ${PROJECT_VERSION} SOVERSION ${PROJECT_VERSION_MAJOR}
  # Windows only: export all functions from the DLL without __declspec
  # (dllexport) in the code; without exports VS produces no import .lib
  WINDOWS_EXPORT_ALL_SYMBOLS ON
  # The IDE folder foo appears in (USE_FOLDERS above)
  FOLDER "proj")
# Include directories of foo. PUBLIC: for foo itself and for everything that
# links foo (the header uses Eigen, so consumers need it too). The two
# generator expressions give different paths for the two cases:
target_include_directories(foo PUBLIC
  # while building this project: the headers in the source tree
  $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
  # for consumers of the installed package: <prefix>/include
  $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>)
# Require C++17 for foo and (PUBLIC) for everything linking it. Better than
# setting -std=c++17 by hand: CMake picks the right flag per compiler
target_compile_features(foo PUBLIC cxx_std_17)
# Link dependencies; this also brings their include dirs and flags along.
# PUBLIC Eigen3::Eigen: foo's header includes Eigen, so consumers get it too.
# PRIVATE SQLiteCpp: only foo.cpp uses it, consumers neither see nor need it.
# SQLiteCpp is static: it needs PIC to be linked into a shared libfoo
target_link_libraries(foo PUBLIC Eigen3::Eigen PRIVATE SQLiteCpp)

# What `cmake --install` copies, and where (relative to the prefix).
# EXPORT proj: also record foo in the export set "proj", from which
# install(EXPORT) below writes the targets file for consumers
install(TARGETS foo EXPORT proj
  # static libraries and Windows import .lib -> <prefix>/lib64
  ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
  # shared libraries .so -> <prefix>/lib64
  LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
  # executables and Windows .dll -> <prefix>/bin
  RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})
# Copy the public headers: include/proj/foo.hpp -> <prefix>/include/proj/foo.hpp
# (the trailing / copies the directory's content, not the directory itself)
install(DIRECTORY include/ DESTINATION ${CMAKE_INSTALL_INCLUDEDIR})

# Package config, so consumers can write find_package(proj). lib*/cmake/<name>/
# is on find_package's search path on every platform (a top-level cmake/ only
# on Windows). No export(): consumers build against the installed prefix,
# never against this build tree
set(config_dir ${CMAKE_INSTALL_LIBDIR}/cmake/proj)
# Write the targets file: the imported target proj::foo with its installed
# paths, include dirs and dependencies, relative to the prefix (relocatable)
install(EXPORT proj
  # prefix for the target names: foo becomes proj::foo for consumers
  NAMESPACE proj::
  # file name; projConfig.cmake includes it
  FILE projTargets.cmake
  # -> <prefix>/lib64/cmake/proj/projTargets.cmake
  DESTINATION ${config_dir})
# Generate projConfig.cmake (what find_package(proj) loads) from the template
# cmake/projConfig.cmake.in, filling in @PACKAGE_INIT@; written into the build
# dir, installed below
configure_package_config_file(cmake/projConfig.cmake.in
  ${CMAKE_CURRENT_BINARY_DIR}/projConfig.cmake
  # where it will be installed, so the paths in it work relative to there
  INSTALL_DESTINATION ${config_dir})
# Generate projConfigVersion.cmake: lets find_package(proj 1.0) check the
# version. SameMajorVersion: 1.x satisfies a request for 1.0, 2.0 does not
write_basic_package_version_file(${CMAKE_CURRENT_BINARY_DIR}/projConfigVersion.cmake
  COMPATIBILITY SameMajorVersion)
# Install both generated files next to projTargets.cmake
install(FILES
  ${CMAKE_CURRENT_BINARY_DIR}/projConfig.cmake
  ${CMAKE_CURRENT_BINARY_DIR}/projConfigVersion.cmake
  DESTINATION ${config_dir})
