# SPDX-FileCopyrightText: 2026 Davide De Rosa
#
# SPDX-License-Identifier: MIT

list(APPEND CMAKE_TRY_COMPILE_PLATFORM_VARIABLES
    CMAKE_ANDROID_NDK
    ANDROID_ABI
    ANDROID_PLATFORM
    ANDROID_STL
    SWIFT_VERSION
)
if(NOT DEFINED SWIFT_VERSION)
    message(FATAL_ERROR "SWIFT_VERSION is required")
endif()
include("${CMAKE_CURRENT_LIST_DIR}/swift-macros.cmake")
swift_android_resolve_inputs()

# Start from the official NDK toolchain
include("${CMAKE_ANDROID_NDK}/build/cmake/android.toolchain.cmake")
if(EXISTS "${CMAKE_CURRENT_LIST_DIR}/swift-android-post.toolchain.cmake")
    include("${CMAKE_CURRENT_LIST_DIR}/swift-android-post.toolchain.cmake")
endif()

# Compilers and flags
set(CMAKE_C_COMPILER_TARGET ${SWIFT_ANDROID_TRIPLE})
set(CMAKE_CXX_COMPILER_TARGET ${SWIFT_ANDROID_TRIPLE})
set(CMAKE_Swift_COMPILER_TARGET ${SWIFT_ANDROID_TRIPLE})
string(APPEND CMAKE_C_FLAGS " -fPIC")

# Inherit clang resource dir (e.g. for stddef.h and stdbool.h)
execute_process(
    COMMAND "${ANDROID_TOOLCHAIN_ROOT}/bin/clang" -print-resource-dir
    OUTPUT_VARIABLE ANDROID_CLANG_RESOURCE_DIR
    OUTPUT_STRIP_TRAILING_WHITESPACE
    ERROR_QUIET
)
if(NOT ANDROID_CLANG_RESOURCE_DIR)
    message(FATAL_ERROR "Unable to infer Android clang resource directory")
endif()
if(NOT IS_DIRECTORY "${ANDROID_CLANG_RESOURCE_DIR}")
    message(FATAL_ERROR "ANDROID_CLANG_RESOURCE_DIR must point to an existing directory: ${ANDROID_CLANG_RESOURCE_DIR}")
endif()

# Swift
set(CMAKE_Swift_COMPILER "${CMAKE_CURRENT_LIST_DIR}/swiftc-wrapper.sh")
set(CMAKE_Swift_FLAGS "\
    -target ${SWIFT_ANDROID_TRIPLE} \
    -resource-dir ${SWIFT_RESOURCE_DIR} \
    -Xcc -resource-dir -Xcc ${ANDROID_CLANG_RESOURCE_DIR} \
    -tools-directory ${ANDROID_TOOLCHAIN_ROOT}/bin \
    -sdk ${SWIFT_ANDROID_SDK}/swift-android/ndk-sysroot \
    -module-cache-path ${CMAKE_BINARY_DIR}/swift-module-cache"
)
set(_swift_android_libraries
    FoundationEssentials
    _FoundationCollections
    _FoundationCShims
    swiftSynchronization
    dispatch
    BlocksRuntime
    android
    ${ANDROID_STL}
)
if(_android_stl_kind STREQUAL "static")
    list(APPEND _swift_android_libraries c++abi)
endif()
list(APPEND _swift_android_libraries log m)
set(CMAKE_Swift_STANDARD_LIBRARIES "")
foreach(library IN LISTS _swift_android_libraries)
    string(APPEND CMAKE_Swift_STANDARD_LIBRARIES " -l${library}")
endforeach()
unset(library)
unset(_swift_android_libraries)

set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
