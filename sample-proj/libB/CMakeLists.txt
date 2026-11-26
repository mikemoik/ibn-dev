# libB: one library target. Same shape for every library of the project:
# target, alias, properties, headers, dependencies, install into the export set.

# The target. Its plain name is prefixed (proj_b) because target names are
# global across all subdirectories, and a bare "b" easily clashes
add_library(proj_b SHARED src/b.cpp)
# The name everything else uses, in this tree and (via NAMESPACE + EXPORT_NAME)
# in consumers of the installed package alike
add_library(proj::B ALIAS proj_b)
set_target_properties(proj_b PROPERTIES
  # Name in the exported targets file: proj:: + B = proj::B
  EXPORT_NAME B
  # Output file libproj_b.so -> libproj_b.so.1 -> libproj_b.so.1.0.0
  VERSION ${PROJECT_VERSION} SOVERSION ${PROJECT_VERSION_MAJOR}
  # Windows: export all functions from the DLL, so VS produces an import .lib
  WINDOWS_EXPORT_ALL_SYMBOLS ON
  # IDE folder
  FOLDER "proj")
# Public headers as a file set: one declaration gives the include dir for
# building (BASE_DIRS), for consumers (<prefix>/include) and what to install.
# Headers live under include/proj/b/, so the installed path
# <prefix>/include/proj/b/b.hpp cannot clash with other projects' headers
target_sources(proj_b PUBLIC FILE_SET HEADERS
  BASE_DIRS include
  FILES include/proj/b/b.hpp)
# C++17 for this library and everything linking it
target_compile_features(proj_b PUBLIC cxx_std_17)
# PUBLIC proj::A: b.hpp includes a.hpp, so whoever links B gets A's
# include dir and library too (transitively, also from the installed package)
target_link_libraries(proj_b PUBLIC proj::A)

# Install the library and its headers, and add it to the project's export set
install(TARGETS proj_b EXPORT ${proj_export}
  ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
  LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
  RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
  # the file set: include/proj/b/b.hpp -> <prefix>/include/proj/b/b.hpp
  FILE_SET HEADERS DESTINATION ${CMAKE_INSTALL_INCLUDEDIR})
