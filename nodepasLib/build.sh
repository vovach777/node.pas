#!/bin/bash

libs_whole='-luv -lssl -lcrypto'
libs_deps=''
opt='-shared -fPIC'
static_libs=''

case "$(uname -s)" in
   Linux*)
            libname='libnodepas.so'
            prefix='/usr/local'
            libs_deps='-Wl,-Bdynamic'
            ;;
   MINGW32*)
            libname=nodepaslib32.dll
            prefix='/mingw32/local'
            libs_deps='-lpthread -lws2_32 -lpsapi -liphlpapi -lshell32 -lsecur32 -luserenv -luser32'
            opt+=' -static'
            ;;
   MINGW64*)
            libname=nodepaslib64.dll
            prefix='/mingw64/local'
            libs_deps='-lpthread -lws2_32 -lpsapi -liphlpapi -lshell32 -lsecur32 -luserenv -luser32'
            opt+=' -static'
            ;;
   *)    exit 1;;
esac

gcc -v -I. -DHTTP_PARSER_STRICT=0 $opt nodepaslib.c http_parser.c -Wl,-Bstatic $static_libs -Wl,--whole-archive -L"${prefix}/lib" $libs_whole -Wl,--no-whole-archive $libs_deps -o $libname
