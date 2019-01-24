unit np.OpenSSL;

interface
  uses np.common;
const

{$IFDEF WIN64}
   LIBCRYPTO = NODEPAS_LIB;
   LIBSSL =    NODEPAS_LIB;
{$ENDIF}
{$IFDEF WIN32}
   LIBCRYPTO = NODEPAS_LIB;
   LIBSSL =    NODEPAS_LIB;
{$ENDIF}
{$IFDEF LINUX64}
   LIBCRYPTO = NODEPAS_LIB;
   LIBSSL =    NODEPAS_LIB;
{$ENDIF}

   SSL_VERIFY_NONE                 = 0;
   SSL_VERIFY_PEER                 = 1;
   SSL_VERIFY_FAIL_IF_NO_PEER_CERT = 2;
   SSL_VERIFY_CLIENT_ONCE          = 4;

   SSL_ERROR_WANT_READ            = 2;
   SSL_ERROR_WANT_WRITE           = 3;
   SSL_ERROR_SYSCALL              = 5;

   BIO_C_SET_BUF_MEM_EOF_RETURN   =   130; (* return end of input value *)
   BIO_CTRL_EOF            = 2;
   TLS_ST_OK = 1;
   X509_FILETYPE_PEM     =  1;
   X509_FILETYPE_ASN1    =  2;
   X509_FILETYPE_DEFAULT =  3;
   SSL_FILETYPE_PEM  = X509_FILETYPE_PEM;
   SSL_FILETYPE_ASN1 = X509_FILETYPE_ASN1;

   SSL_OP_ALL              = $80000BFF;
   SSL_OP_NO_SSLv2         = $01000000;
   SSL_OP_NO_SSLv3         = $02000000;
   SSL_OP_NO_COMPRESSION   = $00020000;
   SSL_CTRL_OPTIONS        = 32;
   SSL_CTRL_SET_READ_AHEAD = 41;

 SSL_CTRL_SET_MIN_PROTO_VERSION        =  123;
 SSL_CTRL_SET_MAX_PROTO_VERSION        =  124;



type
   TSSL_METHOD = type pointer;
   TSSL_CTX    = type pointer;
   TSSL        = type pointer;
   TBIO        = type pointer;
   TBIO_METHOD = type pointer;
   TSSL_COMP   = type pointer;

   TSSLCallBack = function : integer; cdecl;
   {$IFDEF NEXTGEN}
     PAnsiChar = MarshaledAString;
   {$ENDIF}



// ---- init lib -----
//   procedure SSL_library_init(); cdecl; external LIBSSL;
//   procedure SSL_load_error_strings; cdecl; external LIBSSL;
//   procedure ERR_load_BIO_strings;  cdecl; external LIBCRYPTO;
//   procedure ERR_load_crypto_strings; cdecl; external LIBCRYPTO;
//   procedure OPENSSL_add_all_algorithms_noconf; cdecl; external LIBCRYPTO;
//   procedure OPENSSL_add_all_algorithms_conf; cdecl; external LIBCRYPTO;
//   procedure OPENSSL_load_builtin_modules; cdecl; external LIBCRYPTO;
// -----------------------
// ---- shutdown lib -----
//   procedure ERR_remove_state(A:Integer); cdecl; external LIBCRYPTO;
//   procedure ENGINE_cleanup; cdecl; external LIBCRYPTO;
//   procedure CONF_modules_unload(A:Integer); cdecl; external LIBCRYPTO;
//   procedure ERR_free_strings; cdecl; external LIBCRYPTO;
//   procedure EVP_cleanup; cdecl; external LIBCRYPTO;
//   procedure CRYPTO_cleanup_all_ex_data; cdecl; external LIBCRYPTO;
//   function  SSL_COMP_get_compression_methods : TSSL_COMP; cdecl; external LIBCRYPTO;
    procedure OPENSSL_cleanup(); cdecl; external LIBCRYPTO;

// -----------------------

//   function  SSLv23_client_method()  : TSSL_METHOD; cdecl; external LIBSSL;
//   function  SSLv23_server_method()  : TSSL_METHOD; cdecl; external LIBSSL;
//   function  SSLv3_server_method()  : TSSL_METHOD; cdecl; external LIBSSL;
//   function  TLSv1_server_method()  : TSSL_METHOD; cdecl; external LIBSSL;
//   function  SSLv3_client_method() : TSSL_METHOD; cdecl; external LIBSSL;
//   function  TLSv1_client_method() : TSSL_METHOD; cdecl; external LIBSSL;
//   function  TLSv1_1_client_method() : TSSL_METHOD; cdecl; external LIBSSL;
//   function  TLSv1_2_client_method() : TSSL_METHOD; cdecl; external LIBSSL;
   function  TLS_server_method : TSSL_METHOD; cdecl; external LIBSSL;
   function  TLS_client_method() : TSSL_METHOD; cdecl; external LIBSSL;


   function  SSL_CTX_use_certificate_chain_file(ACTX: TSSL_CTX; const AFileName: PAnsiChar) : integer;  cdecl; external LIBSSL;
   function SSL_CTX_use_PrivateKey_file(ACTX: TSSL_CTX; const AfileName: PAnsiChar;Atype : integer) : integer;  cdecl; external LIBSSL;
   function SSL_CTX_use_certificate_file(ACTX: TSSL_CTX;const AfileName: PAnsiChar;Atype : integer) : integer;  cdecl; external LIBSSL;
   function  SSL_CTX_check_private_key(ACTX: TSSL_CTX) : integer;  cdecl; external LIBSSL;
   procedure SSL_CTX_set_default_passwd_cb_userdata(ASSL: TSSL_CTX; u: pointer );cdecl; external LIBSSL;
   procedure SSL_CTX_set_verify(ACTX: TSSL_CTX; mode:integer; callback : TSSLCallBack); cdecl; external LIBSSL;

   function SSL_CTX_ctrl(ACTX: TSSL_CTX; cmd:integer; larg:integer; parg:Pointer) : integer; cdecl; external LIBSSL;


   function  SSL_CTX_new(Amethod:TSSL_METHOD) : TSSL_CTX; cdecl; external LIBSSL;
   procedure SSL_CTX_free(ACTX: TSSL_CTX); cdecl; external LIBSSL;
   function  SSL_new(ACTX: TSSL_CTX) : TSSL; cdecl; external LIBSSL;
   procedure SSL_free(ASSL:TSSL); cdecl; external LIBSSL;
   //function SSL_state(ASSL:TSSL) : integer; cdecl; external LIBSSL;
   function SSL_shutdown(ASSL:TSSL) : integer; cdecl; external LIBSSL;
   function SSL_ctrl(ACTX: TSSL; cmd:integer; larg:integer; parg:Pointer) : integer; cdecl; external LIBSSL;
   procedure SSL_set_accept_state(ASSL: TSSL); cdecl; external LIBSSL;


//  void SSL_set_verify(SSL *s, int mode, SSL_verify_cb callback);
   procedure SSL_set_verify(ACTX: TSSL; AMode:Integer; Acallback: TSSLCallBack); cdecl; external LIBSSL;
// void SSL_set_bio(SSL *s, BIO *rbio, BIO *wbio);
   procedure SSL_set_bio(Assl:TSSL; ARBIO:TBIO; AWBIO:TBIO); cdecl; external LIBSSL;
   procedure SSL_set_connect_state(Assl:TSSL); cdecl; external LIBSSL;
   function SSL_do_handshake(Assl:TSSL): integer;  cdecl; external LIBSSL;
  function SSL_get_error (ASSL:TSSL; ret_code : integer) : integer; cdecl; external LIBSSL;

  function  SSL_read(ASSL:TSSL; ABuf:PByte; ALen:integer) : integer; cdecl; external LIBSSL;
  function  SSL_peek(ASSL:TSSL; ABuf:PByte; ALen:integer) : integer; cdecl; external LIBSSL;
  function  SSL_write(ASSL:TSSL; ABuf:PByte; ALen:integer) : integer; cdecl; external LIBSSL;



   function BIO_new(Anethod: TBIO_METHOD) : TBIO; cdecl; external LIBCRYPTO;
   function BIO_s_mem : TBIO_METHOD; cdecl; external LIBCRYPTO;
   function BIO_read(ABIO:TBIO;AData:PBYTE; ALen:integer) : integer; cdecl; external LIBCRYPTO;
   function BIO_write(ABIO:TBIO;AData:PBYTE; ALen:integer) : integer; cdecl; external LIBCRYPTO;
   function BIO_ctrl_pending(ABIO:TBIO) : integer; cdecl; external LIBCRYPTO;
   function BIO_ctrl_wpending(ABIO:TBIO) : integer; cdecl; external LIBCRYPTO;
//long BIO_ctrl(BIO *bp, int cmd, long larg, void *parg);
   function BIO_ctrl (ABIO:TBIO; ACMD:integer; AArg:integer; APArg:Pointer) :integer; cdecl; external LIBCRYPTO;

   function BIO_set_mem_eof_return(ABIO:TBIO; Value:integer) : integer;
//   function SSL_is_init_finished(Assl:TSSL): Boolean;
   function SSL_is_init_finished(Assl:TSSL): Boolean; cdecl; external LIBSSL;

   function is_SSL_ok : Boolean;

implementation

   function BIO_set_mem_eof_return(ABIO:TBIO; Value:integer) : integer;
   begin
     result := BIO_ctrl(ABIO,BIO_C_SET_BUF_MEM_EOF_RETURN,Value,nil);
   end;

//   function SSL_is_init_finished(Assl:TSSL): Boolean;
//   begin
//     result := SSL_state(Assl) = TLS_ST_OK;
//   end;

  procedure SSL_init_lib;
  begin
//    SSL_library_init();
//    OPENSSL_add_all_algorithms_conf();
//    SSL_load_error_strings();
//    ERR_load_BIO_strings();
//    ERR_load_crypto_strings();
  end;

  procedure SSL_final_lib;
  begin
    OPENSSL_cleanup;
//    ERR_remove_state(0);
//    ENGINE_cleanup();
//    CONF_modules_unload(1);
//    ERR_free_strings();
//    EVP_cleanup();
//    //  sk_SSL_COMP_free(SSL_COMP_get_compression_methods());
//    CRYPTO_cleanup_all_ex_data();
  end;
var
 g_was_init : Boolean = false;

   function is_SSL_ok : Boolean;
   begin
      result := g_was_init;
   end;

initialization
 try
   SSL_init_lib;
   g_was_init := true;
 except
 end;

finalization
  if g_was_init then
    SSL_final_lib;

end.