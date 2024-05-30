#!/bin/bash
# This script uses gpg to encrypt files

encrypt_files() {
    if [[ $ENCRYPT != "true" ]]; then
        return
    fi
    encrypt_dir=${DIR_BACKUP}
    success=true  # assume success initially

    start_time=$(date +"%s")*1000   # record the current time in seconds since epoch

    for file in "${encrypt_dir}"/*; do
        print_msg "encrypting file: ${file} "
        gpg --quiet --output "${file}.gpg" --encrypt --recipient-file "${KEYFILE}" "${file}"
        if [ $? -ne 0 ]; then  # check the exit status of the last command
            success=false
            break
        fi
    done

    end_time=$(date +"%s")*1000  # record the current time in seconds since epoch after encryption is complete

    if $success; then
        elapsed_time=$((end_time - start_time))  # calculate the difference between the two times
        minutes=$((elapsed_time / 60))
        seconds=$((elapsed_time % 60))
        miliseconds=$((elapsed_time % 1 * 1000))
        print_msg "Encryption succeeded and took ${minutes} minutes ${seconds} seconds and ${miliseconds} milliseconds"
    else
        print_error "Encryption failed."
    fi
}