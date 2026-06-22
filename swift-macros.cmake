# SPDX-FileCopyrightText: 2026 Davide De Rosa
#
# SPDX-License-Identifier: MIT

if(NOT COMMAND add_swift_target)
function(add_swift_target target source_dir)
    include(ExternalProject)

    if(NOT DEFINED SWIFT_CMAKE_ARGS)
        message(FATAL_ERROR "SWIFT_CMAKE_ARGS must be defined before add_swift_target()")
    endif()

    if(DEFINED SWIFT_SHARED_LIBRARY_PREFIX)
        set(_swift_library_prefix "${SWIFT_SHARED_LIBRARY_PREFIX}")
    else()
        set(_swift_library_prefix "lib")
    endif()
    if(DEFINED SWIFT_SHARED_LIBRARY_SUFFIX)
        set(_swift_library_suffix "${SWIFT_SHARED_LIBRARY_SUFFIX}")
    else()
        set(_swift_library_suffix ".so")
    endif()

    set(_swift_external_target "${_swift_library_prefix}${target}")
    set(_swift_library_file "${_swift_library_prefix}${target}${_swift_library_suffix}")
    ExternalProject_Add(${_swift_external_target}
            SOURCE_DIR "${source_dir}"
            CMAKE_ARGS ${SWIFT_CMAKE_ARGS}
            INSTALL_COMMAND ""
            BUILD_ALWAYS TRUE
            BUILD_BYPRODUCTS <BINARY_DIR>/${_swift_library_file}
    )
    ExternalProject_Get_Property(${_swift_external_target} BINARY_DIR)

    add_library(${target} SHARED IMPORTED GLOBAL)
    add_dependencies(${target} ${_swift_external_target})
    set_target_properties(${target} PROPERTIES
        IMPORTED_LOCATION "${BINARY_DIR}/${_swift_library_file}"
    )
    if(DEFINED SWIFT_TARGET_INTERFACE_LINK_LIBRARIES)
        set_target_properties(${target} PROPERTIES
            INTERFACE_LINK_LIBRARIES "${SWIFT_TARGET_INTERFACE_LINK_LIBRARIES}"
        )
    endif()
endfunction()
endif()
