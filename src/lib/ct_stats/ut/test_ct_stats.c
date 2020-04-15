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

#include <errno.h>
#include <ev.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <libmnl/libmnl.h>

#include "ct_stats.h"
#include "os_types.h"
#include "target.h"
#include "unity.h"
#include "log.h"
#include "fcm_filter.h"
#include "fcm.h"
#include "neigh_table.h"

struct mnl_buf
{
	size_t len;
	uint8_t data[4096];
};

#include "mnl_dump_2.c"
#include "mnl_dump_10.c"

const char *test_name = "fcm_ct_stats_tests";

fcm_collect_plugin_t g_collector;

char *g_node_id = "4C718002B3";
char *g_loc_id = "59efd33d2c93832025330a3e";
char *g_mqtt_topic = "dev-test/ct_stats/4C718002B3/59efd33d2c93832025330a3e";

/* Gathered at sample colletion. See mnl_cb_run() implementation for details */
int g_portid = 18404;
int g_seq = 1581959512;

char *
test_get_other_config(fcm_collect_plugin_t *plugin, char *key)
{
    return "1";
}


char *
test_get_mqtt_hdr_node_id(void)
{
    return g_node_id;;
}

char *
test_get_mqtt_hdr_loc_id(void)
{
    return g_loc_id;
}

bool
test_send_report(struct net_md_aggregator *aggr, char *mqtt_topic)
{
#ifndef ARCH_X86
    bool ret;

    /* Send the report */
    ret = net_md_send_report(aggr, mqtt_topic);
    TEST_ASSERT_TRUE(ret);
    return ret;
#else
    struct packed_buffer *pb;
    pb = serialize_flow_report(aggr->report);

    /* Free the serialized container */
    free_packed_buffer(pb);
    net_md_reset_aggregator(aggr);

    return true;
#endif
}

void
setUp(void)
{
    struct neigh_table_mgr *neigh_mgr;
    struct net_md_aggregator *aggr;
    flow_stats_t *mgr;
    int rc;

    neigh_table_init();
    memset(&g_collector, 0, sizeof(g_collector));
    g_collector.get_other_config = test_get_other_config;
    g_collector.get_mqtt_hdr_node_id = test_get_mqtt_hdr_node_id;
    g_collector.get_mqtt_hdr_loc_id = test_get_mqtt_hdr_loc_id;
    g_collector.mqtt_topic = g_mqtt_topic;
    g_collector.loop = EV_DEFAULT;
    rc = ct_stats_plugin_init(&g_collector);
    TEST_ASSERT_EQUAL_INT(0, rc);

    mgr = ct_stats_get_mgr();
    TEST_ASSERT_NOT_NULL(mgr);

    aggr = mgr->aggr;
    TEST_ASSERT_NOT_NULL(aggr);
    aggr->send_report = test_send_report;

    neigh_table_init();
    neigh_mgr = neigh_table_get_mgr();
    neigh_mgr->lookup_ovsdb_tables = NULL;
}


void
tearDown(void)
{
    flow_stats_t *mgr;

    mgr = ct_stats_get_mgr();
    memset(&g_collector, 0, sizeof(g_collector));
    neigh_table_cleanup();
    net_md_free_aggregator(mgr->aggr);
    neigh_table_cleanup();
}

void
test_collect(void)
{
    ct_stats_collect_cb(&g_collector);
}


void
test_process_v4(void)
{
    ctflow_info_t *flow_info;
    struct mnl_buf *p_mnl;
    flow_stats_t *mgr;
    bool loop;
    int idx;
    int ret;

    mgr = ct_stats_get_mgr();
    TEST_ASSERT_NOT_NULL(mgr);

    loop = true;
    idx = 0;
    while (loop)
    {
        p_mnl = &g_mnl_buf_ipv4[idx];
        ret = mnl_cb_run(p_mnl->data, p_mnl->len, g_seq, g_portid, data_cb, mgr);
        if (ret == -1)
        {
            ret = errno;
            LOGE("%s: mnl_cb_run failed: %s", __func__, strerror(ret));
            loop = false;
        }
        else if (ret <= MNL_CB_STOP) loop = false;
        idx++;
    }

    ds_dlist_foreach(&mgr->ctflow_list, flow_info)
    {
        ct_stats_print_contrack(&flow_info->flow);
    }

    ct_flow_add_sample(mgr);
    g_collector.send_report(&g_collector);
}


void
test_process_v6(void)
{
    ctflow_info_t *flow_info;
    struct mnl_buf *p_mnl;
    flow_stats_t *mgr;
    bool loop;
    int idx;
    int ret;

    mgr = ct_stats_get_mgr();
    TEST_ASSERT_NOT_NULL(mgr);

    loop = true;
    idx = 0;
    while (loop)
    {
        p_mnl = &g_mnl_buf_ipv6[idx];
        ret = mnl_cb_run(p_mnl->data, p_mnl->len, g_seq, g_portid, data_cb, mgr);
        if (ret == -1)
        {
            ret = errno;
            LOGE("%s: mnl_cb_run failed: %s", __func__, strerror(ret));
            loop = false;
        }
        else if (ret <= MNL_CB_STOP) loop = false;
        idx++;
    }

    ds_dlist_foreach(&mgr->ctflow_list, flow_info)
    {
        ct_stats_print_contrack(&flow_info->flow);
    }
    ct_flow_add_sample(mgr);
    g_collector.send_report(&g_collector);
}

void
test_ct_stat_v4(void)
{
    ctflow_info_t *flow_info;
    flow_stats_t *mgr;
    int ret;

    mgr = ct_stats_get_mgr();
    TEST_ASSERT_NOT_NULL(mgr);

    ret = ct_stats_get_ct_flow(AF_INET);
    TEST_ASSERT_EQUAL_INT(ret, 0);

    ds_dlist_foreach(&mgr->ctflow_list, flow_info)
    {
        ct_stats_print_contrack(&flow_info->flow);
    }

    ct_flow_add_sample(mgr);
    g_collector.send_report(&g_collector);
}

void
test_ct_stat_v6(void)
{
    ctflow_info_t *flow_info;
    flow_stats_t *mgr;
    int ret;

    mgr = ct_stats_get_mgr();
    TEST_ASSERT_NOT_NULL(mgr);

    ret = ct_stats_get_ct_flow(AF_INET6);
    TEST_ASSERT_EQUAL_INT(ret, 0);

    ds_dlist_foreach(&mgr->ctflow_list, flow_info)
    {
        ct_stats_print_contrack(&flow_info->flow);
    }

    ct_flow_add_sample(mgr);
    g_collector.send_report(&g_collector);
}

int
main(int argc, char *argv[])
{
    (void)argc;
    (void)argv;

    target_log_open("TEST", LOG_OPEN_STDOUT);
    log_severity_set(LOG_SEVERITY_TRACE);

    UnityBegin(test_name);

    RUN_TEST(test_process_v4);
    RUN_TEST(test_process_v6);
#if !defined(__x86_64__)
    RUN_TEST(test_ct_stat_v4);
    RUN_TEST(test_ct_stat_v6);
#endif


    return UNITY_END();
}
