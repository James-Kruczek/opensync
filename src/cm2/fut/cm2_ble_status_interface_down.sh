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


# FUT environment loading
source /tmp/fut-base/shell/config/default_shell.sh
[ -e "/tmp/fut-base/fut_set_env.sh" ] && source /tmp/fut-base/fut_set_env.sh
source "${FUT_TOPDIR}/shell/lib/cm2_lib.sh"
[ -e "${LIB_OVERRIDE_FILE}" ] && source "${LIB_OVERRIDE_FILE}" || raise "" -olfm

tc_name="cm2/$(basename "$0")"
cm_setup_file="cm2/cm2_setup.sh"
sleep_time_after_if_down=5
if_down_up_bit_process="01 05 35 75"
if_default="eth0"
usage()
{
cat << usage_string
${tc_name} [-h] arguments
Description:
    - Script observes AW_Bluetooth_Config table field 'payload' during drop/up of link interface.
      If AW_Bluetooth_Config payload field fails to change in given sequence (${if_down_up_bit_process}), test fails
Arguments:
    -h : show this help message
    \$1 (if_name) : <CONNECTION-INTERFACE> : (string)(optional) : (default:${if_default})
Testcase procedure:
    - On DEVICE: Run: ${cm_setup_file} (see ${cm_setup_file} -h)
                 Run: ${tc_name} <WAN-IF-NAME>
Script usage example:
    ./${tc_name} ${if_default}
usage_string
}
while getopts h option; do
    case "$option" in
        h)
            usage && exit 1
            ;;
        *)
            echo "Unknown argument" && exit 1
            ;;
    esac
done

check_kconfig_option "CONFIG_MANAGER_BLEM" "y" ||
    raise "CONFIG_MANAGER_BLEM != y - BLE not present on device" -l "${tc_name}" -s

check_kconfig_option "TARGET_CAP_EXTENDER" "y" ||
    raise "TARGET_CAP_EXTENDER != y - Testcase applicable only for EXTENDER-s" -l "${tc_name}" -s

NARGS=1
[ $# -lt ${NARGS} ] && usage && raise "Requires at least '${NARGS}' input argument(s)" -l "${tc_name}" -arg
if_name=${1:-${if_default}}

trap '
fut_info_dump_line
print_tables AW_Bluetooth_Config
fut_info_dump_line
ifconfig $if_name up || true
check_restore_management_access || true
run_setup_if_crashed cm || true
' EXIT SIGINT SIGTERM

log_title "$tc_name: CM2 test - Observe BLE Status - Interface '${if_name}' down/up"

log "$tc_name: Simulating CM full reconnection by dropping interface"
log "$tc_name: Dropping interface $if_name"
ifconfig "$if_name" down &&
    log "$tc_name: Interface $if_name is down" ||
    raise "Couldn't bring down interface $if_name" -l "$tc_name" -ds
log "$tc_name: Sleeping for 5 seconds"
sleep "${sleep_time_after_if_down}"
log "$tc_name: Bringing back interface $if_name"
ifconfig "$if_name" up &&
    log "$tc_name: Interface $if_name is up" ||
    raise "Couldn't bring up interface $if_name" -l "$tc_name" -ds
for bit in $if_down_up_bit_process; do
    log "$tc_name: Checking AW_Bluetooth_Config payload for $bit:00:00:00:00:00"
    wait_ovsdb_entry AW_Bluetooth_Config -is payload "$bit:00:00:00:00:00" &&
        log "$tc_name: wait_ovsdb_entry - AW_Bluetooth_Config payload changed to $bit:00:00:00:00:00" ||
        raise "AW_Bluetooth_Config payload failed to change $bit:00:00:00:00:00" -l "$tc_name" -tc
done
pass
