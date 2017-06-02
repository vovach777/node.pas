# node.pas
Asynchronous Event-driven framework for modern EMB Delphi 10.2
uses: libuv library
platforms: win32,win64,linux64
target: server applications

NodeJS-like ecosystem
---------------------   
* Buffer (np.buffer.pas)
* From duvLib (libuv wrapper): 
  *  loop
  *  setImmediate
  *  nextTick
  *  EventEmmiter
  *  setTimeout
  *  setInterval
  *  tcp
  *  pipe
  *  tty
  *  child process
* Http server
* Https server powered by OpenSSL 1.1
* Promises (np.promise.pas)
* Experimental Http(s)-connect (uHttpConnect.pas)

