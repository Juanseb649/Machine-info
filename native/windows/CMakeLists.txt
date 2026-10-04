cmake_minimum_required(VERSION 3.14)

set(PROJECT_NAME "machine_info_native")
project(${PROJECT_NAME} LANGUAGES C CXX)

add_subdirectory("${CMAKE_CURRENT_SOURCE_DIR}/../src" "${CMAKE_CURRENT_BINARY_DIR}/shared")

set(machine_info_native_bundled_libraries
  $<TARGET_FILE:machineinfo>
  PARENT_SCOPE
)
