program checkLib;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  np.libuv,
  np.Core;

begin
  try
    assert( uv_handle_size(UV_HANDLE) = uv_handle_size(UV_HANDLE), 'handle failed');
    assert( sizeof(uv_loop_t) = uv_loop_size, 'loop failed');
    assert( uv_handle_size(UV_ASYNC) = sizeof(uv_async_t), 'async failed');
    assert( uv_handle_size(UV_CHECK) = sizeof(uv_check_t), 'check failed');
    assert( uv_handle_size(UV_FS_EVENT_) = sizeof(uv_fs_event_t), 'fs_event failed');
    assert( uv_handle_size(UV_FS_POLL) = sizeof(uv_fs_poll_t), 'fs_poll failed');
    assert( uv_handle_size(UV_IDLE) = uv_handle_size(UV_IDLE), 'idle failed');
    assert( uv_handle_size(UV_NAMED_PIPE) = sizeof(uv_pipe_t), 'named_pipe failed');
    assert( uv_handle_size(UV_POLL) = sizeof(uv_poll_t), 'poll failed');
    assert( uv_handle_size(UV_PREPARE) = sizeof(uv_prepare_t), 'prepare failed');
    assert( uv_handle_size(UV_PROCESS) = sizeof(uv_process_t), 'process failed');
    assert( uv_handle_size(UV_STREAM) = sizeof(uv_stream_t), 'stream failed');
    assert( uv_handle_size(UV_TCP) = sizeof(uv_tcp_t), 'tcp failed');
    assert( uv_handle_size(UV_TIMER) = sizeof(uv_timer_t), 'timer failed');
    assert( uv_handle_size(UV_TTY) = sizeof(uv_tty_t), 'tty failed');
    assert( uv_handle_size(UV_UDP) = sizeof(uv_udp_t), 'udp failed');
    assert( uv_handle_size(UV_SIGNAL) = sizeof(uv_signal_t), 'signal failed');

    // WriteLn('file:', integer(uv_handle_size(UV_FILE_)),' ', integer(uv_handle_size(UV_FILE_)) - sizeof(uv_file_s) );
//    WriteLn('--req--');
    {
      #define UV_REQ_TYPE_MAP(XX)                                                   \
      XX(REQ, req)                                                                \
      XX(CONNECT, connect)                                                        \
      XX(WRITE, write)                                                            \
      XX(SHUTDOWN, shutdown)                                                      \
      XX(UDP_SEND, udp_send)                                                      \
      XX(FS, fs)                                                                  \
      XX(WORK, work)                                                              \
      XX(GETADDRINFO, getaddrinfo)                                                \
      XX(GETNAMEINFO, getnameinfo)                                                \
    }
    {
      uv_req_type = (UV_UNKNOWN_REQ = 0, UV_REQ, UV_CONNECT, UV_WRITE_, UV_SHUTDOWN_, UV_UDP_SEND_, UV_FS, UV_WORK,
      UV_GETADDRINFO_, UV_GETNAMEINFO_, UV_ACCEPT_, UV_FS_EVENT_REQ, UV_POLL_REQ,
      UV_PROCESS_EXIT, UV_READ, UV_UDP_RECV, UV_WAKEUP, UV_SIGNAL_REQ, UV_REQ_TYPE_MAX);
    }

    assert( uv_req_size(UV_REQ) = sizeof(uv_req_t), 'all requests failed');
    assert( uv_req_size(UV_CONNECT) = sizeof(uv_connect_t), 'connect request failed');
    assert( uv_req_size(UV_WRITE_) = sizeof(uv_write_t), 'write request failed');
    assert( uv_req_size(UV_SHUTDOWN_) = sizeof(uv_shutdown_t), 'shutdown request failed');
    assert( uv_req_size(UV_UDP_SEND_) = sizeof(uv_udp_send_t), 'udp_send request faield');
    assert( uv_req_size(UV_FS) = sizeof(uv_fs_t), 'fs request failed');
    assert( uv_req_size(UV_WORK) = sizeof(uv_work_t), 'work request failed');
    assert( uv_req_size(UV_GETADDRINFO_) = sizeof(uv_getaddrinfo_t), 'addrinfo request failed');
    assert( uv_req_size(UV_GETNAMEINFO_) = sizeof(uv_getnameinfo_t), 'nameinfo request failed');
    // WriteLn('accept: ', uv_req_size(UV_ACCEPT_),' ',integer( uv_req_size(UV_ACCEPT_) ) - sizeof(uv_accept_s) );

//    WriteLn('--other--');

    assert( uv_rwlock_size = sizeof(uv_rwlock_t), 'rwlock failed');
    assert( uv_cond_size = sizeof(uv_cond_t), 'cond. failed');
    assert( uv_barrier_size = sizeof(uv_barrier_t), 'barrier failed');
    assert( uv_sem_size = sizeof(uv_sem_t), 'sem. failed');
    assert( uv_mutex_size = sizeof(uv_mutex_t), 'mutex failed');
    assert( uv_os_sock_size = sizeof(uv_os_sock_t), 'os sock failed');
    assert( uv_os_fd_size = sizeof(uv_os_fd_t), 'os fd failed');
//    WriteLn('buf:', uv_buf_size, ' ', sizeof(uv_buf_t));
    // WriteLn('tcp_accept: ', uv_tcp_accept_size, ' ', integer(uv_tcp_accept_size) - sizeof(uv_tcp_accept_t));
    // WriteLn('pipe_accept: ', uv_pipe_accept_size, ' ', integer(uv_pipe_accept_size) - sizeof(uv_pipe_accept_t));
     WriteLn('PASSED');

  except
    on E: Exception do
      Writeln('FAIL: '+E.Message);
  end;
    readln;
end.



