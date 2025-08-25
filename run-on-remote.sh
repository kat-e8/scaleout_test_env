#!/bin/bash

#list of servers, one per line
SERVER_LIST='/vagrant/servers'
#modify function to allow user to select which remote server to execute command on
REMOTE_SERVER_NUM='all'
#options for ssh command
SSH_OPTIONS='-o ConnectTimeout=10'

# Display the usage and exit
usage() {
    echo "Usage: ${0} [-nrv] [-f FILE] [-s SERVER] COMMAND" >&2
    echo 'Executes COMMAND as a single command on every server.' >&2
    echo '  -f FILE Use FILE for the list of servers. Default: /vagrant/servers.' >&2
    echo '  -n Dry run mode. Display the COMMAND that would have been executed and exit.' >&2
    echo '  -r Execute the COMMAND using sudo on the remote server.' >&2
    echo '  -v Verbose mode. Displays the server name before executing COMMAND.' >&2
    echo '  -s SERVER Use SERVER for remote server to execute command on. Default: all remote servers' >&2
    exit 1
}

# Make sure script is not executed with superuser privileges
if [[ "${UID}" -eq 0 ]]
then
    echo 'Do not execute this script as root. Use the -s option instead.' >&2
    usage
fi

# Parse the options
while getopts f:s:nrv OPTION
do
    case ${OPTION} in
        f) SERVER_LIST="${OPTARG}" ;;
        n) DRY_RUN='true' ;;
        r) SUDO='sudo';;
        v) VERBOSE='true' ;;
        s) REMOTE_SERVER_NUM="${OPTARG}" ;;
        ?) usage ;;
    esac
done

# Remove the options while leaving remaining arguments
shift "$(( OPTIND - 1 ))"
# if user doesn't supply at least one argument, give them help
if [[ "${#}" -lt 1 ]]
then
    usage
fi
# Anything that remains in the command line is to be treated as a single command
COMMAND="${@}"
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
        if [[ "${VERBOSE}" = 'true' ]]
        then
            echo "${SERVER}"
        fi
        #build command from options and variables
        SSH_COMMAND="ssh ${SSH_OPTIONS} ${SERVER} ${SUDO} ${COMMAND}"
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
        echo "server0${REMOTE_SERVER_NUM}"
    fi
    #build command from options and variables
    SSH_COMMAND="ssh ${SSH_OPTIONS} server0${REMOTE_SERVER_NUM} ${SUDO} ${COMMAND}"
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

exit ${EXIT_STATUS}
    