# SPDX-FileCopyrightText: 2026 Davide De Rosa
#
# SPDX-License-Identifier: MIT

set(SWIFT_CMAKE_TOOLCHAINS_PATH ${CMAKE_CURRENT_LIST_DIR})

macro(swift_android_resolve_inputs)
    if(NOT CMAKE_ANDROID_NDK)
        message(FATAL_ERROR "CMAKE_ANDROID_NDK must be defined")
    endif()
    if(NOT SWIFT_VERSION)
        set(SWIFT_VERSION "6.3.1")
    endif()
    if(NOT ANDROID_PLATFORM)
        set(ANDROID_PLATFORM "android-28")
    endif()
    if(ANDROID_ABI STREQUAL "arm64-v8a")
        set(SWIFT_ANDROID_ARCH "aarch64")
    elseif(ANDROID_ABI STREQUAL "x86_64")
        set(SWIFT_ANDROID_ARCH "x86_64")
    else()
        message(FATAL_ERROR "Unsupported Android ABI: ${ANDROID_ABI}")
    endif()
    if(NOT ANDROID_STL)
        set(ANDROID_STL "c++_static")
    endif()
    if(NOT ANDROID_STL MATCHES "^c[+][+]_(static|shared)$")
        message(FATAL_ERROR "ANDROID_STL must be c++_static or c++_shared")
    endif()
    string(REPLACE "c++_" "" _android_stl_kind "${ANDROID_STL}")

    file(GLOB _swift_android_toolchains "${CMAKE_ANDROID_NDK}/toolchains/llvm/prebuilt/*")
    list(GET _swift_android_toolchains 0 ANDROID_TOOLCHAIN_ROOT)
    unset(_swift_android_toolchains)

    set(LIBCXX_NAME "${ANDROID_STL}")
    if(_android_stl_kind STREQUAL "shared")
        set(LIBCXX_TRIPLE "${SWIFT_ANDROID_ARCH}-linux-android")
        set(LIBCXX_FILE "${ANDROID_TOOLCHAIN_ROOT}/sysroot/usr/lib/${LIBCXX_TRIPLE}/lib${LIBCXX_NAME}.so")
    endif()

    string(REPLACE "android-" "android" _android_platform "${ANDROID_PLATFORM}")
    set(SWIFT_ANDROID_SDK "$ENV{HOME}/.swiftpm/swift-sdks/swift-${SWIFT_VERSION}-RELEASE_android.artifactbundle")
    set(SWIFT_ANDROID_TRIPLE "${SWIFT_ANDROID_ARCH}-unknown-linux-${_android_platform}")
    set(SWIFT_RESOURCE_DIR "${SWIFT_ANDROID_SDK}/swift-android/swift-resources/usr/lib/swift_static-${SWIFT_ANDROID_ARCH}")

    set(SWIFT_CMAKE_ARGS
        -DCMAKE_ANDROID_NDK:PATH=${CMAKE_ANDROID_NDK}
        -DANDROID_ABI:STRING=${ANDROID_ABI}
        -DANDROID_PLATFORM:STRING=${ANDROID_PLATFORM}
        -DANDROID_STL:STRING=${ANDROID_STL}
        -DSWIFT_VERSION:STRING=${SWIFT_VERSION}
        -DCMAKE_TOOLCHAIN_FILE:FILEPATH=${SWIFT_CMAKE_TOOLCHAINS_PATH}/swift-android.toolchain.cmake
    )
    if(CMAKE_BUILD_TYPE)
        list(APPEND SWIFT_CMAKE_ARGS -DCMAKE_BUILD_TYPE:STRING=${CMAKE_BUILD_TYPE})
    endif()

    set(SWIFT_ENVIRONMENT
        CMAKE_ANDROID_NDK=${CMAKE_ANDROID_NDK}
        SWIFT_ANDROID_ARCH=${SWIFT_ANDROID_ARCH}
    )
endmacro()

function(add_swift_library target source_dir)
    include(ExternalProject)
    swift_android_resolve_inputs()
    cmake_parse_arguments(SWIFT_LIBRARY "" "" "BUILD_BYPRODUCTS;CMAKE_ARGS" ${ARGN})
    if(SWIFT_LIBRARY_BUILD_BYPRODUCTS)
        list(GET SWIFT_LIBRARY_BUILD_BYPRODUCTS 0 library_file)
        list(LENGTH SWIFT_LIBRARY_BUILD_BYPRODUCTS byproducts_count)
        if(byproducts_count GREATER 1)
            set(dependent_libraries ${SWIFT_LIBRARY_BUILD_BYPRODUCTS})
            list(REMOVE_AT dependent_libraries 0)
        endif()
        set(build_byproducts BUILD_BYPRODUCTS ${SWIFT_LIBRARY_BUILD_BYPRODUCTS})
    else()
        set(build_byproducts BUILD_BYPRODUCTS
            <BINARY_DIR>/${CMAKE_SHARED_LIBRARY_PREFIX}${target}${CMAKE_SHARED_LIBRARY_SUFFIX}
        )
    endif()

    set(external_target "lib${target}")
    ExternalProject_Add(${external_target}
        SOURCE_DIR "${source_dir}"
        CONFIGURE_COMMAND ${CMAKE_COMMAND} -E env ${SWIFT_ENVIRONMENT}
            ${CMAKE_COMMAND}
            -G "${CMAKE_GENERATOR}"
            ${SWIFT_CMAKE_ARGS}
            ${SWIFT_LIBRARY_CMAKE_ARGS}
            -DCMAKE_INSTALL_PREFIX:PATH=<INSTALL_DIR>
            <SOURCE_DIR>
        BUILD_COMMAND ${CMAKE_COMMAND} --build <BINARY_DIR>
        INSTALL_COMMAND ${CMAKE_COMMAND} --install <BINARY_DIR>
        BUILD_ALWAYS TRUE
        ${build_byproducts}
    )
    ExternalProject_Get_Property(${external_target} INSTALL_DIR)
    ExternalProject_Get_Property(${external_target} BINARY_DIR)

    if(NOT library_file)
        set(library_file "${BINARY_DIR}/${CMAKE_SHARED_LIBRARY_PREFIX}${target}${CMAKE_SHARED_LIBRARY_SUFFIX}")
    endif()

    set(include_dir "${INSTALL_DIR}/include")
    file(MAKE_DIRECTORY "${include_dir}")

    add_library(${target} SHARED IMPORTED GLOBAL)
    add_dependencies(${target} ${external_target})
    set_target_properties(${target} PROPERTIES
        IMPORTED_LOCATION "${library_file}"
        INTERFACE_INCLUDE_DIRECTORIES "${include_dir}"
    )
    if(dependent_libraries)
        set_target_properties(${target} PROPERTIES
            IMPORTED_LINK_DEPENDENT_LIBRARIES "${dependent_libraries}"
        )
    endif()

    if(_android_stl_kind STREQUAL "shared")
        add_library(SwiftAndroid::cxx_shared SHARED IMPORTED GLOBAL)
        set_target_properties(SwiftAndroid::cxx_shared PROPERTIES
            IMPORTED_LOCATION "${LIBCXX_FILE}"
        )
        target_link_libraries(${target} INTERFACE SwiftAndroid::cxx_shared)
    endif()
endfunction()
