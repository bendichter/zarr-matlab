cmake_minimum_required(VERSION 3.12)
project(zarr_blosc_mex)

# Set architecture
set(CMAKE_OSX_ARCHITECTURES "arm64")

# Set MATLAB paths directly
set(MATLAB_ROOT "/Applications/MATLAB_R2024b.app")
set(MATLAB_INCLUDE_DIR "${MATLAB_ROOT}/extern/include")
set(MATLAB_LIB_DIR "${MATLAB_ROOT}/extern/lib/maci64")
set(MATLAB_MEX "${MATLAB_ROOT}/bin/mex")
set(MATLAB_MX_LIBRARY "${MATLAB_LIB_DIR}/libmx.dylib")
set(MATLAB_MEX_LIBRARY "${MATLAB_LIB_DIR}/libmex.dylib")

# Add MATLAB include directories
include_directories(${MATLAB_INCLUDE_DIR})

# Configure Blosc
include(FetchContent)
FetchContent_Declare(
    c-blosc
    GIT_REPOSITORY https://github.com/Blosc/c-blosc.git
    GIT_TAG v1.21.5  # Latest stable version
)
set(BLOSC_IS_SUBPROJECT ON)
set(BUILD_TESTS OFF)
set(BUILD_BENCHMARKS OFF)
set(BUILD_SHARED OFF)
FetchContent_MakeAvailable(c-blosc)

# MEX file compilation function
function(add_mex_target target_name source_file)
    add_library(${target_name} SHARED ${source_file})
    set_target_properties(${target_name} PROPERTIES
        PREFIX ""
        SUFFIX ".mexmaci64"
        LIBRARY_OUTPUT_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
    )
    target_include_directories(${target_name} PRIVATE ${MATLAB_INCLUDE_DIR} ${c-blosc_SOURCE_DIR}/blosc)
    target_link_libraries(${target_name} PRIVATE 
        ${MATLAB_MX_LIBRARY}
        ${MATLAB_MEX_LIBRARY}
        blosc_static
    )
endfunction()

# Add MEX targets
add_mex_target(blosc_compress blosc_compress.cpp)
add_mex_target(blosc_decompress blosc_decompress.cpp)
