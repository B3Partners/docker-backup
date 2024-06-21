#!/bin/bash
# This script uses gpg to encrypt files

encrypt_files() {
    if [[ $ENCRYPT != "true" ]]; then
        return
    fi
    mkdir -p $(dirname $KEYFILE)
    touch $KEYFILE

    echo "-----BEGIN PGP PUBLIC KEY BLOCK-----" > $KEYFILE
    echo "                                    " >> $KEYFILE
    echo "${PUBLIC_KEY}" >> $KEYFILE
    echo "-----END PGP PUBLIC KEY BLOCK----" >> $KEYFILE


    encrypt_dir=${DIR_BACKUP}

    success=true  # assume success initially

    start_time=$(date +"%s")   # record the current time in seconds since epoch

    for file in "${encrypt_dir}"/*; do
        print_msg "encrypting file: ${file} "
        gpg --quiet --output "${file}.gpg" --encrypt --recipient-file "${KEYFILE}" "${file}"
        if [ $? -ne 0 ]; then  # check the exit status of the last command
            success=false
            break
        fi
    done

    end_time=$(date +"%s")  # record the current time in seconds since epoch after encryption is complete

    if $success; then
        elapsed_time=$((end_time - start_time))  # calculate the difference between the two times
        print_msg "Encryption succeeded and took ${elapsed_time} seconds"
        find $DIR_BACKUP/ -type f ! \( -name "*.gpg" -o -name "*.keep" -o -name "*.sha256" \) -exec rm {} \;
        else
        print_error "Encryption failed causing back-up failure."
    fi

}