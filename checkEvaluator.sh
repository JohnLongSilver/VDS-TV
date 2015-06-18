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

PROGNAME=`basename $0`

LOOPTIME=10

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

    #problems the file does not rotate at midnight but later...
    logfile=/arroyo/log/protocoltiming.log.$(date +%Y%m%d)
    #logfile=/arroyo/log/protocoltiming.log.20150402

    local index=0

    for line in "${@}"
    do
        {
            # prevent Ctrl-C the loop
            #trap ':' INT

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
retrieveEvaluatorHostnames() {

    local index=1

    for line in "${@}"
    do
        {
            # prevent Ctrl-C the loop
            trap ':' INT

            #will later add -n to ssh in order to prevent it from reading stdin
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

    local index=0

    clear
    date +"%H:%M"
    printf "%-15s%10s%15s%20s%15s%10s%10s%15s\n" "VAULT" "Enabled" "Data Recovery" "Mirror Recovery" "Local Mirror" "Defrag" "Smooth" "Remote Smooth"

    for line in "${@}"
    do
        local VAULT=${hostnames[${index}]}
        local EVALUATOR=$(grep "^.Evaluators Enabled" /tmp/${line}.${PROGNAME}.log | awk -F '=' '{ print $2 }' | awk '{ print $1 }' )
        local DATARECOVERY=$(grep "^.DataRecovery" /tmp/${line}.${PROGNAME}.log | awk -F '=' '{ print $3 }' | awk '{ print $1 }' )
        local MIRRORRECOVERY=$(grep "^.MirrorRecovery" /tmp/${line}.${PROGNAME}.log | awk '{ print $3 }' )
        local LOCALMIRROR=$(grep "^.LocalMirror" /tmp/${line}.${PROGNAME}.log | awk -F '=' '{ print $3 }' | awk '{ print $1 }' )
        local DEFRAG=$(grep "^.Defrag" /tmp/${line}.${PROGNAME}.log | awk -F '=' '{ print $3 }' | awk '{ print $1 }' )
        local SMOOTH=$(grep "^.Smooth" /tmp/${line}.${PROGNAME}.log | awk -F '=' '{ print $3 }' | awk '{ print $1 }')
        local REMOTESMOOTH=$(grep "^.RemoteSmooth" /tmp/${line}.${PROGNAME}.log | awk -F '=' '{ print $2 }' | awk '{ print $1 }')

        VAULT=$(DEFAULT ${VAULT})
        EVALUATOR=$(RED ${EVALUATOR}) 
        DATARECOVERY=$(BLINK ${DATARECOVERY})
        MIRRORRECOVERY=$(DEFAULT ${MIRRORRECOVERY})
        LOCALMIRROR=$(DEFAULT ${LOCALMIRROR})
        DEFRAG=$(DEFAULT ${DEFRAG})
        SMOOTH=$(DEFAULT ${SMOOTH})
        REMOTESMOOTH=$(BLINK ${REMOTESMOOTH})

        printf "%b%-15s%b%b%10s%b%b%15s%b%b%20s%b%b%15s%b%b%10s%b%b%10s%b%b%15s%b\n" ${VAULT} ${EVALUATOR} ${DATARECOVERY} ${MIRRORRECOVERY} ${LOCALMIRROR} ${DEFRAG} ${SMOOTH} ${REMOTESMOOTH}

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

if [ ${#servers[@]} -eq 0 ]; then
    echo "There is no Vault nor Streamer to check in the ${SERVER_LIST_FILE} file"
    exit 0
fi

while true
do
    showRemoteValues "${servers[@]}"
    sleep ${LOOPTIME}
done
}

#
# Boot-strap
#
main "$@"
