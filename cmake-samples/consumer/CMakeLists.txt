# Sample consumer: finds the installed proj (and through its config Eigen3 and
# SQLiteCpp) in CMAKE_PREFIX_PATH, which the image's shell hook sets to
# /workspace/opt; under Visual Studio pass -DCMAKE_PREFIX_PATH=C:/…/opt.
#
#   cmake -S consumer -B build-consumer && cmake --build build-consumer && cmake --install build-consumer
cmake_minimum_required(VERSION 3.24)
project(consumer LANGUAGES CXX)

include(GNUInstallDirs)

find_package(proj 1.0 CONFIG REQUIRED)

add_executable(app main.cpp)
target_link_libraries(app PRIVATE proj::foo)
# the installed app finds libfoo in ../lib64 next to it, on the host as well
set_target_properties(app PROPERTIES
  INSTALL_RPATH "$ORIGIN/../${CMAKE_INSTALL_LIBDIR}")

install(TARGETS app RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})
