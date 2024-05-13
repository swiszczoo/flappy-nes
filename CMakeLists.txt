cmake_minimum_required(VERSION 3.25)

set(CMAKE_TOOLCHAIN_FILE ca65-6502-nes-toolchain.cmake)
################################################################################

project(flappy ASM)
#set here the path to file that has the main function

file(GLOB_RECURSE SOURCES "src/*.*")

################################################################################
# linking of executable
add_executable(${PROJECT_NAME} ${SOURCES})
target_compile_options(${PROJECT_NAME} PUBLIC -t nes)
target_link_options(${PROJECT_NAME} PUBLIC -t nes --config ${CMAKE_SOURCE_DIR}/rom.cfg)
set_target_properties(${PROJECT_NAME} PROPERTIES OUTPUT_NAME "flappy_bird (US).nes")
