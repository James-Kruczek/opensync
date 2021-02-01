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


if [ -e "/tmp/fut_set_env.sh" ]; then
    source /tmp/fut_set_env.sh
else
    source /tmp/fut-base/shell/config/default_shell.sh
fi
source "${FUT_TOPDIR}/shell/lib/um_lib.sh"
source "${LIB_OVERRIDE_FILE}"

tc_name="um/$(basename "$0")"
manager_setup_file="um/um_setup.sh"
um_resource_path="resource/um/"
um_image_name_default="um_incorrect_fw_pass_fw"
um_create_md5_file_path="tools/rpi/um/um_create_md5_file.sh"
usage()
{
cat << usage_string
${tc_name} [-h] arguments
Description:
    - Script validates AWLAN_Node 'upgrade_status' field proper code change if invalid fw pass is provided, fails otherwise
Arguments:
    -h  show this help message
    \$1 (fw_path) : download path of UM - used to clear the folder on UM setup  : (string)(required)
    \$2 (fw_url)  : used as firmware_url in AWLAN_Node table                    : (string)(required)
    \$3 (fw_pass) : used as firmware_pass in AWLAN_Node table                   : (string)(required)
Testcase procedure:
    - On RPI SERVER: Prepare clean FW (.img) in ${um_resource_path}
                     Duplicate image with different name (example. ${um_image_name_default}.img) (cp <CLEAN-IMG> <NEW-IMG>)
                     Create MD5 sum for image (example. ${um_image_name_default}.img.md5) (see ${um_create_md5_file_path} -h)
    - On DEVICE: Run: ./${manager_setup_file} (see ${manager_setup_file} -h)
                 Run: ./${tc_name} <FW-PATH> <FW-URL> <FW-PASS>
Script usage example:
   ./${tc_name} /tmp/pfirmware http://192.168.4.1:8000/fut-base/resource/um/${um_image_name_default}.img incorrect_fw_pass
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
NARGS=3
[ $# -lt ${NARGS} ] && usage && raise "Requires at least '${NARGS}' input argument(s)" -l "${tc_name}" -arg

fw_path=$1
fw_url=$2
fw_pass=$3

trap '
  reset_um_triggers $fw_path || true
  run_setup_if_crashed um || true
' EXIT SIGINT SIGTERM

log_title "$tc_name: UM test - Invalid FW pass"

log "$tc_name: Setting firmware_url to $fw_url and firmware_pass to $fw_pass"
update_ovsdb_entry AWLAN_Node \
    -u firmware_pass "$fw_pass" \
    -u firmware_url "$fw_url" &&
        log "$tc_name: update_ovsdb_entry - Success to update" ||
        raise "$tc_name: update_ovsdb_entry - Failed to update" -l "$tc_name" -tc

log "$tc_name: Waiting for FW download start"
wait_ovsdb_entry AWLAN_Node -is upgrade_status "$(get_um_code "UPG_STS_FW_DL_START")" &&
    log "$tc_name: wait_ovsdb_entry - Success to wait" ||
    raise "$tc_name: wait_ovsdb_entry - Failed to wait" -l "$tc_name" -tc

log "$tc_name: Waiting for FW download finish"
wait_ovsdb_entry AWLAN_Node -is upgrade_status "$(get_um_code "UPG_STS_FW_DL_END")" &&
    log "$tc_name: wait_ovsdb_entry - Success to wait" ||
    raise "$tc_name: wait_ovsdb_entry - Failed to wait" -l "$tc_name" -tc

log "$tc_name: Setting AWLAN_Node upgrade_timer to 1 and "
update_ovsdb_entry AWLAN_Node -u upgrade_timer 1 &&
    log "$tc_name: update_ovsdb_entry - Success to update" ||
    raise "$tc_name: update_ovsdb_entry - Failed to update" -l "$tc_name" -tc

log "$tc_name: Waiting for FW corrupt image code UPG_ERR_IMG_FAIL - $(get_um_code "UPG_ERR_IMG_FAIL")"
wait_ovsdb_entry AWLAN_Node -is upgrade_status "$(get_um_code "UPG_ERR_IMG_FAIL")" &&
    log "$tc_name: wait_ovsdb_entry - Success to wait" ||
    raise "$tc_name: wait_ovsdb_entry - Failed to wait" -l "$tc_name" -tc

pass
