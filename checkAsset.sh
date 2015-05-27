#!/bin/bash

#set -x

#	Author Laurent Orban
#	v 0.1 creation -- A simple retrieval
#	v 0.1.1 27-02-2015 -- fancy it into a real script
#	v 0.1.2 03-03-2015 -- make the ssh to server work in a loop with ip taken of a formated file
#	v 0.1.3 04-03-2015 -- finaly output the battery status and the firmware version
#	v 0.1.4 06-03-2015 -- convert the script to an other purpose
#	v 0.2   16-04-2015 -- print table values
#	v 0.2.1 16-04-2015 -- preliminary work to add coloring support

DIRNAME=`dirname $0`
PROGNAME=`basename $0`

SERVER_LIST_FILE=/home/isa/.arroyorc
SSH_CONNECTION_TIMEOUT=10
BATTERY_REPLACEMENT_THRESHOLD=10

#
# Print the command line help message.
#
usage() {
cat << __EO_USAGE__
usage: ${PROGNAME} [options]

options:
    -h        Print this help message.
    -l        provide a list file
    -t        connection time out value; defaulted to 10 seconds
__EO_USAGE__
}

#
# Process command line options.
#
processCommandLine() {

OPTIND=1

    while getopts "hl:t:" key; do
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
            t)
                SSH_CONNECTION_TIMEOUT=${OPTARG}
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
retrieveEvaluatorStatus() {

    #problems the file does not rotate at midnight but later... so I use -u for UTC time
    logfile=/arroyo/log/protocoltiming.log.$(date -u +%Y%m%d)

    local index=0

    for line in "${@}"
    do
        {
            # prevent Ctrl-C the loop
            # trap ':' INT

            >/tmp/${line}.${PROGNAME}.log

            #will later add -n to ssh in order to prevent it from reading stdin
            ssh -o ConnectTimeout=${SSH_CONNECTION_TIMEOUT} -o StrictHostKeyChecking=no root@${line} 'bash -s' << __EO_SSH__ > /tmp/${line}.${PROGNAME}.log

            tail -79 $logfile
__EO_SSH__
        } || {
            rm /tmp/${line}.${PROGNAME}.log
            unset servers[${index}]
        }

    let index++
    done
}

#
#
#
retrieveBackLogStatus() {

    local index=0

    for line in "${@}"
    do
        {
            # prevent Ctrl-C the loop
            # trap ':' INT

            >/tmp/${line}.${PROGNAME}.log

            #will later add -n to ssh in order to prevent it from reading stdin
            ssh -o ConnectTimeout=${SSH_CONNECTION_TIMEOUT} -o StrictHostKeyChecking=no root@${line} 'bash -s' << __EO_SSH__ > /tmp/${line}.${PROGNAME}.log

            grep "bklog" /arroyo/log/avsdb.log | tail -1
__EO_SSH__
        }

    let index++
    done
}

#
#
#
retrieveEvaluatorHostnames() {

    local index=1

    for line in "${@}"
    do
        {
            ssh -o ConnectTimeout=${SSH_CONNECTION_TIMEOUT} -o StrictHostKeyChecking=no root@${line} 'uname -n'
        } || {
            unset servers[${index}]
        }

    let index++
    done
}

#
#
#
getCDSMAssetNumber () {

    su isa -c /arroyo/db/dumpDB << __END_OF_SU__ >/dev/null
1
0
__END_OF_SU__

    grep "Content Objects Count:" /arroyo/db/ctnobj.lst | tail -1 | sed 's/Content Objects Count://;s/\n//;s/\r//'
}

#
#
#
retrieveAssetNumber() {

    for line in "${@}"
    do {
        expect << __END_OF_EXPECT__  | grep "Content from database: Count:" | sed 's/Content from database: Count://;s/\n//;s/\r//'
        spawn ssh -o ConnectTimeout=${SSH_CONNECTION_TIMEOUT} -o StrictHostKeyChecking=no root@${line} '/arroyo/db/AVSDBUtil'
        expect -exact ": " { send -- "1\r" }
        expect -exact ": " { send -- "2\r" }
        expect -exact ": " { send -- "0\r" }
        send "exit\r"
        expect eof"
__END_OF_EXPECT__
       }
    done
}

#
#
#
setMasterVault() {

    local index=0

    for line in "${@}"
    do
    {
        # prevent Ctrl-C the loop
        # trap ':' INT

        #will later add -n to ssh in order to prevent it from reading stdin
        local STATUS=( $(ssh -o ConnectTimeout=${SSH_CONNECTION_TIMEOUT} -o StrictHostKeyChecking=no root@${line} "ip addr show | grep secondary | awk '{ print $8 }' | wc -l") )

        if [ ${STATUS} -ne "0" ] ; then hostnames[${index}]=$(printf "%s%s" ${hostnames[${index}]} "[Master]"); fi
    }
    let index++
    done
}

#
#
#
DEFAULT() {
    echo "\e[0;40;39m ${@} \e[0m"
}

RED() {
    echo "\e[0;40;91m ${@} \e[0m"
}

BLINK() {
    echo "\e[5;40;39m ${@} \e[0m"
}

#
#
#
showRemoteValues() {

    retrieveEvaluatorStatus "${servers[@]}"
    local CDSM_ASSET=( $(getCDSMAssetNumber) )

    local index=0

    clear
    date +"%H:%M"
    echo "CDSM Asset number : ${CDSM_ASSET}"
    printf "%-25s%10s%10s\n" "VAULT" "Enabled" "Assets"

    for line in "${@}"
    do
        local VAULT=${hostnames[${index}]}
        local EVALUATOR=$(grep "^.Evaluators Enabled" /tmp/${line}.${PROGNAME}.log | awk -F '=' '{ print $2 }' | awk '{ print $1 }' )
        local ASSET=$( retrieveAssetNumber ${servers[${index}]} )

        VAULT=$(DEFAULT ${VAULT})

        if [ ! -z "${ASSET}" ] ; then
            if [ "${ASSET}" -ne "${CDSM_ASSET}" ] ; then
                ASSET=$(RED ${ASSET})
            else
                ASSET=$(DEFAULT ${ASSET})
            fi
        else
            # expect is a whimsical command... and this is how I chose to handle it.
            ASSET=$(BLINK 'timeout')
        fi

        if [ "${EVALUATOR}" -ne "1" ] ; then EVALUATOR=$(RED ${EVALUATOR}); else EVALUATOR=$(DEFAULT ${EVALUATOR}); fi

        printf "%b%-25s%b%b%10s%b%b%10s%b\n" ${VAULT} ${EVALUATOR} ${ASSET}
    let index++
    done
}

#
# code entry-point.
#
main() {

processCommandLine "$@"

declare -a servers=($(grep -e "^vault" ${SERVER_LIST_FILE} | awk '{print $2}'))

declare -a hostnames=( $(retrieveEvaluatorHostnames "${servers[@]}") )

setMasterVault "${servers[@]}"

showRemoteValues "${servers[@]}"

}

#
# Boot-strap
#
main "$@"
