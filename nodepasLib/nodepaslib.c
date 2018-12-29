#include <stdio.h>
#include <stdlib.h>
#include "nodepaslib.h"

/*
size_t uv_tcp_accept_size() {
   return sizeof(uv_tcp_accept_t);
}

size_t uv_pipe_accept_size() {
   return sizeof(uv_pipe_accept_t);
}
*/

size_t uv_process_options_size() {
  return sizeof( uv_process_options_t );
}

size_t uv_rwlock_size() {
   return sizeof(uv_rwlock_t);
}

size_t uv_cond_size() {
   return sizeof(uv_cond_t);
}

size_t uv_barrier_size() {
   return sizeof(uv_barrier_t);
}

size_t uv_sem_size() {
  return sizeof(uv_sem_t);
}

size_t uv_mutex_size(void) {
  return sizeof(uv_mutex_t);
}

size_t uv_os_sock_size(void) {
  return sizeof( uv_os_sock_t );
}

size_t uv_os_fd_size(void) {
  return sizeof( uv_os_fd_t );
}

void uv_set_close_cb(uv_handle_t*h, uv_close_cb close_cb) {
  h->close_cb = close_cb;
}

uv_close_cb uv_get_close_cb(uv_handle_t*h) {
  return(h->close_cb);
}


uv_handle_type uv_get_handle_type(uv_handle_t*h) {
  return h->type;
}

void uv_set_user_data(uv_handle_t* h, void*data) {
   h->data = data;
}

void* uv_get_user_data(uv_handle_t* h) {
  return ( h->data );
}

uv_req_type uv_get_req_type(uv_req_t* r) {
  return (r->type);
}

NP_API int uv_get_process_pid(uv_process_t*h) {
   return (h->pid);
}

//NP_API uv_version_string_ = uv_version_string;
/*
  uv_exit_cb exit_cb;
  const char* file;
  char** args;
  char** env;
  const char* cwd;
  unsigned int flags;
  int stdio_count;
  uv_stdio_container_t* stdio;
  uv_uid_t uid;
  uv_gid_t gid;
  char* cpumask;
  size_t cpumask_size;
*/
NP_API void uv_init_process_options(uv_process_options_t * po,
                                    uv_exit_cb exit_cb,
                                    const char* file,
                                    char**args,
                                    char** env,
                                    const char * cwd,
                                    unsigned int flags,
                                    int stdio_count,
                                    uv_stdio_container_t* stdio,
                                    uv_uid_t uid,
                                    uv_gid_t gid,
                                    char* cpumask,
                                    size_t cpumask_size) {

   po->exit_cb = exit_cb;
   po->file = file;
   po->args = args;
   po->env  = env;
   po->cwd  = cwd;
   po->flags = flags;
   po->stdio_count = stdio_count;
   po->stdio = stdio;
   po->uid = uid;
   po->gid = gid;
   po->cpumask = cpumask;
   po->cpumask_size = cpumask_size;
}

