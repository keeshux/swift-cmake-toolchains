# SPDX-FileCopyrightText: 2026 Davide De Rosa
#
# SPDX-License-Identifier: MIT

set(SWIFT_ANDROID_ENV_DEFINE_ONLY TRUE)
include("${CMAKE_CURRENT_LIST_DIR}/swift-android-env.cmake")
unset(SWIFT_ANDROID_ENV_DEFINE_ONLY)
swift_android_resolve_inputs()

# Start from the official NDK toolchain
set(ANDROID_ABI ${SWIFT_ANDROID_ABI})
set(ANDROID_NATIVE_API_LEVEL ${SWIFT_ANDROID_API_LEVEL})
include("${ANDROID_NDK_HOME}/build/cmake/android.toolchain.cmake")
if(EXISTS "${CMAKE_CURRENT_LIST_DIR}/swift-android-post.toolchain.cmake")
    include("${CMAKE_CURRENT_LIST_DIR}/swift-android-post.toolchain.cmake")
endif()

swift_android_resolve_inputs()

# Compiler flags
set(CMAKE_C_COMPILER_TARGET ${SWIFT_ANDROID_TRIPLE})
set(CMAKE_CXX_COMPILER_TARGET ${SWIFT_ANDROID_TRIPLE})
set(CMAKE_Swift_COMPILER_TARGET ${SWIFT_ANDROID_TRIPLE})

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

# C/C++
set(CMAKE_C_FLAGS "-fPIC")

# Swift
set(CMAKE_Swift_COMPILER "${CMAKE_CURRENT_LIST_DIR}/swiftc-wrapper.sh")
set(CMAKE_Swift_FLAGS "\
    -target ${SWIFT_ANDROID_TRIPLE} \
    -resource-dir ${SWIFT_RESOURCE_DIR} \
    -Xcc -resource-dir -Xcc ${ANDROID_CLANG_RESOURCE_DIR} \
    -tools-directory ${ANDROID_TOOLCHAIN_ROOT}/bin \
    -sdk ${SWIFT_ANDROID_SDK}/swift-android/ndk-sysroot \
    -module-cache-path ${CMAKE_BINARY_DIR}/swift-module-cache \
    -lFoundationEssentials \
    -l_FoundationCollections \
    -l_FoundationCShims \
    -lswiftSynchronization \
    -ldispatch \
    -lBlocksRuntime \
    -landroid \
    -lc++_shared \
    -llog \
    -lm"
)

set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
