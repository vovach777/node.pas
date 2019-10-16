#include "uv.h"
#include "http_parser.h"

//int NP_API extern __declspec(dllexport)
#define NP_API
// __declspec(dllexport)
//__declspec(dllexport)

NP_API size_t uv_rwlock_size();
NP_API size_t uv_cond_size();
NP_API size_t uv_barrier_size();
NP_API size_t uv_sem_size();
NP_API size_t uv_mutex_size();
NP_API size_t uv_os_sock_size();
NP_API size_t uv_os_fd_size();
//NP_API size_t uv_tcp_accept_size(void);
//NP_API size_t uv_pipe_accept_size(void);
NP_API void uv_set_close_cb(uv_handle_t*h, uv_close_cb close_cb);
NP_API uv_close_cb uv_get_close_cb(uv_handle_t*h);

NP_API uv_handle_type uv_get_handle_type(uv_handle_t*h);
NP_API void uv_set_user_data(uv_handle_t* h, void*data);
NP_API void* uv_get_user_data(uv_handle_t* h);
NP_API uv_req_type uv_get_req_type(uv_req_t* r);

NP_API size_t uv_process_options_size();
NP_API unsigned int http_parser_get_method(const http_parser * parser);
NP_API unsigned int http_parser_get_status_code(const http_parser * parser);
NP_API unsigned int http_parser_get_http_errno(const http_parser * parser);
NP_API unsigned int http_parser_get_http_upgrade(const http_parser * parser);
NP_API unsigned int http_parser_get_flags(const http_parser * parser);

typedef struct constants_tag {
/* fs open() flags supported on other platforms (or mapped on this platform): */
    int uv_fs_o_direct;
    int uv_fs_o_directory;
    int uv_fs_o_dsync;
    int uv_fs_o_exlock;
    int uv_fs_o_noatime;
    int uv_fs_o_noctty;
    int uv_fs_o_nofollow;
    int uv_fs_o_nonblock;
    int uv_fs_o_symlink;
    int uv_fs_o_sync;

/* fs open() flags supported on this platform: */
    int uv_fs_o_append;
    int uv_fs_o_creat;
    int uv_fs_o_excl;
    int uv_fs_o_random;
    int uv_fs_o_rdonly;
    int uv_fs_o_rdwr;
    int uv_fs_o_sequential;
    int uv_fs_o_short_lived;
    int uv_fs_o_temporary;
    int uv_fs_o_trunc;
    int uv_fs_o_wronly;
    int f_ok;
    int r_ok;
    int w_ok;
    int x_ok;

} constants_t, *pconstants_t;

NP_API pconstants_t uv_get_constants();
