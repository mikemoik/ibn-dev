# Sample project split into three libraries: libA, libB (uses A), libC (uses B).
# One CMake project, one directory and one target per library; installed as a
# single package "sample" with the components A, B, C, so consumers write
#
#   find_package(sample 1.0 CONFIG REQUIRED COMPONENTS C)
#   target_link_libraries(app PRIVATE sample::C)
#
# Build and install, Linux and Visual Studio alike:
#
#   cmake -S sample-proj -B build-sample && cmake --build build-sample && cmake --install build-sample
#
# The basics (GNUInstallDirs, output dirs, install(EXPORT), package config) are
# explained line by line in cmake-samples/proj; comments here focus on what
# changes with several libraries.

# Oldest CMake this file works with; 3.23 is needed for FILE_SET HEADERS
cmake_minimum_required(VERSION 3.24)
# Project name (= package name), version, language
project(sample VERSION 1.0.0 LANGUAGES CXX)

# CMAKE_INSTALL_LIBDIR, CMAKE_INSTALL_BINDIR, CMAKE_INSTALL_INCLUDEDIR, …
include(GNUInstallDirs)
# configure_package_config_file, write_basic_package_version_file
include(CMakePackageConfigHelpers)

# IDE solution folders (VS): each library's FOLDER property groups it
set_property(GLOBAL PROPERTY USE_FOLDERS ON)

# Build results in the install layout inside the build dir (see cmake-samples/proj).
# Set here, before add_subdirectory, so all three libraries land in the same
# lib64/ and bin/ instead of one directory per subproject
set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/${CMAKE_INSTALL_LIBDIR})
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/${CMAKE_INSTALL_LIBDIR})
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/${CMAKE_INSTALL_BINDIR})

# RPATH of the installed libraries: $ORIGIN is the library's own directory.
# Needed as soon as one library loads another privately: libsample_c.so
# needs libsample_b.so at run time, but an app linking only sample::C has no
# RPATH entry for it; with this, libsample_c finds its sibling itself
set(CMAKE_INSTALL_RPATH "$ORIGIN")

# Switch for an optional library: -DSAMPLE_BUILD_LIBC=OFF skips libC.
# Options are cache variables: set once at configure time, remembered after
option(SAMPLE_BUILD_LIBC "Build libC" ON)

# Name of the export set every library adds its target to (install(TARGETS …
# EXPORT ${sample_export}) in each subdirectory); written out once below
set(sample_export sampleTargets)

# Process each library's CMakeLists.txt. Order matters only for plain
# variables; targets can be linked before they are defined, but listing
# dependencies first (A before B before C) keeps it readable
add_subdirectory(libA)
add_subdirectory(libB)
# Optional library: not built, not installed, not in the package when OFF
if(SAMPLE_BUILD_LIBC)
  add_subdirectory(libC)
endif()

# Package config for all libraries together
set(config_dir ${CMAKE_INSTALL_LIBDIR}/cmake/sample)
# One targets file with every library of the export set: sample::A, sample::B,
# sample::C and the links between them. NAMESPACE sample:: plus each target's
# EXPORT_NAME (A, B, C) gives the names consumers use
install(EXPORT ${sample_export}
  NAMESPACE sample::
  FILE sampleTargets.cmake
  DESTINATION ${config_dir})
# sampleConfig.cmake from the template (checks the requested COMPONENTS)
configure_package_config_file(cmake/sampleConfig.cmake.in
  ${CMAKE_CURRENT_BINARY_DIR}/sampleConfig.cmake
  INSTALL_DESTINATION ${config_dir})
# sampleConfigVersion.cmake: find_package(sample 1.0) accepts 1.x
write_basic_package_version_file(${CMAKE_CURRENT_BINARY_DIR}/sampleConfigVersion.cmake
  COMPATIBILITY SameMajorVersion)
# Install both next to sampleTargets.cmake
install(FILES
  ${CMAKE_CURRENT_BINARY_DIR}/sampleConfig.cmake
  ${CMAKE_CURRENT_BINARY_DIR}/sampleConfigVersion.cmake
  DESTINATION ${config_dir})
