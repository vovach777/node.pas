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
