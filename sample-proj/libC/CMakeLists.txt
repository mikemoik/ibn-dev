# libC: one library target. Same shape for every library of the project:
# target, alias, properties, headers, dependencies, install into the export set.

# The target. Its plain name is prefixed (proj_c) because target names are
# global across all subdirectories, and a bare "c" easily clashes
add_library(proj_c SHARED src/c.cpp)
# The name everything else uses, in this tree and (via NAMESPACE + EXPORT_NAME)
# in consumers of the installed package alike
add_library(proj::C ALIAS proj_c)
set_target_properties(proj_c PROPERTIES
  # Name in the exported targets file: proj:: + C = proj::C
  EXPORT_NAME C
  # Output file libproj_c.so -> libproj_c.so.1 -> libproj_c.so.1.0.0
  VERSION ${PROJECT_VERSION} SOVERSION ${PROJECT_VERSION_MAJOR}
  # Windows: export all functions from the DLL, so VS produces an import .lib
  WINDOWS_EXPORT_ALL_SYMBOLS ON
  # IDE folder
  FOLDER "proj")
# Public headers as a file set: one declaration gives the include dir for
# building (BASE_DIRS), for consumers (<prefix>/include) and what to install.
# Headers live under include/proj/c/, so the installed path
# <prefix>/include/proj/c/c.hpp cannot clash with other projects' headers
target_sources(proj_c PUBLIC FILE_SET HEADERS
  BASE_DIRS include
  FILES include/proj/c/c.hpp)
# C++17 for this library and everything linking it
target_compile_features(proj_c PUBLIC cxx_std_17)
# PRIVATE proj::B: only c.cpp uses B, c.hpp does not; consumers of C
# neither see B's headers nor link it directly (it is still loaded at run time)
target_link_libraries(proj_c PRIVATE proj::B)

# Install the library and its headers, and add it to the project's export set
install(TARGETS proj_c EXPORT ${proj_export}
  ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
  LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
  RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
  # the file set: include/proj/c/c.hpp -> <prefix>/include/proj/c/c.hpp
  FILE_SET HEADERS DESTINATION ${CMAKE_INSTALL_INCLUDEDIR})
