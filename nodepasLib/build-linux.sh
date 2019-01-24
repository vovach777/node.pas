#!/bin/bash
gcc -I. -DHTTP_PARSER_STRICT=0 -shared http_parser.c nodepaslib.c -fPIC -Wl,-Bstatic -Wl,--whole-archive -luv -lssl -lcrypto -Wl,--no-whole-archive -Wl,-Bdynamic -o nodepaslib.so

