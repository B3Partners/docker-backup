#!/bin/bash

print_msg() {
  local type="INFO";
  local msg="$1";
  if [[ -n "$2" ]]; then
    type=$1
    msg=$2
  fi
  echo "$(date +"%Y-%m-%dT%H:%M:%S") [$type] $msg"
}

print_error() {
  print_msg ERROR $1
  EXITCODE=1
}

print_error_and_exit() {
  print_error $1
  exit 1
}