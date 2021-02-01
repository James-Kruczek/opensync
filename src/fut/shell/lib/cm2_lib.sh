#!/bin/sh

# Copyright (c) 2015, Plume Design Inc. All rights reserved.
# 
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#    1. Redistributions of source code must retain the above copyright
#       notice, this list of conditions and the following disclaimer.
#    2. Redistributions in binary form must reproduce the above copyright
#       notice, this list of conditions and the following disclaimer in the
#       documentation and/or other materials provided with the distribution.
#    3. Neither the name of the Plume Design Inc. nor the
#       names of its contributors may be used to endorse or promote products
#       derived from this software without specific prior written permission.
# 
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL Plume Design Inc. BE LIABLE FOR ANY
# DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
# ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


# Include basic environment config
if [ -e "/tmp/fut_set_env.sh" ]; then
    source /tmp/fut_set_env.sh
else
    source "${FUT_TOPDIR}/shell/config/default_shell.sh"
fi
# Sourcing guard variable
export CM2_LIB_SOURCED=True

source "${FUT_TOPDIR}/shell/lib/unit_lib.sh"
source "${LIB_OVERRIDE_FILE}"

####################### INFORMATION SECTION - START ###########################
#
#   Base library of common Connection Manager functions
#
####################### INFORMATION SECTION - STOP ############################

####################### SETUP SECTION - START #################################

###############################################################################
# DESCRIPTION:
#   Function prepares device for CM tests.
#   Can be used with parameter to wait for bluetooth payload from CM.
#   Can be used with parameter to make device a gateway, adding WAN interface
#   to bridge.
#   Raises an exception on fail.
# INPUT PARAMETER(S):
#   $1  interface name (optional, default: eth0)
#   $2  is gateway (optional, default: true)
# RETURNS:
#   0   On success.
#   See description.
# USAGE EXAMPLE(S):
#   cm_setup_test_environment
#   cm_setup_test_environment eth0 true
#   cm_setup_test_environment eth0 false
###############################################################################
cm_setup_test_environment()
{
    fn_name="cm2_lib:cm_setup_test_environment"
    cm2_if_name=${1:-eth0}
    cm2_is_gw=${2:-true}

    log -deb "$fn_name - Running CM2 setup"

    device_init ||
        raise "FAIL: Could not initialize device: device_init" -l "$fn_name" -ds

    cm_disable_fatal_state ||
        raise "FAIL: Could not disable fatal state: cm_disable_fatal_state" -l "$fn_name" -ds

    start_openswitch ||
        raise "FAIL: Could not start OpenvSwitch: start_openswitch" -l "$fn_name" -ds

    manipulate_iptables_protocol unblock DNS ||
        raise "FAIL: Could not unblock DNS traffic: manipulate_iptables_protocol unblock DNS" -l "$fn_name" -ds

    manipulate_iptables_protocol unblock SSL ||
        raise "FAIL: Could not unblock SSL traffic: manipulate_iptables_protocol unblock SSL" -l "$fn_name" -ds

    # This needs to execute before we start the managers. Flow is essential.
    if [ "$cm2_is_gw" == "true" ]; then
        add_bridge_interface br-wan "$cm2_if_name" ||
            raise "FAIL: Could not add interface to br-wan bridge: add_bridge_interface br-wan $cm2_if_name" -l "$fn_name" -ds
    fi

    start_specific_manager cm -v ||
        raise "FAIL: Could not start manager: start_specific_manager cm" -l "$fn_name" -ds

    start_specific_manager nm ||
        raise "FAIL: Could not start manager: start_specific_manager nm" -l "$fn_name" -ds

    start_if_specific_manager wano ||
        raise "FAIL: Could not start manager: start_if_specific_manager wano" -l "$fn_name" -ds

    empty_ovsdb_table AW_Debug ||
        raise "FAIL: Could not empty table: empty_ovsdb_table AW_Debug" -l "$fn_name" -ds

    set_manager_log CM TRACE ||
        raise "FAIL: Could not set manager log severity: set_manager_log CM TRACE" -l "$fn_name" -ds

    set_manager_log NM TRACE ||
        raise "FAIL: Could not set manager log severity: set_manager_log NM TRACE" -l "$fn_name" -ds

    if [ "$cm2_is_gw" == "true" ]; then
        wait_for_function_response 0 "check_default_route_gw" ||
            raise "FAIL: Default GW not added to routes" -l "$fn_name" -ds
    fi

    return 0
}

###############################################################################
# DESCRIPTION:
#   Function makes a tear down for CM tests. Removes bridge interface and
#   kills CM. Function is used after CM tests session.
# INPUT PARAMETER(S):
#   None.
# RETURNS:
# USAGE EXAMPLE(S):
#   cm2_teardown
###############################################################################
cm2_teardown()
{
    fn_name="cm2_lib:cm2_teardown"
    log -deb "$fn_name - Running CM2 teardown"
    remove_bridge_interface br-wan &&
        log -deb "$fn_name - Success: remove_bridge_interface br-wan" ||
        log -deb "$fn_name - Failed: remove_bridge_interface br-wan"

    log -deb "$fn_name - Killing CM pid"
    cm_pids=$(pgrep "cm")
    kill $cm_pids &&
        log -deb "$fn_name - CM pids killed" ||
        log -deb "$fn_name - Failed to kill CM pids"
}

####################### SETUP SECTION - STOP ##################################

####################### CLOUD SECTION - START #################################

###############################################################################
# DESCRIPTION:
#   Function waits for Cloud status in Manager table to become
#   as provided in parameter.
#   Cloud statuses are:
#       ACTIVE          device is connected to Cloud.
#       BACKOFF         device could not connect to Cloud, will retry.
#       CONNECTING      connecting to Cloud in progress.
#       DISCONNECTED    device is disconnected from Cloud.
#   Raises an exception on fail.
# INPUT PARAMETER(S):
#   $1  desired cloud state (required)
# RETURNS:
#   None.
#   See DESCRIPTION.
# USAGE EXAMPLE(S):
#   wait_cloud_state ACTIVE
###############################################################################
wait_cloud_state()
{
    fn_name="cm2_lib:wait_cloud_state"
    local NARGS=1
    [ $# -ne ${NARGS} ] &&
        raise "${fn_name} requires ${NARGS} input argument(s), $# given" -arg
    wait_for_cloud_state=$1

    log -deb "$fn_name - Waiting for cloud state $wait_for_cloud_state"
    wait_for_function_response 0 "${OVSH} s Manager status -r | grep -q \"$wait_for_cloud_state\"" &&
        log -deb "$fn_name - Cloud state is $wait_for_cloud_state" ||
        raise "FAIL: Manager::status is not $wait_for_cloud_state}" -l "$fn_name" -ow
    print_tables Manager
}

###############################################################################
# DESCRIPTION:
#   Function waits for Cloud status in Manager table not to become
#   as provided in parameter.
#   Cloud statuses are:
#       ACTIVE          device is connected to Cloud.
#       BACKOFF         device could not connect to Cloud, will retry.
#       CONNECTING      connecting to Cloud in progress.
#       DISCONNECTED    device is disconnected from Cloud.
#   Raises an exception on fail.
# INPUT PARAMETER(S):
#   $1  un-desired cloud state (required)
# RETURNS:
#   None.
#   See DESCRIPTION.
# USAGE EXAMPLE(S):
#   wait_cloud_state_not ACTIVE
###############################################################################
wait_cloud_state_not()
{
    fn_name="cm2_lib:wait_cloud_state_not"
    local NARGS=1
    [ $# -lt ${NARGS} ] &&
        raise "${fn_name} requires ${NARGS} input argument(s), $# given" -arg
    wait_for_cloud_state_not=${1}
    wait_for_cloud_state_not_timeout=${2:-60}

    log -deb "$fn_name - Waiting for cloud state not to be $wait_for_cloud_state_not"
    wait_for_function_response 0 "${OVSH} s Manager status -r | grep -q \"$wait_for_cloud_state_not\"" "${wait_for_cloud_state_not_timeout}" &&
        raise "FAIL: Manager::status is $wait_for_cloud_state_not}" -l "$fn_name" -ow ||
        log -deb "$fn_name - Cloud state is $wait_for_cloud_state_not"

    print_tables Manager
}

####################### CLOUD SECTION - STOP ##################################

####################### ROUTE SECTION - START #################################

###############################################################################
# DESCRIPTION:
#   Function checks if default gateway route exists.
#   Function uses route tool. Must be installed on device.
# INPUT PARAMETER(S):
#   None.
# RETURNS:
#   0   Default route exists.
#   1   Default route does not exist.
# USAGE EXAMPLE(S):
#   check_default_route_gw
###############################################################################
check_default_route_gw()
{
    default_gw=$(route -n | tr -s ' ' | grep -i UG | awk '{printf $2}';)
    if [ -z "$default_gw" ]; then
        return 1
    else
        return 0
    fi
}

####################### ROUTE SECTION - STOP ##################################

####################### LINKS SECTION - START #################################

####################### LINKS SECTION - STOP ##################################


####################### TEST CASE SECTION - START #############################

###############################################################################
# DESCRIPTION:
#   Function manipulates traffic by protocol using iptables.
#   Adds (inserts) or removes (deletes) rules to OUTPUT chain.
#   Can block traffic by using block option.
#   Can unblock traffic by using unblock option.
#   Supports traffic types:
#       - DNS
#       - SSL
#   Raises exception if rule cannot be applied.
# INPUT PARAMETER(S):
#   $1  option, block or unblock traffic (required)
#   $2  traffic type (required)
# RETURNS:
#   None.
#   See DESCRIPTION.
# USAGE EXAMPLE(S):
#   manipulate_iptables_protocol unblock SSL
#   manipulate_iptables_protocol unblock DNS
###############################################################################
manipulate_iptables_protocol()
{
    fn_name="cm2_lib:manipulate_iptables_protocol"
    local NARGS=2
    [ $# -ne ${NARGS} ] &&
        raise "${fn_name} requires ${NARGS} input argument(s), $# given" -arg
    option=$1
    traffic_type=$2

    log -deb "$fn_name - $option $traffic_type traffic"

    if [ "$option" == "block" ]; then
        iptable_option='I'
        exit_code=0
    elif [ "$option" == "unblock" ]; then
        iptable_option='D'
        # Waiting for exit code 1 if multiple iptables rules are inserted - safer way
        exit_code=1
    else
        raise "FAIL: Wrong option, given:$option, supported: block, unblock" -l "$fn_name" -arg
    fi

    if [ "$traffic_type" == "DNS" ]; then
        traffic_port="53"
        traffic_port_type="udp"
    elif [ "$traffic_type" == "SSL" ]; then
        traffic_port="443"
        traffic_port_type="tcp"
    else
        raise "FAIL: Wrong traffic_type, given:$option, supported: DNS, SSL" -l "$fn_name" -arg
    fi

    $(iptables -S | grep -q "OUTPUT -p $traffic_port_type -m $traffic_port_type --dport $traffic_port -j DROP")
    # Add rule if not already an identical one in table, but unblock always
    if [ "$?" -ne 0 ] || [ "$option" == "unblock" ]; then
        wait_for_function_response $exit_code "iptables -$iptable_option OUTPUT -p $traffic_port_type --dport $traffic_port -j DROP" &&
            log -deb "$fn_name - $traffic_type traffic ${option}ed" ||
            raise "FAIL: Could not $option $traffic_type traffic" -l "$fn_name" -nf
    else
        log "$fn_name - Add failure: Rule already in chain"
    fi
}

###############################################################################
# DESCRIPTION:
#   Function manipulates traffic by source address using iptables.
#   Adds (inserts) or removes (deletes) rules to OUTPUT chain.
#   Can block traffic by using block option.
#   Can unblock traffic by using unblock option.
#   Raises exception is rule cannot be applied.
# INPUT PARAMETER(S):
#   $1  option, block or unblock traffic
#   $2  source address to be blocked
# RETURNS:
#   None.
#   See DESCRIPTION.
# USAGE EXAMPLE(S):
#   manipulate_iptables_address block 192.168.200.10
###############################################################################
manipulate_iptables_address()
{
    fn_name="cm2_lib:manipulate_iptables_address"
    local NARGS=2
    [ $# -ne ${NARGS} ] &&
        raise "${fn_name} requires ${NARGS} input argument(s), $# given" -arg
    option=$1
    address=$2

    log -deb "$fn_name - $option $address internet"

    if [ "$option" == "block" ]; then
        iptable_option='I'
        exit_code=0
    elif [ "$option" == "unblock" ]; then
        iptable_option='D'
        # Waiting for exit code 1 if multiple iptables rules are inserted - safer way
        exit_code=1
    else
        raise "FAIL: Wrong option, given:$option, supported: block, unblock" -l "$fn_name" -arg
    fi

    $(iptables -S | grep -q "OUTPUT -s $address -j DROP")
    # Add rule if not already an identical one in table, but unblock always
    if [ "$?" -ne 0 ] || [ "$option" == "unblock" ]; then
        wait_for_function_response $exit_code "iptables -$iptable_option OUTPUT -s $address -j DROP" &&
            log -deb "$fn_name - internet ${option}ed" ||
            raise "FAIL: Could not $option internet" -l "$fn_name" -nf
    else
        log "$fn_name - Add failure: Rule already in chain"
    fi
}

####################### TEST CASE SECTION - STOP ##############################
