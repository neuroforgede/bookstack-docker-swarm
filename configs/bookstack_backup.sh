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
PATH_NEW_FILE_SUCCESS="${BACKUP_SFTP_BASE_PATH}/bookstack_${DATE}.success"
echo "will dump to ${PATH_NEW_FILE}."

echo "starting dump."
tar -czvf - public/uploads storage/uploads \
    | curl -u "${BACKUP_SFTP_USER}:${_BACKUP_SFTP_PASSWORD}" -T - "sftp://${BACKUP_SFTP_TARGET}:${BACKUP_SFTP_BASE_PATH}/bookstack_${DATE}.tar.gz"
check_result "failed to dump to sftp"

# Create a .success marker file to indicate successful dump
echo "creating success marker file."
echo "Backup on ${DATE} was successful." | curl -u "${BACKUP_SFTP_USER}:${_BACKUP_SFTP_PASSWORD}" -T - "sftp://${BACKUP_SFTP_TARGET}:${PATH_NEW_FILE_SUCCESS}"
check_result "failed to create success marker file"

echo "files in dump path:"
curl --silent -u ${BACKUP_SFTP_USER}:${_BACKUP_SFTP_PASSWORD} -k "sftp://${BACKUP_SFTP_TARGET}:${BACKUP_SFTP_BASE_PATH}/"

echo "Checking for and deleting dumps without success markers..."
ALL_TGZ_FILES=$(curl --silent -u ${BACKUP_SFTP_USER}:${_BACKUP_SFTP_PASSWORD} -k "sftp://${BACKUP_SFTP_TARGET}:${BACKUP_SFTP_BASE_PATH}/" | grep -o -E "bookstack_[0-9]{4}_[0-9]{2}_[0-9]{2}_[0-9]{2}_[0-9]{2}_[0-9]{2}.tar.gz")

for tgz_file in $ALL_TGZ_FILES; do
    success_file="${tgz_file%.tar.gz}.success"
    # Check if the .success file exists
    if ! curl --silent -u ${BACKUP_SFTP_USER}:${_BACKUP_SFTP_PASSWORD} -k "sftp://${BACKUP_SFTP_TARGET}:${BACKUP_SFTP_BASE_PATH}/$success_file" &> /dev/null; then
        echo "No success marker for $tgz_file, deleting dump..."
        curl --silent -u ${BACKUP_SFTP_USER}:${_BACKUP_SFTP_PASSWORD} -k sftp://${BACKUP_SFTP_TARGET} -Q "rm ${BACKUP_SFTP_BASE_PATH}/$tgz_file" > /dev/null
    fi
done

echo "Organizing backups with intelligent versioning..."
# Your existing logic here for listing files and starting the cleanup process

# Intelligent versioning cleanup
python3 - <<EOF
import datetime
import subprocess

def execute_shell_command(cmd):
    result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    return result.stdout.strip().split('\n')

def filter_backups(files, pattern):
    return [f for f in files if pattern in f]

def timestamp_part_of_filename(filename):
    return filename.replace("bookstack_", "").replace(".tar.gz", "")

def keep_intelligent_versioning(files):
    now = datetime.datetime.now()
    hourly_backups = [now - datetime.timedelta(hours=x) for x in range(24)]
    daily_backups = [now - datetime.timedelta(days=x) for x in range(1, 8)]
    monthly_backups = [now - datetime.timedelta(days=30*x) for x in range(1, 13)]

    keep_files = set()

    # Hourly backups
    for dt in hourly_backups:
        closest = min(files, key=lambda x: abs(dt - datetime.datetime.strptime(timestamp_part_of_filename(x), '%Y_%m_%d_%H_%M_%S')))
        keep_files.add(closest)

    # Daily backups
    for dt in daily_backups:
        day_files = [f for f in files if dt.strftime('%Y_%m_%d') in f]
        if day_files:
            keep_files.add(min(day_files, key=lambda x: abs(dt - datetime.datetime.strptime(timestamp_part_of_filename(x), '%Y_%m_%d_%H_%M_%S'))))

    # Monthly backups
    for dt in monthly_backups:
        month_files = [f for f in files if dt.strftime('%Y_%m') in f]
        if month_files:
            keep_files.add(min(month_files, key=lambda x: abs(dt - datetime.datetime.strptime(timestamp_part_of_filename(x), '%Y_%m_%d_%H_%M_%S'))))

    nl = '\n'
    print(f"Files to keep: {nl.join(keep_files)}")
    return keep_files

# List all backup files
all_files = execute_shell_command('curl --silent -u ${BACKUP_SFTP_USER}:${_BACKUP_SFTP_PASSWORD} -k "sftp://${BACKUP_SFTP_TARGET}:${BACKUP_SFTP_BASE_PATH}/" | grep -o -E "bookstack_[0-9]{4}_[0-9]{2}_[0-9]{2}_[0-9]{2}_[0-9]{2}_[0-9]{2}.tar.gz"')

# Determine which files to keep
files_to_keep = keep_intelligent_versioning(all_files)

# Delete files not in the keep list
for file in set(all_files) - set(files_to_keep):
    print(f"Deleting {file}...")
    execute_shell_command(f'curl --silent -u ${BACKUP_SFTP_USER}:${_BACKUP_SFTP_PASSWORD} -k sftp://${BACKUP_SFTP_TARGET} -Q "rm ${BACKUP_SFTP_BASE_PATH}/{file}" > /dev/null')
    success_file = file.replace(".tar.gz", ".success")
    execute_shell_command(f'curl --silent -u ${BACKUP_SFTP_USER}:${_BACKUP_SFTP_PASSWORD} -k sftp://${BACKUP_SFTP_TARGET} -Q "rm ${BACKUP_SFTP_BASE_PATH}/{success_file}" > /dev/null')
EOF

echo "Done with intelligent versioning cleanup."

echo "files in dump path after cleanup:"
curl --silent -u ${BACKUP_SFTP_USER}:${_BACKUP_SFTP_PASSWORD} -k "sftp://${BACKUP_SFTP_TARGET}:${BACKUP_SFTP_BASE_PATH}/"

echo "done."
