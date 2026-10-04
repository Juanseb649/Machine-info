cmake_minimum_required(VERSION 3.16)
project(machineinfo VERSION 0.1.0 LANGUAGES C)

set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED ON)
set(CMAKE_C_VISIBILITY_PRESET hidden)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

if(MSVC)
    add_compile_definitions(_CRT_SECURE_NO_WARNINGS)
endif()

if(CMAKE_SOURCE_DIR STREQUAL CMAKE_CURRENT_SOURCE_DIR)
    set(MACHINEINFO_TOP_LEVEL ON)
else()
    set(MACHINEINFO_TOP_LEVEL OFF)
endif()

option(MACHINEINFO_BUILD_CLI "Build the command line adapter" ${MACHINEINFO_TOP_LEVEL})
option(MACHINEINFO_BUILD_TESTS "Build unit tests" ${MACHINEINFO_TOP_LEVEL})

set(CORE_SOURCES
    domain/models.c
    application/inventory_service.c
    adapters/inbound/json/json_writer.c
    adapters/inbound/json/report_presenter.c
)

set(API_SOURCES
    adapters/inbound/c_api.c
    adapters/outbound/platform.c
    adapters/outbound/common/text_utils.c
    adapters/outbound/common/png_writer.c
)

if(WIN32)
    list(APPEND API_SOURCES
        adapters/outbound/windows/win_utils.c
        adapters/outbound/windows/windows_hardware.c
        adapters/outbound/windows/windows_thermal.c
        adapters/outbound/windows/windows_software.c
    )
elseif(APPLE)
    list(APPEND API_SOURCES
        adapters/outbound/macos/macos_hardware.c
        adapters/outbound/macos/macos_smc.c
        adapters/outbound/macos/macos_software.c
    )
elseif(UNIX)
    list(APPEND API_SOURCES
        adapters/outbound/linux/linux_hardware.c
        adapters/outbound/linux/linux_software.c
    )
endif()

add_library(machineinfo_core STATIC ${CORE_SOURCES})
target_include_directories(machineinfo_core PUBLIC include ${CMAKE_CURRENT_SOURCE_DIR})
if(UNIX)
    target_link_libraries(machineinfo_core PUBLIC m)
endif()

add_library(machineinfo SHARED ${API_SOURCES})
target_link_libraries(machineinfo PRIVATE machineinfo_core)
target_compile_definitions(machineinfo PRIVATE MACHINEINFO_BUILDING MACHINEINFO_VERSION="${PROJECT_VERSION}")
set_target_properties(machineinfo PROPERTIES PREFIX "lib")

if(MSVC)
    target_compile_options(machineinfo_core PRIVATE /W4)
    target_compile_options(machineinfo PRIVATE /W4)
else()
    target_compile_options(machineinfo_core PRIVATE -Wall -Wextra)
    target_compile_options(machineinfo PRIVATE -Wall -Wextra)
endif()

if(WIN32)
    set_target_properties(machineinfo PROPERTIES PREFIX "")
    target_link_libraries(machineinfo PRIVATE advapi32 ole32 oleaut32 wbemuuid shell32 gdi32 user32)
elseif(APPLE)
    target_link_libraries(machineinfo PRIVATE "-framework CoreFoundation" "-framework IOKit" "-framework DiskArbitration")
endif()

if(MACHINEINFO_BUILD_CLI)
    add_executable(machineinfo-cli adapters/inbound/cli/main.c)
    target_include_directories(machineinfo-cli PRIVATE include)
    target_link_libraries(machineinfo-cli PRIVATE machineinfo)
endif()

if(MACHINEINFO_BUILD_TESTS)
    enable_testing()
    add_executable(machineinfo-tests tests/test_inventory.c tests/fake_adapters.c adapters/outbound/common/png_writer.c)
    target_link_libraries(machineinfo-tests PRIVATE machineinfo_core)
    add_test(NAME inventory COMMAND machineinfo-tests)
endif()

if(MACHINEINFO_TOP_LEVEL)
    install(TARGETS machineinfo RUNTIME DESTINATION bin LIBRARY DESTINATION lib ARCHIVE DESTINATION lib)
    install(FILES include/machineinfo/machineinfo.h DESTINATION include/machineinfo)
endif()
