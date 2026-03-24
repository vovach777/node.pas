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

## FPC / Lazarus Support
This project is fully compatible with Free Pascal Compiler (FPC).
To use it in Lazarus:
1. Open `NodePas.lpk` in Lazarus.
2. Click "Compile" to build the package.
3. Add the package as a requirement to your project or add the `source` directory to your project's search path.
