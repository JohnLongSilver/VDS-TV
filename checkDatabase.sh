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
#
#
retrieveNSDStatus() {

    local index=0

    for line in "${@}"
    do
        {
            # prevent Ctrl-C the loop
            # trap ':' INT

            >/tmp/${line}.${PROGNAME}.log

            #will later add -n to ssh in order to prevent it from reading stdin
            ssh -o ConnectTimeout=${SSH_CONNECTION_TIMEOUT} -o StrictHostKeyChecking=no root@${line} 'bash -s' << __EO_SSH__ > /tmp/${line}.${PROGNAME}.log

            grep ": No Servers Down" /arroyo/log/avsdb.log | tail -1
__EO_SSH__
        }

    let index++
    done
}

#
#
#
retrieveSDStatus() {

    local index=0

    for line in "${@}"
    do
        {
            # prevent Ctrl-C the loop
            # trap ':' INT

            >/tmp/${line}.${PROGNAME}.log

            #will later add -n to ssh in order to prevent it from reading stdin
            ssh -o ConnectTimeout=${SSH_CONNECTION_TIMEOUT} -o StrictHostKeyChecking=no root@${line} 'bash -s' << __EO_SSH__ > /tmp/${line}.${PROGNAME}.log

            grep ": Servers Down" /arroyo/log/avsdb.log | tail -1
__EO_SSH__
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

            >/tmp/${line}.Database.log

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
retrieveNETSTATStatus() {

    local index=0

    for line in "${@}"
    do
        {
            # prevent Ctrl-C the loop
            # trap ':' INT

            >/tmp/${line}.${PROGNAME}.log

            #will later add -n to ssh in order to prevent it from reading stdin
            ssh -o ConnectTimeout=${SSH_CONNECTION_TIMEOUT} -o StrictHostKeyChecking=no root@${line} 'bash -s' << __EO_SSH__ > /tmp/${line}.${PROGNAME}.log

            netstat -an | grep 9999
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
            # prevent Ctrl-C the loop
            # trap ':' INT

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
showNSDtatus() {

    retrieveNSDStatus "${servers[@]}"

    for line in "${@}"
    do
        cat /tmp/${line}.${PROGNAME}.log | sed 's/No Servers Down,/NSD/' | awk '{print $1" "$2" "$3" "$4"\t\t"$6}' | sed 's/NSD/No Servers Down/'
    done
}

#
#
#
showSDtatus() {

    retrieveSDStatus "${servers[@]}"

    for line in "${@}"
    do
        cat /tmp/${line}.${PROGNAME}.log | sed 's/Servers Down,/SD/' | awk '{print $1" "$2" "$3" "$4"\t\t"$6}' | sed 's/NSD/Servers Down/'
    done
}

#
#
#
showBackLogStatus() {

    retrieveBackLogStatus "${servers[@]}"

    for line in "${@}"
    do
        awk '{ printf "%s %s %s %s\t\tBacklog:%s\n", $1, $2, $3, $4, $14 }' /tmp/${line}.${PROGNAME}.log
    done
}

#
#
#
showNETSTATtatus() {

    retrieveNETSTATStatus "${servers[@]}"

    local index=0

    for line in "${@}"
    do
        echo ${hostnames[${index}]}

        grep -v LISTEN /tmp/${line}.${PROGNAME}.log | awk '{print $4"\t"$5"\t"$6}'
    
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

setMasterVault "${servers[@]}"

showNSDtatus "${servers[@]}"

showSDtatus "${servers[@]}"

showBackLogStatus "${servers[@]}"

showNETSTATtatus "${servers[@]}"

}

#
# Boot-strap
#
main "$@"
