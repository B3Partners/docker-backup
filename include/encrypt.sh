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

  success="true"
  start_time=$(date +"%s")

  for file in "${encrypt_dir}"/*; do
    print_msg "Encrypting file: $(basename $file)"
    gpg --quiet --output "${file}.gpg" --encrypt --recipient-file "${KEYFILE}" "${file}"
    if [[ $? -ne 0 ]]; then
      success="false"
      break
    fi
  done

  end_time=$(date +"%s")

  if [[ $success = "true" ]]; then
    elapsed_time=$((end_time - start_time))
    print_msg "Encryption succeeded and took ${elapsed_time} seconds"
    find $DIR_BACKUP/ -type f ! \( -name "*.gpg" -o -name "*.keep" -o -name "*.sha256" \) -exec rm {} \;
  else
    print_error_and_exit "Encryption failed, invalid key specified? Unencrypted backup remains on system, but not uploading unencrypted backup to SFTP"
  fi
}