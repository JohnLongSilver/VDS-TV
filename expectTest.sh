#!/bin/bash 

#set -x

SSH_CONNECTION_TIMEOUT=10

#
#
#
retrieveContentNumber() {

    expect << __END_OF_EXPECT__ | grep "Content from database: Count:" | sed 's/Content from database: Count://'
    spawn ssh -o ConnectTimeout=${SSH_CONNECTION_TIMEOUT} -o StrictHostKeyChecking=no root@10.50.205.42 '/arroyo/db/AVSDBUtil'
    expect -exact ": "
    send -- "1\r"
    expect -exact ": "
    send -- "2\r"
    expect -exact ": "
    send -- "0\r"
    expect eof"
__END_OF_EXPECT__

}

main() {

    retrieveContentNumber
}

#
# Boot-strap
#
main "$@"
