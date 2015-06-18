#!/bin/bash

#set -x

#	Author Laurent Orban

ARGUMENT=$1
FILE_PATH=$(dirname "$1")
FILE=$(basename "$1")

cd ${FILE_PATH}

HOST='10.50.212.97'
USER='laorban'
PASSWORD="J'aimelechocol4t"

ftp -n $HOST << __EO_FTP__
quote USER ${USER}
quote PASS ${PASSWORD}
put ${FILE}
quit
__EO_FTP__

exit 0