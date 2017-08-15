##############################################################################
# Copyright (c) 2017 Nokia and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

# include only once
[ ! -z "$_tools_included" ] && return || readonly _tools_included=true

#######################################
# Echo printing in yellow bold color
# Arguments:
#   Same as for echo
# Returns:
#   None
#######################################
function echo_info { (
    # don't clutter the script output with the xtrace of the echo command
    { set +x; } 2> /dev/null

    yellow_bold='\033[1;33m'
    color_off='\033[0m'
    echo "${@:1:($#-1)}" -e "$yellow_bold${@: -1}$color_off";
  )
}

#######################################
# Echo error (to stderr)
# Arguments:
#   Same as for echo
# Returns:
#   None
#######################################
function echo_error { (
    # don't clutter the script output with the xtrace of the echo command
    { set +x; } 2> /dev/null

    red_bold='\033[1;31m'
    color_off='\033[0m'
    >&2 echo "${@:1:($#-1)}" -e "$red_bold${@: -1}$color_off";
  )
}

#######################################
# Echo warning (to stderr)
# Arguments:
#   Same as for echo
# Returns:
#   None
#######################################
function echo_warning { (
    # don't clutter the script output with the xtrace of the echo command
    { set +x; } 2> /dev/null

    red_italic='\033[3;91m'
    color_off='\033[0m'
    >&2 echo "${@:1:($#-1)}" -e "$red_italic${@: -1}$color_off";
  )
}
