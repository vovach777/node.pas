# node.pas & nodepaslib
Asynchronous Event-driven server applications framework

# nodepaslib (libnodepas.so, nodepaslib32.dll, nodepaslib64.dll)

One dynamic library configured to use two static libraries in Delphi:

* libuv-v1.32.0
* openssl-1.1.1d

also compilled-in misc functions and http_parser.

Support platforms: Win32, Win64, Linux64

# node.pas framework

The idea of the framework is to develop a server application with the Delphi language using the NodeJS approach.
The framework is based on Delphi closures.

NodeJS-like ecosystem
---------------------
* Buffer
* loop
* setImmediate/nextTick
* setTimeout/setInterval
* udp/tcp/pipe/tty
* shared handle over pipes
* fs/fswatch
* child process
* Http(s) server/client
* EventEmitter
* Promises
* JSON (Number values is integer for now)
* JS-like Object/Array (JSON also. Number is Double or int64)

- There is no Streams for now!
- There is no documentation yet. But since the syntax is close to Node, it will be easy to understand the examples presented.

