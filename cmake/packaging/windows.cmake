# windows specific packaging
install(TARGETS sunshine RUNTIME DESTINATION "." COMPONENT application)

# Hardening: include zlib1.dll (loaded via LoadLibrary() in openssl's libcrypto.a)
# Check for zlib in Sunshine or Apollo install directories
if(EXISTS "${ZLIB}")
    install(FILES "${ZLIB}" DESTINATION "." COMPONENT application)
elseif(EXISTS "C:/Program Files (x86)/Sunshine/zlib1.dll")
    install(FILES "C:/Program Files (x86)/Sunshine/zlib1.dll" DESTINATION "." COMPONENT application)
elseif(EXISTS "C:/Program Files/Apollo/zlib1.dll")
    install(FILES "C:/Program Files/Apollo/zlib1.dll" DESTINATION "." COMPONENT application)
else()
    message(FATAL_ERROR "zlib1.dll not found in expected locations")
endif()

if(WEBRTC_RUNTIME_DLL)
    install(FILES "${WEBRTC_RUNTIME_DLL}" DESTINATION "." COMPONENT application)
endif()

# ViGEmBus installer is no longer bundled or managed by the installer

# Adding tools
install(TARGETS dxgi-info RUNTIME DESTINATION "tools" COMPONENT dxgi)
install(TARGETS audio-info RUNTIME DESTINATION "tools" COMPONENT audio)

# Helpers and tools
# - Playnite launcher helper used for Playnite-managed app launches
# - WGC capture helper used by the WGC display backend
# - Display helper used for applying/reverting display settings
if (TARGET playnite-launcher)
    install(TARGETS playnite-launcher RUNTIME DESTINATION "tools" COMPONENT application)
endif()
if (TARGET sunshine_wgc_capture)
    install(TARGETS sunshine_wgc_capture RUNTIME DESTINATION "tools" COMPONENT application)
endif()
if (TARGET sunshine_display_helper)
    install(TARGETS sunshine_display_helper RUNTIME DESTINATION "tools" COMPONENT application)
endif()
install(FILES "${CMAKE_BINARY_DIR}/uninstall.exe" DESTINATION "." COMPONENT application)

# Drivers (SudoVDA virtual display).
#
# The SudoVDA binary artifacts (SudoVDA.dll, sudovda.cat, sudovda.cer,
# nefconc.exe) are NOT committed to the repository. Upstream Nonary/Vibepollo
# builds releases with these files present on the maintainer's machine;
# GitHub CI has no route to obtain them. This fork relaxes the check so the
# Windows installer can be built without SudoVDA: users who need it install
# it via the existing Apollo installer (the driver is identical and stays
# loaded across Vibepollo upgrades).
#
# Gate: set -DVIBEPOLLO_BUNDLE_SUDOVDA=ON at configure time to re-enable the
# strict check and include the driver in the installer. Defaults to OFF.
option(VIBEPOLLO_BUNDLE_SUDOVDA
       "Bundle the SudoVDA virtual-display driver in the Windows installer"
       OFF)

set(SUDOVDA_SOURCE_DIR "${SUNSHINE_SOURCE_ASSETS_DIR}/windows/drivers/sudovda")
set(SUDOVDA_DRIVER_FILES_REQUIRED
    "${SUDOVDA_SOURCE_DIR}/install.ps1"
    "${SUDOVDA_SOURCE_DIR}/uninstall.bat"
    "${SUDOVDA_SOURCE_DIR}/SudoVDA.inf"
    "${SUDOVDA_SOURCE_DIR}/sudovda.cer"
)
# Optional binary artifacts (not committed to repo, present only when
# Nonary-style local builds include them).
set(SUDOVDA_DRIVER_FILES_OPTIONAL
    "${SUDOVDA_SOURCE_DIR}/SudoVDA.dll"
    "${SUDOVDA_SOURCE_DIR}/sudovda.cat"
    "${SUDOVDA_SOURCE_DIR}/nefconc.exe"
)

if (VIBEPOLLO_BUNDLE_SUDOVDA)
    set(SUDOVDA_DRIVER_FILES ${SUDOVDA_DRIVER_FILES_REQUIRED} ${SUDOVDA_DRIVER_FILES_OPTIONAL})
    foreach(_sudovda_file IN LISTS SUDOVDA_DRIVER_FILES)
        if (NOT EXISTS "${_sudovda_file}")
            message(FATAL_ERROR "Required SudoVDA driver artifact missing: ${_sudovda_file}")
        endif()
        file(SIZE "${_sudovda_file}" _sudovda_file_size)
        if (_sudovda_file_size EQUAL 0)
            message(FATAL_ERROR "Required SudoVDA driver artifact is empty (0 bytes): ${_sudovda_file}")
        endif()
    endforeach()
    unset(_sudovda_file_size)

    install(FILES ${SUDOVDA_DRIVER_FILES}
            DESTINATION "drivers/sudovda"
            COMPONENT sudovda)
else()
    message(STATUS "VIBEPOLLO_BUNDLE_SUDOVDA=OFF: building without the "
                   "SudoVDA driver. Install it separately via Apollo if "
                   "virtual-display functionality is needed.")
    set(SUDOVDA_DRIVER_FILES ${SUDOVDA_DRIVER_FILES_REQUIRED})
    foreach(_sudovda_file IN LISTS SUDOVDA_DRIVER_FILES)
        if (EXISTS "${_sudovda_file}")
            list(APPEND SUDOVDA_DRIVER_FILES_PRESENT "${_sudovda_file}")
        endif()
    endforeach()
    if (SUDOVDA_DRIVER_FILES_PRESENT)
        install(FILES ${SUDOVDA_DRIVER_FILES_PRESENT}
                DESTINATION "drivers/sudovda"
                COMPONENT sudovda)
    endif()
endif()

# Mandatory scripts
install(DIRECTORY "${SUNSHINE_SOURCE_ASSETS_DIR}/windows/misc/service/"
        DESTINATION "scripts"
        COMPONENT assets)
install(DIRECTORY "${SUNSHINE_SOURCE_ASSETS_DIR}/windows/misc/migration/"
        DESTINATION "scripts"
        COMPONENT assets)
install(DIRECTORY "${SUNSHINE_SOURCE_ASSETS_DIR}/windows/misc/path/"
        DESTINATION "scripts"
        COMPONENT assets)

# Configurable options for the service
install(DIRECTORY "${SUNSHINE_SOURCE_ASSETS_DIR}/windows/misc/autostart/"
        DESTINATION "scripts"
        COMPONENT autostart)

# scripts
install(DIRECTORY "${SUNSHINE_SOURCE_ASSETS_DIR}/windows/misc/firewall/"
        DESTINATION "scripts"
        COMPONENT firewall)
install(DIRECTORY "${SUNSHINE_SOURCE_ASSETS_DIR}/windows/misc/gamepad/"
        DESTINATION "scripts"
        COMPONENT assets)

# Sunshine assets
install(DIRECTORY "${SUNSHINE_SOURCE_ASSETS_DIR}/windows/assets/"
        DESTINATION "${SUNSHINE_ASSETS_DIR}"
        COMPONENT assets)

# Plugins (copy plugin folders such as `plugins/playnite` into the package)
install(DIRECTORY "${CMAKE_SOURCE_DIR}/plugins/"
        DESTINATION "plugins"
        COMPONENT assets)

# copy assets (excluding shaders) to build directory, for running without install
file(COPY "${SUNSHINE_SOURCE_ASSETS_DIR}/windows/assets/"
        DESTINATION "${CMAKE_BINARY_DIR}/assets"
        PATTERN "shaders" EXCLUDE)

if(WEBRTC_RUNTIME_DLL)
    file(COPY "${WEBRTC_RUNTIME_DLL}"
            DESTINATION "${CMAKE_BINARY_DIR}")
endif()
# use junction for shaders directory
cmake_path(CONVERT "${SUNSHINE_SOURCE_ASSETS_DIR}/windows/assets/shaders"
        TO_NATIVE_PATH_LIST shaders_in_build_src_native)
cmake_path(CONVERT "${CMAKE_BINARY_DIR}/assets/shaders" TO_NATIVE_PATH_LIST shaders_in_build_dest_native)
if(NOT EXISTS "${CMAKE_BINARY_DIR}/assets/shaders")
    execute_process(COMMAND cmd.exe /c mklink /J "${shaders_in_build_dest_native}" "${shaders_in_build_src_native}")
endif()

set(CPACK_PACKAGE_ICON "${CMAKE_SOURCE_DIR}\\\\apollo.ico")

# The name of the directory that will be created in C:/Program Files/
# Match the legacy NSIS layout by installing under Apollo
set(CPACK_PACKAGE_INSTALL_DIRECTORY "Apollo")

# Setting components groups and dependencies
set(CPACK_COMPONENT_GROUP_CORE_EXPANDED true)

# sunshine binary
set(CPACK_COMPONENT_APPLICATION_DISPLAY_NAME "${CMAKE_PROJECT_NAME}")
set(CPACK_COMPONENT_APPLICATION_DESCRIPTION "${CMAKE_PROJECT_NAME} main application and required components.")
set(CPACK_COMPONENT_APPLICATION_GROUP "Core")
set(CPACK_COMPONENT_APPLICATION_REQUIRED true)
set(CPACK_COMPONENT_APPLICATION_DEPENDS assets)

# service auto-start script
set(CPACK_COMPONENT_AUTOSTART_DISPLAY_NAME "Launch on Startup")
set(CPACK_COMPONENT_AUTOSTART_DESCRIPTION "If enabled, launches Vibepollo automatically on system startup.")
set(CPACK_COMPONENT_AUTOSTART_GROUP "Core")

# assets
set(CPACK_COMPONENT_ASSETS_DISPLAY_NAME "Required Assets")
set(CPACK_COMPONENT_ASSETS_DESCRIPTION "Shaders, default box art, and web UI.")
set(CPACK_COMPONENT_ASSETS_GROUP "Core")
set(CPACK_COMPONENT_ASSETS_REQUIRED true)

# drivers
set(CPACK_COMPONENT_SUDOVDA_DISPLAY_NAME "SudoVDA")
set(CPACK_COMPONENT_SUDOVDA_DESCRIPTION "Driver required for Virtual Display to function.")
set(CPACK_COMPONENT_SUDOVDA_GROUP "Drivers")
if (VIBEPOLLO_BUNDLE_SUDOVDA)
    set(CPACK_COMPONENT_SUDOVDA_REQUIRED true)
else()
    set(CPACK_COMPONENT_SUDOVDA_REQUIRED false)
endif()

# audio tool
set(CPACK_COMPONENT_AUDIO_DISPLAY_NAME "audio-info")
set(CPACK_COMPONENT_AUDIO_DESCRIPTION "CLI tool providing information about sound devices.")
set(CPACK_COMPONENT_AUDIO_GROUP "Tools")

# display tool
set(CPACK_COMPONENT_DXGI_DISPLAY_NAME "dxgi-info")
set(CPACK_COMPONENT_DXGI_DESCRIPTION "CLI tool providing information about graphics cards and displays.")
set(CPACK_COMPONENT_DXGI_GROUP "Tools")

# firewall scripts
set(CPACK_COMPONENT_FIREWALL_DISPLAY_NAME "Add Firewall Exclusions")
set(CPACK_COMPONENT_FIREWALL_DESCRIPTION "Scripts to enable or disable firewall rules.")
set(CPACK_COMPONENT_FIREWALL_GROUP "Scripts")

# gamepad scripts are bundled under assets and not exposed as a separate component

# include specific packaging (WiX only)
include(${CMAKE_MODULE_PATH}/packaging/windows_wix.cmake)
