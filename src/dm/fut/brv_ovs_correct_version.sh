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


# Include environment config from default shell file
source /tmp/fut-base/shell/config/default_shell.sh
[ -e "/tmp/fut_set_env.sh" ] && source /tmp/fut_set_env.sh
# Include shared libraries and library overrides
source "${FUT_TOPDIR}/shell/lib/brv_lib.sh"

tc_name="brv/$(basename "$0")"
brv_setup_file="brv/brv_setup.sh"
usage()
{
cat << usage_string
${tc_name} [-h] \$1
Description:
    - Script checks if correct OVS version is on the system, fails otherwise
Arguments:
    -h : show this help message
    \$1 (expected_version) : expected version of the Open vSwitch : (string)(required)
Testcase procedure:
    - On DEVICE: Run: ./${brv_setup_file} (see ${brv_setup_file} -h)
                 Run: ./${tc_name} <EXPECTED-VERSION>
Usage:
   ./${tc_name} "2.8.7"
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
NARGS=1
[ $# -ne ${NARGS} ] && usage && raise "Requires exactly '${NARGS}' input argument(s)" -l "${tc_name}" -arg

expected_ovs_ver=$1

log_title "${tc_name}: BRV test - Verify OVS version is '${expected_ovs_ver}'"

actual_ovs_ver="$(get_ovs_version)"
check_ovs_version "${expected_ovs_ver}" "${actual_ovs_ver}" &&
    log -deb "${tc_name}: Actual on device OVS version: ${actual_ovs_ver} is as expected: ${expected_ovs_ver}" ||
    raise "Actual on device OVS version: ${actual_ovs_ver} is NOT as expected: ${expected_ovs_ver}" -l "${tc_name}" -tc

pass
