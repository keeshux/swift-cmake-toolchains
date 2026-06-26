# SPDX-FileCopyrightText: 2026 Davide De Rosa
#
# SPDX-License-Identifier: MIT

set(SWIFT_CMAKE_TOOLCHAINS_PATH ${CMAKE_CURRENT_LIST_DIR})

function(swift_copy_windows_runtime destination)
    if(NOT WIN32)
        return()
    endif()

    if(NOT DEFINED SWIFT_SDKROOT)
        message(FATAL_ERROR "SWIFT_SDKROOT is required to locate the Swift runtime libraries")
    endif()
    if(NOT DEFINED SWIFT_VERSION)
        message(FATAL_ERROR "SWIFT_VERSION is required to locate the Swift runtime libraries")
    endif()

    set(SWIFT_RUNTIME_LIBRARIES
        BlocksRuntime.dll
        dispatch.dll
        FoundationEssentials.dll
        swiftCore.dll
        swiftCRT.dll
        swiftDispatch.dll
        swiftWinSDK.dll
        swift_Concurrency.dll
        swift_RegexParser.dll
        swift_StringProcessing.dll
    )
    list(GET SWIFT_RUNTIME_LIBRARIES 0 first_runtime_library)

    set(swift_windows_sdk "${SWIFT_SDKROOT}/swift-${SWIFT_VERSION}-RELEASE_windows.artifactbundle")
    set(runtime_dir_candidates
        "${swift_windows_sdk}/swift-windows/swift-resources/usr/bin"
        "${swift_windows_sdk}/swift-windows/swift-resources/usr/lib/swift/windows"
        "${swift_windows_sdk}/swift-windows/usr/bin"
        "${swift_windows_sdk}/swift-windows/usr/lib/swift/windows"
        "${swift_windows_sdk}/usr/bin"
        "${swift_windows_sdk}/usr/lib/swift/windows"
        "${SWIFT_SDKROOT}/swift-windows/swift-resources/usr/bin"
        "${SWIFT_SDKROOT}/swift-windows/swift-resources/usr/lib/swift/windows"
        "${SWIFT_SDKROOT}/swift-windows/usr/bin"
        "${SWIFT_SDKROOT}/swift-windows/usr/lib/swift/windows"
        "${SWIFT_SDKROOT}/usr/bin"
        "${SWIFT_SDKROOT}/usr/lib/swift/windows"
    )
    set(runtime_dir "")
    foreach(candidate IN LISTS runtime_dir_candidates)
        if(EXISTS "${candidate}/${first_runtime_library}")
            set(runtime_dir "${candidate}")
            break()
        endif()
    endforeach()
    if(NOT runtime_dir)
        message(FATAL_ERROR "Unable to locate Swift runtime libraries under SWIFT_SDKROOT: ${SWIFT_SDKROOT}")
    endif()

    file(MAKE_DIRECTORY "${destination}")
    foreach(library IN LISTS SWIFT_RUNTIME_LIBRARIES)
        set(runtime_library "${runtime_dir}/${library}")
        if(NOT EXISTS "${runtime_library}")
            message(FATAL_ERROR "Missing Swift runtime library: ${runtime_library}")
        endif()
        file(COPY "${runtime_library}" DESTINATION "${destination}")
    endforeach()
endfunction()

macro(swift_android_resolve_inputs)
    if(NOT CMAKE_ANDROID_NDK)
        message(FATAL_ERROR "CMAKE_ANDROID_NDK must be defined")
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
endfunction()
