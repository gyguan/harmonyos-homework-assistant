cmake_minimum_required(VERSION 3.5.0)
project(homeworkcapture)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

add_library(homeworkcapture SHARED homework_capture_napi.cpp)

# The HarmonyOS/OpenHarmony SDK toolchain injects --gcc-toolchain=<sdk>/native/llvm
# into Clang invocations. Current Clang does not consume that driver argument and emits
# -Wunused-command-line-argument for both arm64-v8a and x86_64. Keep the SDK-managed
# toolchain untouched and suppress only this known driver diagnostic for this native target.
target_compile_options(homeworkcapture PRIVATE
  -Wno-unused-command-line-argument
)

target_link_libraries(homeworkcapture PUBLIC
  libace_napi.z.so
  libhilog_ndk.z.so
  libnative_avscreen_capture.so
  libnative_buffer.so
  libnative_media_core.so
  libnative_display_manager.so
)
