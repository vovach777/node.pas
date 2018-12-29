unit np.http_parser;

interface

const
  HTTP_PARSER_LIB = 'nodepaslib64.dll';
  UF_MAX = 7;
type
    SIZE_T = NativeUInt;
    psize_t = ^SIZE_T;
    SSIZE_T = NativeInt;

{$MinEnumSize 4}
   Tparser_type = ( HTTP_REQUEST, HTTP_RESPONSE, HTTP_BOTH );
   THttp_method = ( HTTP_DELETE = 0, HTTP_GET = 1, HTTP_HEAD = 2, HTTP_POST = 3, HTTP_PUT = 4, HTTP_CONNECT = 5, HTTP_OPTIONS = 6, HTTP_TRACE = 7, HTTP_COPY = 8, HTTP_LOCK = 9, HTTP_MKCOL = 10, HTTP_MOVE = 11, HTTP_PROPFIND = 12, HTTP_PROPPATCH = 13, HTTP_SEARCH = 14, HTTP_UNLOCK = 15, HTTP_BIND = 16, HTTP_REBIND = 17, HTTP_UNBIND = 18, HTTP_ACL = 19, HTTP_REPORT = 20, HTTP_MKACTIVITY = 21, HTTP_CHECKOUT = 22, HTTP_MERGE = 23, HTTP_MSEARCH = 24, HTTP_NOTIFY = 25, HTTP_SUBSCRIBE = 26, HTTP_UNSUBSCRIBE = 27, HTTP_PATCH = 28, HTTP_PURGE = 29, HTTP_MKCALENDAR = 30, HTTP_LINK = 31, HTTP_UNLINK = 32, HTTP_SOURCE = 33);
   THttp_status = ( HTTP_STATUS_CONTINUE = 100, HTTP_STATUS_SWITCHING_PROTOCOLS = 101, HTTP_STATUS_PROCESSING = 102, HTTP_STATUS_OK = 200, HTTP_STATUS_CREATED = 201, HTTP_STATUS_ACCEPTED = 202, HTTP_STATUS_NON_AUTHORITATIVE_INFORMATION = 203, HTTP_STATUS_NO_CONTENT = 204, HTTP_STATUS_RESET_CONTENT = 205, HTTP_STATUS_PARTIAL_CONTENT = 206, HTTP_STATUS_MULTI_STATUS = 207, HTTP_STATUS_ALREADY_REPORTED = 208, HTTP_STATUS_IM_USED = 226, HTTP_STATUS_MULTIPLE_CHOICES = 300, HTTP_STATUS_MOVED_PERMANENTLY = 301, HTTP_STATUS_FOUND = 302, HTTP_STATUS_SEE_OTHER = 303, HTTP_STATUS_NOT_MODIFIED = 304, HTTP_STATUS_USE_PROXY = 305, HTTP_STATUS_TEMPORARY_REDIRECT = 307, HTTP_STATUS_PERMANENT_REDIRECT = 308, HTTP_STATUS_BAD_REQUEST = 400, HTTP_STATUS_UNAUTHORIZED = 401, HTTP_STATUS_PAYMENT_REQUIRED = 402, HTTP_STATUS_FORBIDDEN = 403, HTTP_STATUS_NOT_FOUND = 404, HTTP_STATUS_METHOD_NOT_ALLOWED = 405, HTTP_STATUS_NOT_ACCEPTABLE = 406, HTTP_STATUS_PROXY_AUTHENTICATION_REQUIRED = 407, HTTP_STATUS_REQUEST_TIMEOUT = 408, HTTP_STATUS_CONFLICT = 409, HTTP_STATUS_GONE = 410, HTTP_STATUS_LENGTH_REQUIRED = 411, HTTP_STATUS_PRECONDITION_FAILED = 412, HTTP_STATUS_PAYLOAD_TOO_LARGE = 413, HTTP_STATUS_URI_TOO_LONG = 414, HTTP_STATUS_UNSUPPORTED_MEDIA_TYPE = 415, HTTP_STATUS_RANGE_NOT_SATISFIABLE = 416, HTTP_STATUS_EXPECTATION_FAILED = 417, HTTP_STATUS_MISDIRECTED_REQUEST = 421, HTTP_STATUS_UNPROCESSABLE_ENTITY = 422, HTTP_STATUS_LOCKED = 423, HTTP_STATUS_FAILED_DEPENDENCY = 424, HTTP_STATUS_UPGRADE_REQUIRED = 426, HTTP_STATUS_PRECONDITION_REQUIRED = 428, HTTP_STATUS_TOO_MANY_REQUESTS = 429, HTTP_STATUS_REQUEST_HEADER_FIELDS_TOO_LARGE = 431, HTTP_STATUS_UNAVAILABLE_FOR_LEGAL_REASONS = 451, HTTP_STATUS_INTERNAL_SERVER_ERROR = 500, HTTP_STATUS_NOT_IMPLEMENTED = 501, HTTP_STATUS_BAD_GATEWAY = 502, HTTP_STATUS_SERVICE_UNAVAILABLE = 503, HTTP_STATUS_GATEWAY_TIMEOUT = 504, HTTP_STATUS_HTTP_VERSION_NOT_SUPPORTED = 505, HTTP_STATUS_VARIANT_ALSO_NEGOTIATES = 506, HTTP_STATUS_INSUFFICIENT_STORAGE = 507, HTTP_STATUS_LOOP_DETECTED = 508, HTTP_STATUS_NOT_EXTENDED = 510, HTTP_STATUS_NETWORK_AUTHENTICATION_REQUIRED = 511 );

{$MinEnumSize 1}
  Thttp_flag = ( F_CHUNKED, F_CONNECTION_KEEP_ALIVE, F_CONNECTION_CLOSE, F_CONNECTION_UPGRADE, F_TRAILING, F_UPGRADE, F_SKIPBODY,F_CONTENTLENGTH);
  Thttp_flags = set of Thttp_flag;

{$MinEnumSize 1}
  Thttp_errno = (HPE_OK, HPE_CB_message_begin, HPE_CB_url, HPE_CB_header_field, HPE_CB_header_value, HPE_CB_headers_complete, HPE_CB_body, HPE_CB_message_complete, HPE_CB_status, HPE_CB_chunk_header, HPE_CB_chunk_complete, HPE_INVALID_EOF_STATE, HPE_HEADER_OVERFLOW, HPE_CLOSED_CONNECTION, HPE_INVALID_VERSION, HPE_INVALID_STATUS, HPE_INVALID_METHOD, HPE_INVALID_URL, HPE_INVALID_HOST, HPE_INVALID_PORT, HPE_INVALID_PATH, HPE_INVALID_QUERY_STRING, HPE_INVALID_FRAGMENT, HPE_LF_EXPECTED, HPE_INVALID_HEADER_TOKEN, HPE_INVALID_CONTENT_LENGTH, HPE_UNEXPECTED_CONTENT_LENGTH, HPE_INVALID_CHUNK_SIZE, HPE_INVALID_CONSTANT, HPE_INVALID_INTERNAL_STATE, HPE_STRICT, HPE_PAUSED, HPE_UNKNOWN);

   PHttp_parser = ^Thttp_parser;
   //32 bytes
   Thttp_parser = record
      bit_stuff : Cardinal;
      nread : Cardinal;
      content_length: uint64;
      http_major : word;
      http_minor : word;
      bit_stuff2: Cardinal;
      data : Pointer;
   end;

   http_cb = function ( parser: PHttp_parser) : integer; cdecl;
   http_data_cb = function (parser: PHttp_parser; const at: PAnsiChar; len:SIZE_T) : integer; cdecl;

   PHttp_parser_Settings = ^THttp_parser_Settings;
   THttp_parser_Settings = record
      on_message_begin: http_cb;
      on_url: http_data_cb;
      on_status: http_data_cb;
      on_header_field: http_data_cb;
      on_header_value: http_data_cb;
      on_headers_complete: http_cb;
      on_body : http_data_cb;
      on_message_complete: http_cb;

      on_chunk_header : http_cb;
      on_chunk_complete: http_cb;
   end;



  {$MinEnumSize 2}
   Thttp_parser_url_fields = (
   UF_SCHEMA = 0
  , UF_HOST = 1
  , UF_PORT = 2
  , UF_PATH = 3
  , UF_QUERY = 4
  , UF_FRAGMENT = 5
  , UF_USERINFO = 6);

  //32 bytes
  Thttp_parser_url = record
     field_set : Thttp_parser_url_fields;
     port : word;
     field_data: array [1..UF_MAX] of record
        off: word;
        len: word;
        end;
     end;

procedure http_parser_init(var parser:Thttp_Parser; parser_type : Tparser_type); cdecl; external HTTP_PARSER_LIB;
procedure http_parser_settings_init(settings : phttp_parser_settings); cdecl; external HTTP_PARSER_LIB;
function http_parser_execute(parser:Phttp_Parser; const ps: Thttp_parser_settings; const data: PAnsiChar; len: SIZE_T): size_t; cdecl; external HTTP_PARSER_LIB;
function http_should_keep_alive(const parser:Thttp_Parser) : integer; cdecl; external HTTP_PARSER_LIB;
function http_method_str(m : THttp_method) : PAnsiChar; cdecl; external HTTP_PARSER_LIB;
function http_status_str( s: THttp_status) : PAnsiChar; cdecl; external HTTP_PARSER_LIB;
function http_errno_name( err: Thttp_errno) : PAnsiChar; cdecl; external HTTP_PARSER_LIB;
function http_errno_description( err: Thttp_errno) : PAnsiChar; cdecl; external HTTP_PARSER_LIB;
procedure http_parser_url_init(var u : Thttp_parser_url); cdecl; external HTTP_PARSER_LIB;
function http_parser_parse_url(const buf: PansiChar; buflen : size_t; is_connect: integer;var u : Thttp_parser_url): integer; cdecl; external HTTP_PARSER_LIB;
procedure http_parser_pause(parser : Phttp_parser; paused : integer); cdecl; external HTTP_PARSER_LIB;
function http_body_is_final(const parser : Thttp_parser) : integer; cdecl; external HTTP_PARSER_LIB;
function http_message_needs_eof(const parser : Thttp_parser) : integer; cdecl; external HTTP_PARSER_LIB;
procedure http_parser_set_max_header_size(sz : Cardinal); cdecl; external HTTP_PARSER_LIB;
function http_parser_version : cardinal; cdecl; external HTTP_PARSER_LIB;

implementation

end.
