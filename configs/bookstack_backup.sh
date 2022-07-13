#!/bin/bash

check_result () {
    ___RESULT=$?
    if [ $___RESULT -ne 0 ]; then
        echo $1
        exit 1
    fi
}

set -e -o pipefail

echo "before starting backup, ensure this container works properly"
sleep 60

_BACKUP_SFTP_PASSWORD=$(/bin/cat /run/secrets/storagebox_password)


echo "getting current date..."
DATE=`date '+%Y_%m_%d_%H_%M_%S'`

PATH_NEW_FILE="${BACKUP_SFTP_BASE_PATH}/bookstack_${DATE}.tar.gz"
echo "will dump to ${PATH_NEW_FILE}."

echo "starting dump."
tar -czvf - public/uploads storage/uploads \
    | curl -u "${BACKUP_SFTP_USER}:${_BACKUP_SFTP_PASSWORD}" -T - "sftp://${BACKUP_SFTP_TARGET}:${BACKUP_SFTP_BASE_PATH}/bookstack_${DATE}.tar.gz"
check_result "failed to dump to sftp"

echo "files in dump path:"
curl --silent -u ${BACKUP_SFTP_USER}:${_BACKUP_SFTP_PASSWORD} -k "sftp://${BACKUP_SFTP_TARGET}:${BACKUP_SFTP_BASE_PATH}/"

OLD_FILES=$(
    curl --silent -u ${BACKUP_SFTP_USER}:${_BACKUP_SFTP_PASSWORD} -k "sftp://${BACKUP_SFTP_TARGET}:${BACKUP_SFTP_BASE_PATH}/" \
    | grep -o -E "bookstack_[0-9]{4}_[0-9]{2}_[0-9]{2}_[0-9]{2}_[0-9]{2}_[0-9]{2}.tar.gz" \
    | sort -r \
    | tail -n +${BACKUP_KEEP_LAST_N_DUMPS} \
)

echo "cleaning up, but keeping last ${BACKUP_KEEP_LAST_N_DUMPS} dumps..."
for elem in $OLD_FILES;
do
    if [ "$elem" != "bookstack_${DATE}.tar.gz" ]; then
        echo "deleting old dump $elem."
        curl --silent -u ${BACKUP_SFTP_USER}:${_BACKUP_SFTP_PASSWORD} -k sftp://${BACKUP_SFTP_TARGET} -Q "rm ${BACKUP_SFTP_BASE_PATH}/$elem" > /dev/null
    fi
done

echo "files in dump path:"
curl --silent -u ${BACKUP_SFTP_USER}:${_BACKUP_SFTP_PASSWORD} -k "sftp://${BACKUP_SFTP_TARGET}:${BACKUP_SFTP_BASE_PATH}/"

echo "done."