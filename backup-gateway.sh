#!/bin/bash

#list of servers, one per line
SERVER_LIST='/vagrant/servers'
#modify function to allow user to select which remote server to execute command on
REMOTE_SERVER_NUM='all'
#options for ssh command
SSH_OPTIONS='-o ConnectTimeout=10'

#
BACKUP=''
# Display the usage and exit
usage() {
    echo "Usage: ${0} [-nrv] [-f FILE] [-s SERVER] [-b GATEWAY]" >&2
    echo 'Backup Ignition gateway on specified server.' >&2
    echo '  -f FILE Use FILE for the list of servers. Default: /vagrant/servers.' >&2
    echo '  -n Dry run mode. Display the COMMAND that would have been executed and exit.' >&2
    echo '  -r Execute the COMMAND using sudo on the remote server.' >&2
    echo '  -v Verbose mode. Displays the server name before executing COMMAND.' >&2
    echo '  -s SERVER Use SERVER for remote server to execute command on. Default: all remote servers' >&2
    echo '  -b GATEWAY backup specified gateway. First select server using -s and then select server' >&2
    exit 1
}

# Make sure script is not executed with superuser privileges
if [[ "${UID}" -eq 0 ]]
then
    echo 'Do not execute this script as root. Use the -s option instead.' >&2
    usage
fi

# Parse the options
while getopts f:s:b:nv OPTION
do
    case ${OPTION} in
        f) SERVER_LIST="${OPTARG}" ;;
        n) DRY_RUN='true' ;;
        v) VERBOSE='true' ;;
        s) REMOTE_SERVER_NUM="${OPTARG}" ;;
        b) BACKUP='true' ; CONTAINER="${OPTARG}" ;;
        ?) usage ;;
    esac
done

# Make sure the server list file exists
if [[ ! -e "${SERVER_LIST}" ]]
then
    echo "Cannot open the server list file ${SERVER_LIST}" >&2
    exit 1
fi


#expect best but prepare for worst
EXIT_STATUS='0'
# Loop through the server list
if [[ "${REMOTE_SERVER_NUM}" -eq 'all' ]]
then
    for SERVER in $(cat ${SERVER_LIST})
    do
        if [[ "${VERBOSE}" -eq 'true' ]]
        then
            echo "Backing up gateways on ${SERVER}..."
        fi
        #back up all gateways on current server
        if [[ "${SERVER}" = 'server01' ]]
        then
            for GATEWAY in edge basic;
            do
                #build command from options and variables
                GWCMD='"./gwcmd.sh -b ."'
                COMMAND="docker exec ${GATEWAY} bash -c ${GWCMD}" 
                SSH_COMMAND="ssh ${SSH_OPTIONS} ${SERVER} ${COMMAND}"
                ${SSH_COMMAND}
                SSH_EXIT_STATUS="${?}"
                # capture any non-zero status from SSH command and report to user
                if [[ "${SSH_EXIT_STATUS}" -ne 0 ]]
                then
                    EXIT_STATUS="${SSH_EXIT_STATUS}"
                    echo "Execution on ${SERVER} failed."
                fi
            done
        else
            for GW in edge frontend backend;
            do
                #build command from options and variables
                GWCMD='"./gwcmd.sh -b ."'
                COMMAND="docker exec ${GW} bash -c ${GWCMD}" 
                SSH_COMMAND="ssh ${SSH_OPTIONS} ${SERVER} ${COMMAND}"
                ${SSH_COMMAND}
                SSH_EXIT_STATUS="${?}"
                # capture any non-zero status from SSH command and report to user
                if [[ "${SSH_EXIT_STATUS}" -ne 0 ]]
                then
                    EXIT_STATUS="${SSH_EXIT_STATUS}"
                    echo "Execution on ${SERVER} failed."
                fi
            done
        fi
        # if it's a dry run, don't execute anything, just echo it.
        if [[ "${DRY_RUN}" = 'true' ]]
        then
            #just echo
            echo "DRY RUN: ${SSH_COMMAND}"
        else
            #actually execute
            ${SSH_COMMAND}
            SSH_EXIT_STATUS="${?}"
            # capture any non-zero status from SSH command and report to user
            if [[ "${SSH_EXIT_STATUS}" -ne 0 ]]
            then
                EXIT_STATUS="${SSH_EXIT_STATUS}"
                echo "Execution on ${SERVER} failed."
            fi
        fi
    done
else
    if [[ "${VERBOSE}" = 'true' ]]
    then
        echo "backing up ${CONTAINER} on server0${REMOTE_SERVER_NUM}..."
    fi
    #build command from options and variables
    GWCMD='"./gwcmd.sh -b ."'
    COMMAND="docker exec ${CONTAINER} bash -c ${GWCMD}" 
    SSH_COMMAND="ssh ${SSH_OPTIONS} server0${REMOTE_SERVER_NUM} ${COMMAND}"

    # if it's a dry run, don't execute anything, just echo it.
    if [[ "${DRY_RUN}" = 'true' ]]
    then
        #just echo
        echo "DRY RUN: ${SSH_COMMAND}"
    else
        #actually execute
        ${SSH_COMMAND}
        SSH_EXIT_STATUS="${?}"
        # capture any non-zero status from SSH command and report to user
        if [[ "${SSH_EXIT_STATUS}" -ne 0 ]]
        then
            EXIT_STATUS="${SSH_EXIT_STATUS}"
            echo "Execution on ${SERVER} failed."
        fi
    fi
fi

