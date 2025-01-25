cmake_minimum_required(VERSION 3.12)
project(zarr_blosc_mex)

# Detect system architecture
execute_process(
    COMMAND uname -m
    OUTPUT_VARIABLE SYSTEM_ARCH
    OUTPUT_STRIP_TRAILING_WHITESPACE
)

# Set MATLAB paths
set(MATLAB_ROOT "/Applications/MATLAB_R2024b.app")
set(MATLAB_INCLUDE_DIR "${MATLAB_ROOT}/extern/include")

# Try to find MATLAB libraries in different locations
if(SYSTEM_ARCH STREQUAL "arm64")
    if(EXISTS "${MATLAB_ROOT}/bin/maca64/libmx.dylib")
        set(MATLAB_LIB_DIR "${MATLAB_ROOT}/bin/maca64")
        set(MEX_SUFFIX ".mexmaca64")
    else()
        message(FATAL_ERROR "MATLAB ARM64 libraries not found in ${MATLAB_ROOT}/bin/maca64")
    endif()
else()
    if(EXISTS "${MATLAB_ROOT}/bin/maca64/libmx.dylib")
        set(MATLAB_LIB_DIR "${MATLAB_ROOT}/bin/maca64")
        set(MEX_SUFFIX ".mexmaca64")
    else()
        message(FATAL_ERROR "MATLAB x86_64 libraries not found in ${MATLAB_ROOT}/bin/maca64")
    endif()
endif()

message(STATUS "Using MATLAB libraries from: ${MATLAB_LIB_DIR}")
message(STATUS "System architecture: ${SYSTEM_ARCH}")
message(STATUS "MEX suffix: ${MEX_SUFFIX}")

# Force CMake to use arm64 architecture on Apple Silicon
if(APPLE)
    set(CMAKE_OSX_ARCHITECTURES "arm64")
    set(CMAKE_SYSTEM_PROCESSOR "arm64")
    
    # Set architecture-specific flags for all targets
    set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -arch arm64")
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -arch arm64")
    set(CMAKE_ASM_FLAGS "${CMAKE_ASM_FLAGS} -arch arm64")
endif()

set(MATLAB_MEX "${MATLAB_ROOT}/bin/mex")
set(MATLAB_MX_LIBRARY "${MATLAB_LIB_DIR}/libmx.dylib")
set(MATLAB_MEX_LIBRARY "${MATLAB_LIB_DIR}/libmex.dylib")

# Ensure MATLAB libraries exist
if(NOT EXISTS ${MATLAB_MX_LIBRARY} OR NOT EXISTS ${MATLAB_MEX_LIBRARY})
    message(FATAL_ERROR "MATLAB libraries not found in ${MATLAB_LIB_DIR}")
endif()

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
set(CMAKE_POSITION_INDEPENDENT_CODE ON)
FetchContent_MakeAvailable(c-blosc)

# Ensure blosc is built with the correct architecture
set_target_properties(blosc_static PROPERTIES
    OSX_ARCHITECTURES "arm64"
    POSITION_INDEPENDENT_CODE ON
)

# MEX file compilation function
function(add_mex_target target_name source_file)
    add_library(${target_name} SHARED ${source_file})
    set_target_properties(${target_name} PROPERTIES
        PREFIX ""
        SUFFIX ${MEX_SUFFIX}
        LIBRARY_OUTPUT_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
    )
    target_include_directories(${target_name} PRIVATE ${MATLAB_INCLUDE_DIR} ${c-blosc_SOURCE_DIR}/blosc)
    target_link_libraries(${target_name} PRIVATE 
        ${MATLAB_MX_LIBRARY}
        ${MATLAB_MEX_LIBRARY}
        blosc_static
    )
    set_target_properties(${target_name} PROPERTIES
        OSX_ARCHITECTURES "arm64"
    )
endfunction()

# Add MEX targets
add_mex_target(blosc_compress blosc_compress.cpp)
add_mex_target(blosc_decompress blosc_decompress.cpp)
