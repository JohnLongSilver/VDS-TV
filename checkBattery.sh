#!/bin/bash

#set -x

set -e
set -u
set -o pipefail

#	Author Laurent Orban
#	v 0.1 creation -- A simple retrieval
#	v 0.1.1 27-02-2015 -- fancy it into a real script
#	v 0.1.2 03-03-2015 -- make the ssh to server work in a loop with ip taken of a formated file
#	v 0.1.3 04-03-2015 -- finaly output the battery status and the firmware version

readonly PROGNAME=$(basename $0 .sh)

SERVER_LIST_FILE=/home/isa/.arroyorc
LOG_FILE=/arroyo/log/${PROGNAME}.log.$(date +%Y%m%d)
SSH_CONNECTION_TIMEOUT=30
BATTERY_REPLACEMENT_THRESHOLD=10
VERBOSE=0

#
# Print the command line help message.
#
usage() {
cat << __EO_USAGE__
usage: ${PROGNAME}.sh [options]

options:
    -h    Print this help message.
    -v    verbose
    -l    provide a list file; defaulted to ${SERVER_LIST_FILE}
    -t    connection time out value; defaulted to ${SSH_CONNECTION_TIMEOUT} seconds
    -e    thereshold battery error message occurence should not reach. Defaulted to ${BATTERY_REPLACEMENT_THRESHOLD}
__EO_USAGE__
}

#
# Process command line options.
#
processCommandLine() {

OPTIND=1

    while getopts "hl:e:t:v" key; do
        case "${key}" in
            h)
                usage
                exit 0
                ;;
            l)
                if [ -f ${SERVER_LIST_FILE} ]; then
                    SERVER_LIST_FILE=${OPTARG}
                fi
                ;;
            e)
                BATTERY_REPLACEMENT_THRESHOLD=${OPTARG}
                ;;
            t)
                SSH_CONNECTION_TIMEOUT=${OPTARG}
                ;;
            v)
                VERBOSE=1
                ;;
            *)
                usage
                exit 1
                ;;
        esac
    done

shift $((OPTIND-1))
}

#
# besides the obvious, the function removes any IP which is not functional from the ${servers[@]} list
#
retrieveMegaRaidStatus() {

    local index=0

    for line in "${@}"
    do
        {
            # prevent Ctrl-C the loop
            trap ':' INT

            >/tmp/${line}.${PROGNAME}.log

            echo "retrieve battery status and firmware version for ${line}"

            #will later add -n to ssh in order to prevent it from reading stdin 
            ssh -o ConnectTimeout=${SSH_CONNECTION_TIMEOUT} -o StrictHostKeyChecking=no root@${line} 'bash -s' << __EO_SSH__ > /tmp/${line}.${PROGNAME}.log

            /opt/MegaRAID/CmdTool2/CmdTool2 -AdpEventLog -GetEvents -f /tmp/megaraid.log -aALL

            cat /tmp/megaraid.log
__EO_SSH__
        } || {
            rm /tmp/${line}.${PROGNAME}.log
            unset servers[${index}]
        }

    let ++index
    done
}

#
# report batteries that needs to be replaced based on # of error occurence being >= predefined value
#
showBatteryStatus() {

    for line in "${@}"
    do
        local OCCURRENCES=$(grep -c -e "Battery needs replacement - SOH Bad" \
                                    -e "Battery Not Present" \
                                    -e "BBU removed" \
                                    -e "BBU not seen" \
                            /tmp/${line}.${PROGNAME}.log)

        if (("${OCCURRENCES}" >= "${BATTERY_REPLACEMENT_THRESHOLD}")); then
            echo "[${OCCURRENCES} occurences] ${line} needs to replace the MegaRaid battery!"
        else
            echo "[${OCCURRENCES} occurences] ${line} has no battery issue"
        fi
    done
}

#
#
#
showFirmwareVersion () {

    #echo "${@}" | while read line
    for line in "${@}"
    do
       local OUTPUT=$(grep -m 1 "Event Description: Firmware version" /tmp/${line}.${PROGNAME}.log | sed 's/Event Description: //')
       echo "${line} ${OUTPUT}"
    done
}

#
#
#
verbose() {

cat << __EO_HEADER__
========================================================================
Command invoked : $0 $@
By user : $(whoami)
At $(date)
Logging to : ${LOG_FILE}
__EO_HEADER__

}

#
# code entry-point.
#
main() {

    processCommandLine "$@"

    declare -a servers=($(grep -e "^vault" -e "^streamer" ${SERVER_LIST_FILE} | awk '{print $2}'))

    {
    if (( ${VERBOSE} )); then
        verbose
    fi

    if [ ${#servers[@]} -eq 0 ]; then

        echo "There is no Vault nor Streamer to be checked."
        exit 0
    else
        echo "There is ${#servers[@]} vault/streamers to be checked."
    fi

    retrieveMegaRaidStatus "${servers[@]}"

    showBatteryStatus "${servers[@]}"

    showFirmwareVersion "${servers[@]}"

    } | tee -a ${LOG_FILE}

    ./putonftp.sh ${LOG_FILE}
}

#
# Boot-strap
#
main "$@"
