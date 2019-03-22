#include "uv.h"
#include "http_parser.h"

//#define NP_API extern __declspec(dllexport)
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
    int O_DIRECT;
    int O_DIRECTORY;
    int O_DSYNC;
    int O_EXLOCK;
    int O_NOATIME;
    int O_NOCTTY;
    int O_NOFOLLOW;
    int O_NONBLOCK;
    int O_SYMLINK;
    int O_SYNC; 
} constants_t, *pconstants_t;

NP_API pconstants_t uv_get_constants();
