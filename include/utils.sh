#!/bin/bash

backup_directory() {
  if [[ -n "$BACKUP_DIR" ]]; then
    print_msg "Backing up directory $BACKUP_DIR, size `du -bhs $BACKUP_DIR | awk '{print $1}'`"
    if [[ ! $STARTUP ]]; then
      rm $DIR_BACKUP/files.tar.* 2>/dev/null
      tar acP $BACKUP_DIR | $TAR_COMPRESS > $DIR_BACKUP/files.tar.$TAR_COMPRESS || print_error "Error backing up directory $BACKUP_DIR"
    fi
  fi
}

upload_backup() {
  if [[ -z "$SFTP_HOST" || -z "$SSHPASS" ]]; then
    print_msg WARN "No SFTP_HOST/SSHPASS defined, not copying backup"
    return
  fi
  SFTP=$SFTP_USER@$SFTP_HOST:$SFTP_PATH
  print_msg "Copying backup size `du -bhs $DIR_BACKUP/ | awk '{print $1}'` to SFTP $SFTP"
  rm $DIR_UPLOADED/* 2>/dev/null
  mkdir -p ~/.ssh && ssh-keyscan -H $SFTP_HOST 2> /dev/null > $HOME/.ssh/known_hosts
  sshpass -e scp -p $DIR_BACKUP/* $SFTP && mv $DIR_BACKUP/* $DIR_UPLOADED/ || print_error "[ERR] Error copying to SFTP server"
}