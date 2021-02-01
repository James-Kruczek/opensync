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


# Include basic environment config from default shell file and if any from FUT framework generated /tmp/fut_set_env.sh file
if [ -e "/tmp/fut_set_env.sh" ]; then
    source /tmp/fut_set_env.sh
else
    source /tmp/fut-base/shell/config/default_shell.sh
fi
source "${FUT_TOPDIR}/shell/lib/wm2_lib.sh"
source "${FUT_TOPDIR}/shell/lib/nm2_lib.sh"
source "${LIB_OVERRIDE_FILE}"

tc_name="wm2/$(basename "$0")"
manager_setup_file="wm2/wm2_setup.sh"
usage()
{
cat << usage_string
${tc_name} [-h] arguments
Description:
    - Script tries to set chosen THERMAL TX CHAINMASK. If interface is not UP it brings up the interface, and tries to set
      THERMAL TX CHAINMASK to desired value.
Arguments:
    -h  show this help message
    \$1  (radio_idx)            : Wifi_VIF_Config::vif_radio_idx                                                   : (int)(required)
    \$2  (if_name)              : Wifi_Radio_Config::if_name                                                       : (string)(required)
    \$3  (ssid)                 : Wifi_VIF_Config::ssid                                                            : (string)(required)
    \$4  (password)             : Wifi_VIF_Config::security                                                        : (string)(required)
    \$5  (channel)              : Wifi_Radio_Config::channel                                                       : (int)(required)
    \$6  (ht_mode)              : Wifi_Radio_Config::ht_mode                                                       : (string)(required)
    \$7  (hw_mode)              : Wifi_Radio_Config::hw_mode                                                       : (string)(required)
    \$8  (mode)                 : Wifi_VIF_Config::mode                                                            : (string)(required)
    \$9  (country)              : Wifi_Radio_Config::country                                                       : (string)(required)
    \$10 (vif_if_name)          : Wifi_VIF_Config::if_name                                                         : (string)(required)
    \$11 (tx_chainmask)         : used as tx_chainmask in Wifi_Radio_Config table (recomended 1, 3, 7, 15)         : (int)(required)
    \$12 (thermal_tx_chainmask) : used as thermal_tx_chainmask in Wifi_Radio_Config table (recomended 1, 3, 7, 15) : (int)(required)
Testcase procedure:
    - On DEVICE: Run: ./${manager_setup_file} (see ${manager_setup_file} -h)
                 Run: ./${tc_name}
Script usage example:
   ./${tc_name} 2 wifi1 test_wifi_50L WifiPassword123 44 HT20 11ac ap US home-ap-l50 36 5
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
NARGS=12
[ $# -lt ${NARGS} ] && usage && raise "Requires at least '${NARGS}' input argument(s)" -l "${tc_name}" -arg

trap 'run_setup_if_crashed wm || true' EXIT SIGINT SIGTERM

vif_radio_idx=$1
if_name=$2
ssid=$3
security=$4
channel=$5
ht_mode=$6
hw_mode=$7
mode=$8
country=$9
vif_if_name=${10}
tx_chainmask=${11}
thermal_tx_chainmask=${12}

log_title "$tc_name: WM2 test - Testing Wifi_Radio_Config field thermal_tx_chainmask"

log "$tc_name: Determining minimal value THERMAL TX CHAINMASK ($thermal_tx_chainmask) vs TX CHAINMASK ($tx_chainmask)"
if [ "$thermal_tx_chainmask" -gt "$tx_chainmask" ]; then
    value_to_check=$tx_chainmask
else
    value_to_check=$thermal_tx_chainmask
fi

log "$tc_name: Checking is interface UP and running"
(interface_is_up "$if_name" && ${OVSH} s Wifi_VIF_State -w if_name=="$if_name") ||
    create_radio_vif_interface \
        -vif_radio_idx "$vif_radio_idx" \
        -channel_mode manual \
        -if_name "$if_name" \
        -ssid "$ssid" \
        -security "$security" \
        -enabled true \
        -channel "$channel" \
        -ht_mode "$ht_mode" \
        -hw_mode "$hw_mode" \
        -mode "$mode" \
        -country "$country" \
        -vif_if_name "$vif_if_name" &&
            log "$tc_name create_radio_vif_interface - Success" ||
            raise "create_radio_vif_interface - Failed" -l "$tc_name" -tc

log "$tc_name: Changing tx_chainmask to $tx_chainmask"
update_ovsdb_entry Wifi_Radio_Config -w if_name "$if_name" -u tx_chainmask "$tx_chainmask" &&
    log "$tc_name: update_ovsdb_entry - Wifi_Radio_Config table updated - tx_chainmask $tx_chainmask" ||
    raise "update_ovsdb_entry - Failed to update Wifi_Radio_Config - tx_chainmask $tx_chainmask" -l "$tc_name" -tc

wait_ovsdb_entry Wifi_Radio_State -w if_name "$if_name" -is tx_chainmask "$tx_chainmask" &&
    log "$tc_name: wait_ovsdb_entry - Wifi_Radio_Config reflected to Wifi_Radio_State - tx_chainmask $tx_chainmask" ||
    raise "wait_ovsdb_entry - Failed to reflect Wifi_Radio_Config to Wifi_Radio_State - tx_chainmask $tx_chainmask" -l "$tc_name" -tc

log "$tc_name: LEVEL 2 - checking TX CHAINMASK $tx_chainmask at OS level"
check_tx_chainmask_at_os_level "$tx_chainmask" "$if_name" &&
    log "$tc_name: check_tx_chainmask_at_os_level - TX CHAINMASK $tx_chainmask is SET at OS level" ||
    raise "check_tx_chainmask_at_os_level - TX CHAINMASK $tx_chainmask is NOT set at" -l "$tc_name" -tc

log "$tc_name: Changing thermal_tx_chainmask to $thermal_tx_chainmask"
update_ovsdb_entry Wifi_Radio_Config -w if_name "$if_name" -u thermal_tx_chainmask "$thermal_tx_chainmask" &&
    log "$tc_name: update_ovsdb_entry - Wifi_Radio_Config table updated - thermal_tx_chainmask $thermal_tx_chainmask" ||
    raise "update_ovsdb_entry - Failed to update Wifi_Radio_Config - thermal_tx_chainmask $thermal_tx_chainmask" -l "$tc_name" -tc

log "$tc_name: Check did it change tx_chainmask to $value_to_check"
wait_ovsdb_entry Wifi_Radio_State -w if_name "$if_name" -is tx_chainmask "$value_to_check" &&
    log "$tc_name: wait_ovsdb_entry - Wifi_Radio_Config reflected to Wifi_Radio_State - tx_chainmask $value_to_check" ||
    raise "wait_ovsdb_entry - Failed to reflect Wifi_Radio_Config to Wifi_Radio_State - tx_chainmask $value_to_check" -l "$tc_name" -tc

log "$tc_name: LEVEL 2 - checking TX CHAINMASK $value_to_check at OS level"
check_tx_chainmask_at_os_level "$value_to_check" "$if_name" &&
    log "$tc_name: check_tx_chainmask_at_os_level - TX CHAINMASK $value_to_check is SET at OS level" ||
    raise "check_tx_chainmask_at_os_level - TX CHAINMASK $value_to_check is NOT set at" -l "$tc_name" -tc

pass
