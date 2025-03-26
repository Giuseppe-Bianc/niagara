#
# This function will prevent in-source builds
#
function(niagara_assure_out_of_source_builds)
  # Resolve absolute paths to handle symlinks and path variations
  get_filename_component(srcdir "${CMAKE_SOURCE_DIR}" REALPATH)
  get_filename_component(bindir "${CMAKE_BINARY_DIR}" REALPATH)

  # Detect and prevent in-source builds
  if("${srcdir}" STREQUAL "${bindir}")
    # Format error message with full details
    message("###############################################################################")
    message(" FATAL ERROR: In-source builds are strictly prohibited")
    message("------------------------------------------------------------------------------")
    message(" Detected identical source and binary directories:")
    message("   Source directory: ${srcdir}")
    message("   Build directory:  ${bindir}")
    message("\n Reasons for this restriction:")
    message(" - Prevents build artifacts from contaminating source control")
    message(" - Avoids accidental overwriting of source files")
    message(" - Maintains clean separation between source and generated files")
    message("\n Immediate action required:")
    message(" 1. Create a dedicated build directory:")
    message("    mkdir build && cd build")
    message(" 2. Rerun CMake from the new build directory:")
    message("    cmake [options] ..")
    message(" 3. Build from the created directory")
    message("\n For more information, see:")
    message(" https://cmake.org/pipermail/cmake/2000-May/000803.html")
    message("###############################################################################")

    # Force configuration failure with explanatory error
    message(FATAL_ERROR "\nCMake configuration aborted: Remove CMakeCache.txt and use out-of-source build.\n")
  endif()
endfunction()

niagara_assure_out_of_source_builds()
