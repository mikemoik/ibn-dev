# Sample consumer of the installed package proj (../): a separate project,
# built against the install prefix, never against sample-proj's build tree.
# CMAKE_PREFIX_PATH must contain the prefix (/workspace/opt via the image's
# shell hook; under Visual Studio pass -DCMAKE_PREFIX_PATH=C:/…/opt).
#
#   cmake -S consumer -B build-consumer && cmake --build build-consumer && cmake --install build-consumer

# Oldest CMake this file works with, and the behavior (policies) of that version
cmake_minimum_required(VERSION 3.24)
# Project name and language (C++ only)
project(consumer LANGUAGES CXX)

# Standard install directory names: CMAKE_INSTALL_BINDIR, CMAKE_INSTALL_LIBDIR, …
include(GNUInstallDirs)

# Find the installed package: loads <prefix>/lib64/cmake/proj/projConfig.cmake.
# COMPONENTS: the libraries this app needs; find_package fails if one is
# missing (e.g. C from an install built with -DPROJ_BUILD_LIBC=OFF).
# A is not listed: it comes along through B (PUBLIC dependency)
find_package(proj 1.0 CONFIG REQUIRED COMPONENTS B C)

# The executable app, built from main.cpp
add_executable(app main.cpp)
# Link C and B. B has to be named although C uses it: C links B PRIVATE, so
# linking only proj::C gives no access to B's headers. A needs no entry,
# proj::B passes it on. PRIVATE: nothing links app
target_link_libraries(app PRIVATE proj::C proj::B)
# RPATH of the installed app: <prefix>/bin/app finds the libraries in
# <prefix>/lib64, wherever the prefix is (container and host)
set_target_properties(app PROPERTIES
  INSTALL_RPATH "$ORIGIN/../${CMAKE_INSTALL_LIBDIR}")

# `cmake --install` copies app to <prefix>/bin
install(TARGETS app RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})
