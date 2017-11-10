unit sock5client;

interface

uses sysUtils, np.core, np.buffer, np.libuv;

type
   POptions = ^TOptions;
   TOptions = record
     socksHost: string;
     socksPort: word;
     socksUserName: string;
     socksPassword: string;
   end;

   TSocks5ClientSocket = class(TEventEmitter)
     socket: INPTCPConnect;
     socksHost: string;
     socksPort: word;
     socksUserName: string;
     socksPassword: string;
     socketTimeout : int64;
     socketTimeoutCallBack : Tproc;
     constructor Create(const AsocksHost:string='';
                        ASocksPort:word=0;
                        ASocksUserName:string='';
                        AsocksPassword:string='');
     procedure setTimeout(msec: int64; callback: TProc);
     procedure setNoDelay(noDelay: Boolean);
     procedure setKeepAlive(enable: Boolean; msecs: Cardinal);
     procedure write(const data: BufferRef; const cb : TProc=nil);
     procedure connect(const Ahost: string; APort: word);
   end;

const
   ev_error = 1;


implementation

  constructor TSocks5ClientSocket.Create(const AsocksHost:string='';
                        ASocksPort:word=0;
                        ASocksUserName:string='';
                        AsocksPassword:string='');
  begin
     if AsocksHost = '' then
        socksHost := 'localhost'
     else
        socksHost := AsocksHost;
     if ASocksPort = 0 then
        socksPort := 1080
     else
        socksPort := ASocksPort;
     if ASocksUserName <> '' then
     begin
        socksUserName := ASocksUserName;
        socksPassword := AsocksPassword;
     end;
     socket := TNPTCPStream.CreateConnect;
     socket.setOnError(
         procedure (err:Integer)
         begin
           emit(ev_error, @err);
         end);

      on_(ev_error, procedure
          begin
            if (socket <> nil) then
            begin
              socket.Clear;
              socket := nil;
            end;
          end);
  end;


 procedure TSocks5ClientSocket.setTimeout(msec: int64; callback: TProc);
 begin
   	//return this.socket.setTimeout(msecs, callback);
    socketTimeout := msec;
    socketTimeoutCallBack := callBack;
 end;

 procedure TSocks5ClientSocket.setNoDelay(noDelay: Boolean);
 begin
	socket.set_nodelay(noDelay);
end;

 procedure TSocks5ClientSocket.setKeepAlive(enable: Boolean; msecs: Cardinal);
 begin
	 socket.set_keepalive(enable,msecs);
 end;


procedure TSocks5ClientSocket.write(const data:BufferRef; const cb:TProc);
begin
	socket.write(data.ref,data.length, cb);
end;

procedure TSocks5ClientSocket.connect(const Ahost: string; APort: word);
begin
	socket.connect(AHost,APort);
  socket.setOnConnect(
      procedure
      begin
         authenticateWithSocks(
             procedure
             begin
               connectSocksToHost(AHost,APort,
                          procedure
                          begin
                            onProxied;
                          end);
             end
      end);
end;

Socks5ClientSocket.prototype.onProxied = function() {
	var self = this;

	self.socket.on('close', function(hadErr) {
		self.emit('close', hadErr);
	});

	self.socket.on('end', function() {
		self.emit('end');
	});

	self.socket.on('data', function(data) {
		self.emit('data', data);
	});

	self.socket._httpMessage = self._httpMessage;
	self.socket.parser = self.parser;
	self.socket.ondata = self.ondata;
	self.writable = true;
	self.readable = true;
	self.emit('connect');
};

function authenticateWithSocks(client, cb) {
	var authMethods, buffer;

	client.socket.once('data', function(data) {
		var error, request, buffer, i, l;

		if (2 !== data.length) {
			error = 'Unexpected number of bytes received.';
		} else if (0x05 !== data[0]) {
			error = 'Unexpected SOCKS version number: ' + data[0] + '.';
		} else if (0xFF === data[1]) {
			error = 'No acceptable authentication methods were offered.';
		} else if (authMethods.indexOf(data[1]) === -1) {
			error = 'Unexpected SOCKS authentication method: ' + data[1] + '.';
		}

		if (error) {
			client.emit('error', new Error('SOCKS authentication failed. ' + error));
			return;
		}

		// Begin username and password authentication.
		if (0x02 === data[1]) {
			client.socket.once('data', function(data) {
				var error;

				if (2 !== data.length) {
					error = 'Unexpected number of bytes received.';
				} else if (0x01 !== data[0]) {
					error = 'Unexpected authentication method code: ' + data[0] + '.';
				} else if (0x00 !== data[1]) {
					error = 'Username and password authentication failure: ' + data[1] + '.';
				}

				if (error) {
					client.emit('error', new Error('SOCKS authentication failed. ' + error));
				} else {
					cb();
				}
			});

			request = [0x01];
			parseString(client.socksUsername, request);
			parseString(client.socksPassword, request);
			client.write(new Buffer(request));

		// No authentication to negotiate.
		} else {
			cb();
		}
	});

	// Add the "no authentication" method.
	authMethods = [0x00];
	if (client.socksUsername) {
		authMethods.push(0x02);
	}

	buffer = new Buffer(2 + authMethods.length);
	buffer[0] = 0x05; // SOCKS version.
	buffer[1] = authMethods.length; // Number of authentication methods.

	// Copy the authentication method codes into the request buffer.
	authMethods.forEach(function(authMethod, i) {
		buffer[2 + i] = authMethod;
	});

	client.write(buffer);
}

function connectSocksToHost(client, host, port, cb) {
	var request, buffer;

	client.socket.once('data', function(data) {
		var error;

		if (data[0] !== 0x05) {
			error = 'Unexpected SOCKS version number: ' + data[0] + '.';
		} else if (data[1] !== 0x00) {
			error = getErrorMessage(data[1]) + '.';
		} else if (data[2] !== 0x00) {
			error = 'The reserved byte must be 0x00.';
		}

		if (error) {
			client.emit('error', new Error('SOCKS connection failed. ' + error));
			return;
		}

		cb();
	});

	request = [];
	request.push(0x05); // SOCKS version.
	request.push(0x01); // Command code: establish a TCP/IP stream connection.
	request.push(0x00); // Reserved - must be 0x00.

	switch (net.isIP(host)) {

	// Add a hostname to the request.
	case 0:
		request.push(0x03);
		parseString(host, request);
		break;

	// Add an IPv4 address to the request.
	case 4:
		request.push(0x01);
		parseIPv4(host, request);
		break;
	case 6:
		request.push(0x04);
		if (parseIPv6(host, request) === false) {
			client.emit('error', new Error('IPv6 host parsing failed. Invalid address.'));
			return;
		}
		break;
	}

	// Add a placeholder for the port bytes.
	request.length += 2;

	buffer = new Buffer(request);
	buffer.writeUInt16BE(port, buffer.length - 2, true);

	client.write(buffer);
}

function parseString(string, request) {
	var buffer = new Buffer(string), i, l = buffer.length;

	// Declare the length of the following string.
	request.push(l);

	// Copy the hostname buffer into the request buffer.
	for (i = 0; i < l; i++) {
		request.push(buffer[i]);
	}
}

function parseIPv4(host, request) {
	var i, ip, groups = host.split('.');

	for (i = 0; i < 4; i++) {
		ip = parseInt(groups[i], 10);
		request.push(ip);
	}
}

function parseIPv6(host, request) {
	var i, b1, b2, part1, part2, address, groups;

	// `#canonicalForm` returns `null` if the address is invalid.
	address = new Address6(host).canonicalForm();
	if (!address) {
		return false;
	}

	groups = address.split(':');

	for (i = 0; i < groups.length; i++) {
		part1 = groups[i].substr(0,2);
		part2 = groups[i].substr(2,2);

		b1 = parseInt(part1, 16);
		b2 = parseInt(part2, 16);

		request.push(b1);
		request.push(b2);
	}

	return true;
}

function getErrorMessage(code) {
	switch (code) {
	case 1:
		return 'General SOCKS server failure';
	case 2:
		return 'Connection not allowed by ruleset';
	case 3:
		return 'Network unreachable';
	case 4:
		return 'Host unreachable';
	case 5:
		return 'Connection refused';
	case 6:
		return 'TTL expired';
	case 7:
		return 'Command not supported';
	case 8:
		return 'Address type not supported';
	default:
		return 'Unknown status code ' + code;
	}
}
