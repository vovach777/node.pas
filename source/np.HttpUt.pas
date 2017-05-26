unit np.HttpUt;

interface

function ResponseText(const AValue: Integer) : UTF8String;

implementation

const
  // HTTP Status
  RSHTTPChunkStarted = 'Chunk Started';
  RSHTTPContinue = 'Continue';
  RSHTTPSwitchingProtocols = 'Switching protocols';
  RSHTTPOK = 'OK';
  RSHTTPCreated = 'Created';
  RSHTTPAccepted = 'Accepted';
  RSHTTPNonAuthoritativeInformation = 'Non-authoritative Information';
  RSHTTPNoContent = 'No Content';
  RSHTTPResetContent = 'Reset Content';
  RSHTTPPartialContent = 'Partial Content';
  RSHTTPMovedPermanently = 'Moved Permanently';
  RSHTTPMovedTemporarily = 'Moved Temporarily';
  RSHTTPSeeOther = 'See Other';
  RSHTTPNotModified = 'Not Modified';
  RSHTTPUseProxy = 'Use Proxy';
  RSHTTPBadRequest = 'Bad Request';
  RSHTTPUnauthorized = 'Unauthorized';
  RSHTTPForbidden = 'Forbidden';
  RSHTTPNotFound = 'Not Found';
  RSHTTPMethodNotAllowed = 'Method not allowed';
  RSHTTPNotAcceptable = 'Not Acceptable';
  RSHTTPProxyAuthenticationRequired = 'Proxy Authentication Required';
  RSHTTPRequestTimeout = 'Request Timeout';
  RSHTTPConflict = 'Conflict';
  RSHTTPGone = 'Gone';
  RSHTTPLengthRequired = 'Length Required';
  RSHTTPPreconditionFailed = 'Precondition Failed';
  RSHTTPPreconditionRequired = 'Precondition Required';
  RSHTTPTooManyRequests = 'Too Many Requests';
  RSHTTPRequestHeaderFieldsTooLarge = 'Request Header Fields Too Large';
  RSHTTPNetworkAuthenticationRequired = 'Network Authentication Required';
  RSHTTPRequestEntityTooLong = 'Request Entity Too Long';
  RSHTTPRequestURITooLong = 'Request-URI Too Long. 256 Chars max';
  RSHTTPUnsupportedMediaType = 'Unsupported Media Type';
  RSHTTPExpectationFailed = 'Expectation Failed';
  RSHTTPInternalServerError = 'Internal Server Error';
  RSHTTPNotImplemented = 'Not Implemented';
  RSHTTPBadGateway = 'Bad Gateway';
  RSHTTPServiceUnavailable = 'Service Unavailable';
  RSHTTPGatewayTimeout = 'Gateway timeout';
  RSHTTPHTTPVersionNotSupported = 'HTTP version not supported';
  RSHTTPUnknownResponseCode = 'Unknown Response Code';


function ResponseText(const AValue: Integer) : UTF8String;
begin
  case AValue of
    100: ResponseText := RSHTTPContinue;
    // 2XX: Success
    200: ResponseText := RSHTTPOK;
    201: ResponseText := RSHTTPCreated;
    202: ResponseText := RSHTTPAccepted;
    203: ResponseText := RSHTTPNonAuthoritativeInformation;
    204: ResponseText := RSHTTPNoContent;
    205: ResponseText := RSHTTPResetContent;
    206: ResponseText := RSHTTPPartialContent;
    // 3XX: Redirections
    301: ResponseText := RSHTTPMovedPermanently;
    302: ResponseText := RSHTTPMovedTemporarily;
    303: ResponseText := RSHTTPSeeOther;
    304: ResponseText := RSHTTPNotModified;
    305: ResponseText := RSHTTPUseProxy;
    // 4XX Client Errors
    400: ResponseText := RSHTTPBadRequest;
    401: ResponseText := RSHTTPUnauthorized;
    403: ResponseText := RSHTTPForbidden;
    404: begin
      ResponseText := RSHTTPNotFound;
      // Close connection
    end;
    405: ResponseText := RSHTTPMethodNotAllowed;
    406: ResponseText := RSHTTPNotAcceptable;
    407: ResponseText := RSHTTPProxyAuthenticationRequired;
    408: ResponseText := RSHTTPRequestTimeout;
    409: ResponseText := RSHTTPConflict;
    410: ResponseText := RSHTTPGone;
    411: ResponseText := RSHTTPLengthRequired;
    412: ResponseText := RSHTTPPreconditionFailed;
    413: ResponseText := RSHTTPRequestEntityTooLong;
    414: ResponseText := RSHTTPRequestURITooLong;
    415: ResponseText := RSHTTPUnsupportedMediaType;
    417: ResponseText := RSHTTPExpectationFailed;
    428: ResponseText := RSHTTPPreconditionRequired;
    429: ResponseText := RSHTTPTooManyRequests;
    431: ResponseText := RSHTTPRequestHeaderFieldsTooLarge;
    // 5XX Server errors
    500: ResponseText := RSHTTPInternalServerError;
    501: ResponseText := RSHTTPNotImplemented;
    502: ResponseText := RSHTTPBadGateway;
    503: ResponseText := RSHTTPServiceUnavailable;
    504: ResponseText := RSHTTPGatewayTimeout;
    505: ResponseText := RSHTTPHTTPVersionNotSupported;
    511: ResponseText := RSHTTPNetworkAuthenticationRequired;
    else
      ResponseText := RSHTTPUnknownResponseCode;
  end;

  {if ResponseNo >= 400 then
    // Force COnnection closing when there is error during the request processing
    CloseConnection := true;
  end;}
end;


end.
