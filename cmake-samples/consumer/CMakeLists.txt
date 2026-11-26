# Sample consumer: finds the installed proj (and through its config Eigen3 and
# SQLiteCpp) in CMAKE_PREFIX_PATH, which the image's shell hook sets to
# /workspace/opt; under Visual Studio pass -DCMAKE_PREFIX_PATH=C:/…/opt.
#
#   cmake -S consumer -B build-consumer && cmake --build build-consumer && cmake --install build-consumer

# Oldest CMake this file works with, and the behavior (policies) of that version
cmake_minimum_required(VERSION 3.24)
# Project name and language (C++ only)
project(consumer LANGUAGES CXX)

# Standard install directory names: CMAKE_INSTALL_BINDIR, CMAKE_INSTALL_LIBDIR, …
include(GNUInstallDirs)

# Find the installed package proj: loads <prefix>/lib64/cmake/proj/projConfig.cmake,
# which finds Eigen3 and SQLiteCpp and defines proj::foo. 1.0: minimum version,
# checked by projConfigVersion.cmake. CONFIG: only package configs, no
# Find<Name>.cmake modules. REQUIRED: error if not found
find_package(proj 1.0 CONFIG REQUIRED)

# A target: the executable app, built from main.cpp
add_executable(app main.cpp)
# Link proj::foo; this also brings its include dir, C++17 and (public) Eigen
# along. PRIVATE: nothing links app, so nothing is passed on
target_link_libraries(app PRIVATE proj::foo)
# RPATH: where the installed app looks for shared libraries at run time.
# $ORIGIN is the app's own directory, so <prefix>/bin/app finds libfoo in
# <prefix>/lib64, wherever the prefix is: in the container and on the host
set_target_properties(app PROPERTIES
  INSTALL_RPATH "$ORIGIN/../${CMAKE_INSTALL_LIBDIR}")

# `cmake --install` copies app to <prefix>/bin
install(TARGETS app RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})
