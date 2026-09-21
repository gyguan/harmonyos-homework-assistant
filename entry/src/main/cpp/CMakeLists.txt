cmake_minimum_required(VERSION 3.5.0)
project(homeworkcapture)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

add_library(homeworkcapture SHARED homework_capture_napi.cpp)

target_link_libraries(homeworkcapture PUBLIC
  libace_napi.z.so
  libhilog_ndk.z.so
  libnative_avscreen_capture.so
  libnative_buffer.so
  libnative_media_core.so
  libnative_display_manager.so
)
