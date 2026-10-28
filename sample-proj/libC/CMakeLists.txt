# libC: one library target. Same shape for every library of the project:
# target, alias, properties, headers, dependencies, install into the export set.

# The target. Its plain name is prefixed (sample_c) because target names are
# global across all subdirectories, and a bare "c" easily clashes
add_library(sample_c SHARED src/c.cpp)
# The name everything else uses, in this tree and (via NAMESPACE + EXPORT_NAME)
# in consumers of the installed package alike
add_library(sample::C ALIAS sample_c)
set_target_properties(sample_c PROPERTIES
  # Name in the exported targets file: sample:: + C = sample::C
  EXPORT_NAME C
  # Output file libsample_c.so -> libsample_c.so.1 -> libsample_c.so.1.0.0
  VERSION ${PROJECT_VERSION} SOVERSION ${PROJECT_VERSION_MAJOR}
  # Windows: export all functions from the DLL, so VS produces an import .lib
  WINDOWS_EXPORT_ALL_SYMBOLS ON
  # IDE folder
  FOLDER "sample")
# Public headers as a file set: one declaration gives the include dir for
# building (BASE_DIRS), for consumers (<prefix>/include) and what to install.
# Headers live under include/sample/c/, so the installed path
# <prefix>/include/sample/c/c.hpp cannot clash with other projects' headers
target_sources(sample_c PUBLIC FILE_SET HEADERS
  BASE_DIRS include
  FILES include/sample/c/c.hpp)
# C++17 for this library and everything linking it
target_compile_features(sample_c PUBLIC cxx_std_17)
# PRIVATE sample::B: only c.cpp uses B, c.hpp does not; consumers of C
# neither see B's headers nor link it directly (it is still loaded at run time)
target_link_libraries(sample_c PRIVATE sample::B)

# Install the library and its headers, and add it to the project's export set
install(TARGETS sample_c EXPORT ${sample_export}
  ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
  LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
  RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
  # the file set: include/sample/c/c.hpp -> <prefix>/include/sample/c/c.hpp
  FILE_SET HEADERS DESTINATION ${CMAKE_INSTALL_INCLUDEDIR})
