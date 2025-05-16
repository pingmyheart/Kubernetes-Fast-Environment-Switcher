#!/usr/bin/env bash

### Const
readonly _EXTERNAL_BINARIES=""

### Helpers
_load_libraries() {
  for _ext_bin in $_EXTERNAL_BINARIES; do
    if ! hash "$_ext_bin" &>/dev/null; then
      return 1
    fi
  done
}

### Parse args
while [[ -n "$1" ]]; do
  case "$1" in
  --check)
    if ! _load_libraries &>/dev/null; then
      exit 1
    else
      exit 0
    fi
    ;;
  esac
  shift
done

### Main Source
