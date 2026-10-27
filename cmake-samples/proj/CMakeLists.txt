# Sample library project: builds libfoo, installs it as package "proj" with
# GNUInstallDirs, consumers use find_package(proj CONFIG) -> proj::foo.
# Linux and Visual Studio alike:
#
#   cmake -S proj -B build-proj && cmake --build build-proj && cmake --install build-proj
#
# The prefix is CMAKE_INSTALL_PREFIX (/workspace/opt from the image's
# environment); under Visual Studio pass it with -DCMAKE_INSTALL_PREFIX=….
# Dependencies: Eigen3 (public, in foo's headers) and SQLiteCpp (private, only
# in foo.cpp), both installed by 3party/ first.
cmake_minimum_required(VERSION 3.24)
project(proj VERSION 1.0.0 LANGUAGES CXX)

include(GNUInstallDirs)
include(CMakePackageConfigHelpers)

# IDE solution folders (VS, Xcode); the default from CMake 3.26 on (CMP0143)
set_property(GLOBAL PROPERTY USE_FOLDERS ON)

# Build tree in the same layout as the install tree (lib64 on RHEL), so the
# relative RPATH below works in both. ARCHIVE: .a/.lib and DLL import .lib,
# LIBRARY: .so, RUNTIME: executables and .dll. Under the build dir, never the
# install prefix: only install() writes there
set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/${CMAKE_INSTALL_LIBDIR})
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/${CMAKE_INSTALL_LIBDIR})
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/${CMAKE_INSTALL_BINDIR})

find_package(Eigen3 CONFIG REQUIRED)
find_package(SQLiteCpp CONFIG REQUIRED)

add_library(foo SHARED src/foo.cpp)
# same name in-tree (add_subdirectory) as for find_package consumers
add_library(proj::foo ALIAS foo)
set_target_properties(foo PROPERTIES
  VERSION ${PROJECT_VERSION} SOVERSION ${PROJECT_VERSION_MAJOR}
  WINDOWS_EXPORT_ALL_SYMBOLS ON
  FOLDER "proj")
# BUILD_INTERFACE: only in this build; consumers get the installed include dir
target_include_directories(foo PUBLIC
  $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
  $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>)
target_compile_features(foo PUBLIC cxx_std_17)
# SQLiteCpp is static: it needs PIC to be linked into a shared libfoo
target_link_libraries(foo PUBLIC Eigen3::Eigen PRIVATE SQLiteCpp)

install(TARGETS foo EXPORT proj
  ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
  LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
  RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})
install(DIRECTORY include/ DESTINATION ${CMAKE_INSTALL_INCLUDEDIR})

# Package config: lib*/cmake/<name>/ is on find_package's search path on every
# platform (a top-level cmake/ only on Windows). No export(): consumers build
# against the installed prefix, never against this build tree
set(config_dir ${CMAKE_INSTALL_LIBDIR}/cmake/proj)
install(EXPORT proj
  NAMESPACE proj::
  FILE projTargets.cmake
  DESTINATION ${config_dir})
configure_package_config_file(cmake/projConfig.cmake.in
  ${CMAKE_CURRENT_BINARY_DIR}/projConfig.cmake
  INSTALL_DESTINATION ${config_dir})
write_basic_package_version_file(${CMAKE_CURRENT_BINARY_DIR}/projConfigVersion.cmake
  COMPATIBILITY SameMajorVersion)
install(FILES
  ${CMAKE_CURRENT_BINARY_DIR}/projConfig.cmake
  ${CMAKE_CURRENT_BINARY_DIR}/projConfigVersion.cmake
  DESTINATION ${config_dir})
