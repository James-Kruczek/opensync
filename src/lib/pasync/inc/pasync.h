/*
Copyright (c) 2015, Plume Design Inc. All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:
   1. Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
   2. Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.
   3. Neither the name of the Plume Design Inc. nor the
      names of its contributors may be used to endorse or promote products
      derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL Plume Design Inc. BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

#ifndef PASYNC_H_INCLUDED
#define PASYNC_H_INCLUDED

#include <stdlib.h>
#include <stdint.h>
#include <stdbool.h>
#include <string.h>
#include <ev.h>
#include "log.h"


typedef struct
{
    int    id;    /* user id for this async cmd */
    void  *data;  /* optional user context data */
    int    rc;    /* cmd return code or -1 if it didn't terminate normally */
} pasync_ctx_t;

/*
 * PASYNC callback function prototype
 */
typedef void (pasync_cb)(int id, void *buff, int buff_sz);

/*
 * PASYNC callback with context passing function prototype
 */
typedef void (pasync_cbx)(pasync_ctx_t *ctx, void *buff, int buff_sz);

/*
 * Async read process output implementation
 * This function invokes given command line by
 * calling popen, and reads complete
 * process output in asynchronous  manner
 *
 * Upon spawn process completion, submitted callback function is
 * invoked by async library. Buffer will contain complete process
 * output
 *
 * NOTE don't free given buffer in callback function
 *
 */
bool pasync_ropen(struct ev_loop *loop,
                  int id,
                  const char * cmd,
                  pasync_cb * cb);

/*
 * The same as pasync_ropen() except that with this function
 * arbitrary user context data can be specified and the same
 * context data will be passed in callback function when it is
 * invoked by async library.
 */
bool pasync_ropenx(struct ev_loop *loop,
                   int id,
                   void *ctx_data,
                   const char * cmd,
                   pasync_cbx * cb);

/*
 * Not yet implemented write version of async process
 * interaction. When process is ready for write accept
 * callback function is invoked
 */
bool pasync_wopen(struct ev_loop * loop,
                  int id,
                  const char * cmd,
                  pasync_cb * cb);

#endif /* PASYNC_H_INCLUDED */
