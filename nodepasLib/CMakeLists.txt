cmake_minimum_required(VERSION 3.16)
project(nodepaslib C)

set(CMAKE_C_STANDARD 99)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)
add_definitions(-DHTTP_PARSER_STRICT=0)

# Имя выходного файла
if(WIN32)
    if(CMAKE_SIZEOF_VOID_P EQUAL 8)
        set(OUTPUT_NAME "nodepaslib64")
    else()
        set(OUTPUT_NAME "nodepaslib32")
    endif()
else()
    set(OUTPUT_NAME "nodepas")
endif()

# --- ПОИСК ЗАВИСИМОСТЕЙ ---
set(OPENSSL_USE_STATIC_LIBS TRUE)
find_package(libuv CONFIG REQUIRED)
find_package(OpenSSL REQUIRED)

# --- ИСХОДНИКИ ---
set(SOURCES nodepaslib.c http_parser.c)

# --- ИСПОЛЬЗОВАНИЕ .DEF ФАЙЛА (Windows/MSVC) ---
if(MSVC OR CMAKE_C_SIMULATE_ID MATCHES "MSVC")
    # Теперь берем файл напрямую из исходников, так как он поддерживается вручную
    set(DEF_FILE "${CMAKE_CURRENT_SOURCE_DIR}/nodepaslib.def")

    if(EXISTS "${DEF_FILE}")
        list(APPEND SOURCES "${DEF_FILE}")
    else()
        message(FATAL_ERROR "Definition file ${DEF_FILE} not found! Required for exports.")
    endif()

    # Список целей для принудительного включения всех символов (для экспорта через DEF)
    set(SCAN_TARGETS libuv::uv_a OpenSSL::SSL OpenSSL::Crypto)
endif()

# --- СБОРКА DLL ---
add_library(nodepaslib SHARED ${SOURCES})
set_target_properties(nodepaslib PROPERTIES OUTPUT_NAME ${OUTPUT_NAME})
target_include_directories(nodepaslib PRIVATE ${CMAKE_CURRENT_SOURCE_DIR})

target_link_libraries(nodepaslib PRIVATE
    libuv::uv_a OpenSSL::SSL OpenSSL::Crypto
    crypt32.lib ws2_32.lib psapi.lib userenv.lib advapi32.lib
)

if(MSVC OR CMAKE_C_SIMULATE_ID MATCHES "MSVC")
    # Используем /WHOLEARCHIVE для статических библиотек, чтобы все функции из DEF были найдены
    foreach(tgt ${SCAN_TARGETS})
        target_link_options(nodepaslib PRIVATE "/WHOLEARCHIVE:$<TARGET_FILE:${tgt}>")
    endforeach()
    set_target_properties(nodepaslib PROPERTIES MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")
endif()
