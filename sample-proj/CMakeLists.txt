# Sample project split into three libraries: libA, libB (uses A), libC (uses B).
# One CMake project, one directory and one target per library; installed as a
# single package "proj" with the components A, B, C, so consumers write
#
#   find_package(proj 1.0 CONFIG REQUIRED COMPONENTS C)
#   target_link_libraries(app PRIVATE proj::C)
#
# Build and install, Linux and Visual Studio alike:
#
#   cmake -S sample-proj -B build-proj && cmake --build build-proj && cmake --install build-proj
#
# The basics (GNUInstallDirs, output dirs, install(EXPORT), package config) are
# explained line by line in cmake-samples/proj; comments here focus on what
# changes with several libraries. consumer/ is a separate project using the
# installed package.

# Oldest CMake this file works with; 3.23 is needed for FILE_SET HEADERS
cmake_minimum_required(VERSION 3.24)
# Project name (= package name), version, language
project(proj VERSION 1.0.0 LANGUAGES CXX)

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
# Needed as soon as one library loads another privately: libproj_c.so
# needs libproj_b.so at run time, but an app linking only proj::C has no
# RPATH entry for it; with this, libproj_c finds its sibling itself
set(CMAKE_INSTALL_RPATH "$ORIGIN")

# Switch for an optional library: -DPROJ_BUILD_LIBC=OFF skips libC.
# Options are cache variables: set once at configure time, remembered after
option(PROJ_BUILD_LIBC "Build libC" ON)

# Name of the export set every library adds its target to (install(TARGETS …
# EXPORT ${proj_export}) in each subdirectory); written out once below
set(proj_export projTargets)

# Process each library's CMakeLists.txt. Order matters only for plain
# variables; targets can be linked before they are defined, but listing
# dependencies first (A before B before C) keeps it readable
add_subdirectory(libA)
add_subdirectory(libB)
# Optional library: not built, not installed, not in the package when OFF
if(PROJ_BUILD_LIBC)
  add_subdirectory(libC)
endif()

# Package config for all libraries together
set(config_dir ${CMAKE_INSTALL_LIBDIR}/cmake/proj)
# One targets file with every library of the export set: proj::A, proj::B,
# proj::C and the links between them. NAMESPACE proj:: plus each target's
# EXPORT_NAME (A, B, C) gives the names consumers use
install(EXPORT ${proj_export}
  NAMESPACE proj::
  FILE projTargets.cmake
  DESTINATION ${config_dir})
# projConfig.cmake from the template (checks the requested COMPONENTS)
configure_package_config_file(cmake/projConfig.cmake.in
  ${CMAKE_CURRENT_BINARY_DIR}/projConfig.cmake
  INSTALL_DESTINATION ${config_dir})
# projConfigVersion.cmake: find_package(proj 1.0) accepts 1.x
write_basic_package_version_file(${CMAKE_CURRENT_BINARY_DIR}/projConfigVersion.cmake
  COMPATIBILITY SameMajorVersion)
# Install both next to projTargets.cmake
install(FILES
  ${CMAKE_CURRENT_BINARY_DIR}/projConfig.cmake
  ${CMAKE_CURRENT_BINARY_DIR}/projConfigVersion.cmake
  DESTINATION ${config_dir})
