include(cmake/SystemLink.cmake)
include(cmake/LibFuzzer.cmake)
include(CMakeDependentOption)
include(CheckCXXCompilerFlag)


macro(niagara_supports_sanitizers)
  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND NOT WIN32)
    set(SUPPORTS_UBSAN ON)
  else()
    set(SUPPORTS_UBSAN OFF)
  endif()

  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND WIN32)
    set(SUPPORTS_ASAN OFF)
  else()
    set(SUPPORTS_ASAN ON)
  endif()
endmacro()

macro(niagara_setup_options)
  option(niagara_ENABLE_HARDENING "Enable hardening" ON)
  option(niagara_ENABLE_COVERAGE "Enable coverage reporting" OFF)
  cmake_dependent_option(
    niagara_ENABLE_GLOBAL_HARDENING
    "Attempt to push hardening options to built dependencies"
    ON
    niagara_ENABLE_HARDENING
    OFF)

  niagara_supports_sanitizers()

  if(NOT PROJECT_IS_TOP_LEVEL OR niagara_PACKAGING_MAINTAINER_MODE)
    option(niagara_ENABLE_IPO "Enable IPO/LTO" OFF)
    option(niagara_WARNINGS_AS_ERRORS "Treat Warnings As Errors" OFF)
    option(niagara_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(niagara_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" OFF)
    option(niagara_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(niagara_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" OFF)
    option(niagara_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(niagara_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(niagara_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(niagara_ENABLE_CLANG_TIDY "Enable clang-tidy" OFF)
    option(niagara_ENABLE_CPPCHECK "Enable cpp-check analysis" OFF)
    option(niagara_ENABLE_PCH "Enable precompiled headers" OFF)
    option(niagara_ENABLE_CACHE "Enable ccache" OFF)
  else()
    option(niagara_ENABLE_IPO "Enable IPO/LTO" ON)
    option(niagara_WARNINGS_AS_ERRORS "Treat Warnings As Errors" ON)
    option(niagara_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(niagara_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" ${SUPPORTS_ASAN})
    option(niagara_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(niagara_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" ${SUPPORTS_UBSAN})
    option(niagara_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(niagara_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(niagara_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(niagara_ENABLE_CLANG_TIDY "Enable clang-tidy" ON)
    option(niagara_ENABLE_CPPCHECK "Enable cpp-check analysis" ON)
    option(niagara_ENABLE_PCH "Enable precompiled headers" OFF)
    option(niagara_ENABLE_CACHE "Enable ccache" ON)
  endif()

  if(NOT PROJECT_IS_TOP_LEVEL)
    mark_as_advanced(
      niagara_ENABLE_IPO
      niagara_WARNINGS_AS_ERRORS
      niagara_ENABLE_USER_LINKER
      niagara_ENABLE_SANITIZER_ADDRESS
      niagara_ENABLE_SANITIZER_LEAK
      niagara_ENABLE_SANITIZER_UNDEFINED
      niagara_ENABLE_SANITIZER_THREAD
      niagara_ENABLE_SANITIZER_MEMORY
      niagara_ENABLE_UNITY_BUILD
      niagara_ENABLE_CLANG_TIDY
      niagara_ENABLE_CPPCHECK
      niagara_ENABLE_COVERAGE
      niagara_ENABLE_PCH
      niagara_ENABLE_CACHE)
  endif()

  niagara_check_libfuzzer_support(LIBFUZZER_SUPPORTED)
  if(LIBFUZZER_SUPPORTED AND (niagara_ENABLE_SANITIZER_ADDRESS OR niagara_ENABLE_SANITIZER_THREAD OR niagara_ENABLE_SANITIZER_UNDEFINED))
    set(DEFAULT_FUZZER ON)
  else()
    set(DEFAULT_FUZZER OFF)
  endif()

  option(niagara_BUILD_FUZZ_TESTS "Enable fuzz testing executable" ${DEFAULT_FUZZER})

endmacro()

macro(niagara_global_options)
  if(niagara_ENABLE_IPO)
    include(cmake/InterproceduralOptimization.cmake)
    niagara_enable_ipo()
  endif()

  niagara_supports_sanitizers()

  if(niagara_ENABLE_HARDENING AND niagara_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR niagara_ENABLE_SANITIZER_UNDEFINED
       OR niagara_ENABLE_SANITIZER_ADDRESS
       OR niagara_ENABLE_SANITIZER_THREAD
       OR niagara_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    message("${niagara_ENABLE_HARDENING} ${ENABLE_UBSAN_MINIMAL_RUNTIME} ${niagara_ENABLE_SANITIZER_UNDEFINED}")
    niagara_enable_hardening(niagara_options ON ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()
endmacro()

macro(niagara_local_options)
  if(PROJECT_IS_TOP_LEVEL)
    include(cmake/StandardProjectSettings.cmake)
  endif()

  add_library(niagara_warnings INTERFACE)
  add_library(niagara_options INTERFACE)

  include(cmake/CompilerWarnings.cmake)
  niagara_set_project_warnings(
    niagara_warnings
    ${niagara_WARNINGS_AS_ERRORS}
    ""
    ""
    ""
    "")

  if(niagara_ENABLE_USER_LINKER)
    include(cmake/Linker.cmake)
    niagara_configure_linker(niagara_options)
  endif()

  include(cmake/Sanitizers.cmake)
  niagara_enable_sanitizers(
    niagara_options
    ${niagara_ENABLE_SANITIZER_ADDRESS}
    ${niagara_ENABLE_SANITIZER_LEAK}
    ${niagara_ENABLE_SANITIZER_UNDEFINED}
    ${niagara_ENABLE_SANITIZER_THREAD}
    ${niagara_ENABLE_SANITIZER_MEMORY})

  set_target_properties(niagara_options PROPERTIES UNITY_BUILD ${niagara_ENABLE_UNITY_BUILD})

  if(niagara_ENABLE_PCH)
    target_precompile_headers(
      niagara_options
      INTERFACE
      <vector>
      <string>
      <utility>)
  endif()

  if(niagara_ENABLE_CACHE)
    include(cmake/Cache.cmake)
    niagara_enable_cache()
  endif()

  include(cmake/StaticAnalyzers.cmake)
  if(niagara_ENABLE_CLANG_TIDY)
    niagara_enable_clang_tidy(niagara_options ${niagara_WARNINGS_AS_ERRORS})
  endif()

  if(niagara_ENABLE_CPPCHECK)
    niagara_enable_cppcheck(${niagara_WARNINGS_AS_ERRORS} "" # override cppcheck options
    )
  endif()

  if(niagara_ENABLE_COVERAGE)
    include(cmake/Tests.cmake)
    niagara_enable_coverage(niagara_options)
  endif()

  if(niagara_WARNINGS_AS_ERRORS)
    check_cxx_compiler_flag("-Wl,--fatal-warnings" LINKER_FATAL_WARNINGS)
    if(LINKER_FATAL_WARNINGS)
      # This is not working consistently, so disabling for now
      # target_link_options(niagara_options INTERFACE -Wl,--fatal-warnings)
    endif()
  endif()

  if(niagara_ENABLE_HARDENING AND NOT niagara_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR niagara_ENABLE_SANITIZER_UNDEFINED
       OR niagara_ENABLE_SANITIZER_ADDRESS
       OR niagara_ENABLE_SANITIZER_THREAD
       OR niagara_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    niagara_enable_hardening(niagara_options OFF ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()

endmacro()
