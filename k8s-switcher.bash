#!/usr/bin/env bash

### Trap signals
signal_exit() {
  local l_signal
  l_signal="$1"

  case "$l_signal" in
  INT)
    error_exit "Program interrupted by user"
    ;;
  TERM)
    error_exit "Program terminated"
    ;;
  *)
    error_exit "Terminating on unknown signal"
    ;;
  esac
}

trap "signal_exit TERM" TERM HUP
trap "signal_exit INT" INT

### Const
readonly SCRIPT_LOCATION="~/programs/k8s-switcher"
readonly PROGRAM_NAME=${0##*/}
readonly PROGRAM_VERSION="1.0.0"
readonly EXTERNAL_BINARIES="grep sed "
readonly EXTERNAL_SOURCES="${SCRIPT_LOCATION}/base-source.sh"
readonly is_number='^[0-9]+$'

### Var
# Colors declaration
declare -A Colors
Colors["yellow"]='\033[1;33m'
Colors["blue"]='\033[0;34m'
Colors["cyan"]='\033[0;36m'
Colors["white"]='\033[1;37m'
Colors["magenta"]='\033[1;36m'
Colors["red"]='\033[0;31m'
Colors["green"]='\033[0;32m'
Colors["end"]='\033[0m'

# Error declaration
declare -A ErrorCodes
ErrorCodes["err.generic.connection"]="Internet Connection must be up. Aborting..."
ErrorCodes["err.generic.vpn"]="VPN Connection must be up. Trying to connect..."
ErrorCodes["err.generic.vpn.upScriptError"]="Error occurred while connecting to VPN with up script. Aborting..."
ErrorCodes["err.generic.vpn.scriptNotFound"]="VPN Script folder is not settled. Setting up..."
ErrorCodes["err.config.fileIsEmpty"]="Configuration file is empty. Aborting..."
ErrorCodes["err.config.noFileFound"]="No configuration files found. Choose import special command..."
ErrorCodes["err.config.invalidIndex"]="Invalid configuration index selected. Aborting..."
ErrorCodes["err.country.invalidIndex"]="Invalid country index selected. Aborting..."
ErrorCodes["err.generic.invalidInteger"]="Integer number needed. Aborting..."
ErrorCodes["err.lib.libraryCheckFailed"]="Libraries Check Failed. Aborting..."
ErrorCodes["err.banner.notFound"]="No Banner Found or Retrieved..."

### Args
LOG_LEVEL="STABLE"

### Welcome
printf "Hello %s - Welcome to %s v%s\n" "$(whoami)" "$PROGRAM_NAME" "$PROGRAM_VERSION"

# Helpers
clean_up() {
  return
}

error_exit() {
  local l_error_message
  l_error_message="$1"

  printf "[ERROR] - %s\n" "${l_error_message:-'Unknown Error'}" >&2
  echo "Exiting with exit code 1"
  clean_up
  exit 1
}

graceful_exit() {
  clean_up
  exit 0
}

load_libraries() {
  for _ext_bin in $EXTERNAL_BINARIES; do
    if ! hash "$_ext_bin" &>/dev/null; then
      error_exit "Required binary $_ext_bin not found."
    fi
  done
}

load_sources() {
  for _ext_src in $EXTERNAL_SOURCES; do
    # shellcheck disable=SC1090
    if bash $_ext_src --check &>/dev/null; then
      source $_ext_src
      echo "Loaded $_ext_src"
    else
      error_exit "[$_ext_src] - Check library returned non-zero code"
    fi
  done
}

help_message() {
  cat <<-_EOF_

Description  : Git clone via SSH a set of project under a specific groupId,
               projects will be cloned in launch directory.
Example usage: 

Options:
  [-h | --help]                      Display this help message
  [-v | --verbose]        (OPTIONAL) More verbose output
  [--trace]               (OPTIONAL) Set -o xtrace
  [--version]                        Show program version
_EOF_
  return
}

### Func
log_debug() {
  local l_message
  l_message="$1"

  if [ $LOG_LEVEL == "DEBUG" ]; then
    echo "[DEBUG] - $l_message"
  fi
}

log_info() {
  local l_message
  l_message="$1"
  echo "[INFO] - $l_message"
}

log_error() {
  local l_message
  l_message="$1"
  echo "[ERROR] - $l_message"
}

ask_user_permission() {
  local l_message
  l_message="$1"

  printf "%s (y/n): " "$l_message"

  local l_continue
  read -r l_continue

  if [ "$l_continue" == "y" ]; then
    echo "OK"
  elif [ "$l_continue" == "n" ]; then
    graceful_exit
  else
    echo "Invalid choice [$l_continue]! Retrying..."
    ask_user_permission "$l_message"
  fi
}

### Check binaries
load_libraries

### Load Sources
load_sources

### Parse args
while [[ -n "$1" ]]; do
  case "$1" in
  -h | --help)
    help_message
    graceful_exit
    ;;
  -v | --verbose)
    LOG_LEVEL="DEBUG"
    ;;
  --trace)
    set -o xtrace
    ;;
  --version)
    printf "Running version: %s\n" "$PROGRAM_VERSION"
    graceful_exit
    ;;
  --* | -*)
    usage >&2
    error_exit "Unknown option $1"
    ;;
  esac
  shift
done

### Checking args

### Main logic
configuration_list=()
# shellcheck disable=SC2010
for _i in $(ls -la ~/.kube | grep config_ | awk '{print $9}' | sort); do
  if [[ -f ~/.kube/"$_i" ]] && [ -s ~/.kube/"$_i" ]; then
    configuration_list+=("$_i")
  fi
done

# Check if configuration_list size is greater than 0
if ! (("${#configuration_list[@]}")); then
  first_index=-1
  log_error "${ErrorCodes["err.config.noFileFound"]}"
else
  first_index=0
fi

# shellcheck disable=SC2059
printf "\n ${Colors["magenta"]}***${Colors["end"]} ${Colors["green"]}SELECT KUBERNETES ENVIRONMENT ${Colors["end"]}${Colors["magenta"]}***${Colors["end"]}\n\n"

# Print all config files with index
for key in "${!configuration_list[@]}"; do
  cmp --silent ~/.kube/config ~/.kube/"${configuration_list[$key]}"
  # shellcheck disable=SC2181
  if [ "$?" = 0 ]; then
    echo -e "${Colors["green"]}$key) ${configuration_list[$key]} (Applied)${Colors["end"]}"
  else
    echo -e "${Colors["blue"]}$key) ${configuration_list[$key]}${Colors["end"]}"
  fi
done

# shellcheck disable=SC2059
printf "\n${Colors["cyan"]}Insert your choice:${Colors["end"]} ${Colors["white"]}[${first_index}-$((${#configuration_list[@]} - 1))]${Colors["end"]} "
read -r opt

# Check if option is a number
if ! [[ $opt =~ $is_number ]]; then
  error_exit "${ErrorCodes["err.generic.invalidInteger"]}"
fi
if (("$opt" >= 0)); then
  if (("$opt" <= $((${#configuration_list[@]} - 1)))); then
    log_info "$(echo -e "Applied ${configuration_list[$opt]} configuration..." | sed -r 's/config_+//g')"
    # shellcheck disable=SC2002
    cat ~/.kube/"${configuration_list[$opt]}" | tee ~/.kube/config >/dev/null
    graceful_exit
  fi
fi

error_exit "${ErrorCodes["err.config.invalidIndex"]}"
### Finalize
graceful_exit
