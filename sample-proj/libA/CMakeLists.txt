# libA: one library target. Same shape for every library of the project:
# target, alias, properties, headers, dependencies, install into the export set.

# The target. Its plain name is prefixed (sample_a) because target names are
# global across all subdirectories, and a bare "a" easily clashes
add_library(sample_a SHARED src/a.cpp)
# The name everything else uses, in this tree and (via NAMESPACE + EXPORT_NAME)
# in consumers of the installed package alike
add_library(sample::A ALIAS sample_a)
set_target_properties(sample_a PROPERTIES
  # Name in the exported targets file: sample:: + A = sample::A
  EXPORT_NAME A
  # Output file libsample_a.so -> libsample_a.so.1 -> libsample_a.so.1.0.0
  VERSION ${PROJECT_VERSION} SOVERSION ${PROJECT_VERSION_MAJOR}
  # Windows: export all functions from the DLL, so VS produces an import .lib
  WINDOWS_EXPORT_ALL_SYMBOLS ON
  # IDE folder
  FOLDER "sample")
# Public headers as a file set: one declaration gives the include dir for
# building (BASE_DIRS), for consumers (<prefix>/include) and what to install.
# Headers live under include/sample/a/, so the installed path
# <prefix>/include/sample/a/a.hpp cannot clash with other projects' headers
target_sources(sample_a PUBLIC FILE_SET HEADERS
  BASE_DIRS include
  FILES include/sample/a/a.hpp)
# C++17 for this library and everything linking it
target_compile_features(sample_a PUBLIC cxx_std_17)
# No dependencies on other libraries

# Install the library and its headers, and add it to the project's export set
install(TARGETS sample_a EXPORT ${sample_export}
  ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
  LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
  RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
  # the file set: include/sample/a/a.hpp -> <prefix>/include/sample/a/a.hpp
  FILE_SET HEADERS DESTINATION ${CMAKE_INSTALL_INCLUDEDIR})
