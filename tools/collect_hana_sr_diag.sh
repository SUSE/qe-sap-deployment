#!/bin/bash
set -e
#set -x

# --- GLOBAL ---
SSH_USER='cloudadmin' # eventually overwritten by in  parse_inventory_file

# --- Script Setup ---
# Function to parse config.yaml
parse_config_file() {
    local config_file="$1"
    local sid=''
    local instance_num=''
    local provider_val=''

    if [[ -f $config_file ]]; then
        sid=$(sed -n -e '/^[[:space:]]*#/d' -e "/sap_hana_install_sid:/ { s/.*sap_hana_install_sid:[[:space:]]*//; s/['\"]//g; s/#.*//; p; q }" "$config_file" | xargs)
        instance_num=$(grep "sap_hana_install_instance_number:" "$config_file" | grep -v '^[[:space:]]*#' | head -n 1 | sed -e 's/.*sap_hana_install_instance_number:[[:space:]]*//' -e "s/['\"]//g" -e 's/#.*//' | xargs)
        # The following command extracts the provider value from the YAML config_file.
        # It handles values with or without quotes (e.g., 'azure', "azure", azure),
        # trims whitespace, and ignores commented lines.
        provider_val=$(sed -n -e '/^[[:space:]]*#/d' -e "/provider:/ { s/.*provider:[[:space:]]*//; s/['\"]//g; s/#.*//; p; q }" "$config_file" | xargs)
    fi

    echo "$sid $instance_num $provider_val"
}

# --- Helper Function ---
log_message() {
    local level="$1"
    local message="$2"
    if [[ $LOG_FILE == '/dev/stdout' ]]; then
        echo "[$level] $message"
    else
        echo "[$level] $message" | tee -a "$LOG_FILE"
    fi
}

print_header() {
    log_message 'INFO' '=============================================================================='
    log_message 'INFO' "=> $1"
    log_message 'INFO' '=============================================================================='
}

check_file() {
    if [[ -s $1 ]]; then
        log_message 'SUCCESS' "Collected: $1"
        return 0 # Indicate success
    else
        log_message 'WARNING' "Collected file: $1 is empty. This might indicate an issue with the collection command."
        return 1 # Indicate warning/failure
    fi
}

# Declare associative array for remote tool cache
declare -gA REMOTE_TOOL_CACHE

check_and_run_remote_command() {
    local node_ip="$1"
    local tool_name="$2"
    local remote_command="$3"
    local output_file="$4"   # Optional: where to save stdout
    local log_errors_to="$5" # Optional: where to save stderr
    local cache_key="${node_ip}_${tool_name}"
    local tool_check_result

    # Special handling for hdbnsutil and HDBSettings: skip 'which' check if full path is provided in remote_command
    if [[ $tool_name == 'hdbnsutil' || $tool_name == 'HDBSettings' ]]; then
        tool_check_result=0
        log_message "INFO" "Skipping 'which' check for '$tool_name' as full path is expected in remote command."
        REMOTE_TOOL_CACHE[$cache_key]=$tool_check_result
    else
        # Determine if `which` needs sudo
        local which_prefix=''
        if [[ $remote_command == *sudo* ]]; then
            which_prefix='sudo '
        fi
        local which_cmd="${which_prefix}which \\$tool_name"

        # Only check each executable or tool once
        if [[ -v REMOTE_TOOL_CACHE[$cache_key] ]]; then
            tool_check_result=${REMOTE_TOOL_CACHE[$cache_key]}
            #log_message "INFO" "Using cached result for '$tool_name' on $node_ip: $([[ $tool_check_result -eq 0 ]] && echo 'Found' || echo 'Not Found')."
        else
            log_message 'INFO' "Checking if '$tool_name' exists on $node_ip (first check)..."
            # shellcheck disable=SC2029
            if ssh "${SSH_USER}@${node_ip}" "$which_cmd" &>/dev/null; then
                tool_check_result=0
                log_message 'SUCCESS' "'$tool_name' found on $node_ip."
            else
                tool_check_result=1
                log_message 'ERROR' "'$tool_name' not found or not executable on $node_ip. Skipping command."
            fi
            REMOTE_TOOL_CACHE[$cache_key]=$tool_check_result
        fi
    fi
    if [[ $tool_check_result -ne 0 ]]; then
        # Tool not found, so we return immediately. No need to log "Skipping command" here,
        # as it was logged when tool_check_result was determined.
        return 1
    fi

    log_message 'INFO' "Running: $remote_command on $node_ip"
    local command_failed=0
    if [[ -n $output_file ]]; then
        # shellcheck disable=SC2029
        ssh "${SSH_USER}@${node_ip}" "$remote_command" >"$output_file" 2>>"${log_errors_to:-$LOG_FILE}" || command_failed=1
    else
        # shellcheck disable=SC2029
        ssh "${SSH_USER}@${node_ip}" "$remote_command" 2>>"${log_errors_to:-$LOG_FILE}" || command_failed=1
    fi

    if [[ $command_failed -ne 0 ]]; then
        if [[ $tool_name == 'HDBSettings' ]]; then
            log_message 'WARNING' "Remote command '$remote_command' on $node_ip returned non-zero exit code. Ignoring as requested for HDBSettings."
            return 0
        else
            log_message 'ERROR' "Remote command '$remote_command' failed on $node_ip."
            return 1
        fi
    fi
    return 0
}

parse_inventory_file() {
    local inventory_file="$1"
    local primary_ip=''
    local secondary_ip=''
    local ssh_user='cloudadmin' # Default SSH user

    if [[ -f $inventory_file ]]; then
        # The hostnames can have prefixes. We search for hosts ending in vmhana01 and vmhana02.
        primary_ip=$(grep -A 1 -- '.*vmhana01:' "$inventory_file" | grep 'ansible_host:' | awk -F: '{print $2}' | xargs | tr -d "'\"")
        secondary_ip=$(grep -A 1 -- '.*vmhana02:' "$inventory_file" | grep 'ansible_host:' | awk -F: '{print $2}' | xargs | tr -d "'\"")

        # Attempt to extract ansible_user from vmhana01. If not found, it remains "cloudadmin".
        local extracted_user
        extracted_user=$(grep -A 2 -- '.*vmhana01:' "$inventory_file" | grep 'ansible_user:' | awk '{print $2}' | tr -d "'\"")
        if [[ -n $extracted_user ]]; then
            ssh_user="$extracted_user"
        fi
    fi
    echo "$primary_ip $secondary_ip $ssh_user"
}

collect_hdbnsutil_command() {
    local node_ip="$1"
    local output_dir="$2"
    local subcommand="$3"       # e.g., "-sr_state", "-sr_stateConfiguration"
    local output_filename="$4"  # e.g., "hdbnsutil_sr_state.txt"
    local tool_name='hdbnsutil' # Used for the 'which' check exemption
    local remote_command="sudo su - ${SAP_SID,,}adm -c '/usr/sap/${SAP_SID}/HDB${INSTANCE_NUM}/exe/hdbnsutil ${subcommand}'"
    local output_file="${output_dir}/${output_filename}"

    log_message 'INFO' "Collecting: hdbnsutil ${subcommand}"
    if check_and_run_remote_command "${node_ip}" "${tool_name}" "${remote_command}" "${output_file}" "${LOG_FILE}"; then
        check_file "${output_file}"
    fi
}

collect_hdbsettings_script() {
    local node_ip=$1
    local output_dir=$2
    local script_name=$3          # e.g., "landscapeHostConfiguration.py", "systemReplicationStatus.py"
    local tool_name='HDBSettings' # Use "HDBSettings" as the tool_name for the which check exemption

    local remote_command="sudo su - ${SAP_SID,,}adm -c 'HDBSettings.sh ${script_name}'"
    local output_file="${output_dir}/${script_name%.py}.txt" # Remove .py extension and add .txt

    log_message 'INFO' "Collecting: ${script_name}"
    if check_and_run_remote_command "${node_ip}" "${tool_name}" "${remote_command}" "${output_file}" "${LOG_FILE}"; then
        check_file "${output_file}"
    fi
}

collect_firewall_rules() {
    log_message 'INFO' "Checking firewalld status on $1..."
    if check_and_run_remote_command "$1" "systemctl" "sudo systemctl is-active firewalld" >/dev/null; then
        log_message 'INFO' "Collecting: firewall-cmd --list-all"
        if check_and_run_remote_command "$1" "firewall-cmd" "sudo firewall-cmd --list-all" "$2"; then
            check_file "$2"
        fi
    else
        log_message 'INFO' "firewalld is not running on $1. Skipping firewall rule collection."
        echo "firewalld is not running" >"$2"
    fi
}

collect_system_info() {
    log_message 'INFO' "Collecting OS version"
    if check_and_run_remote_command "$1" "cat" "cat /etc/os-release" "$2/os_version.txt"; then
        check_file "$2/os_version.txt"
    fi
    if check_and_run_remote_command "$1" "hostnamectl" 'hostnamectl | grep "Operating System"' "$2/hostnamectl.txt"; then
        check_file "$2/hostnamectl.txt"
    fi

    log_message 'INFO' 'Collecting Pacemaker version'
    if check_and_run_remote_command "$1" "rpm" "rpm -q pacemaker" "$2/pacemaker_version.txt"; then
        check_file "$2/pacemaker_version.txt"
    fi

    log_message 'INFO' 'Collecting crmsh version'
    if check_and_run_remote_command "$1" "rpm" "rpm -q crmsh" "$2/crmsh_version.txt"; then
        check_file "$2/crmsh_version.txt"
    fi

    log_message 'INFO' 'Collecting package details'
    if check_and_run_remote_command "$1" "rpm" "rpm -qa | grep -E 'pacemaker|crmsh|resource.*agent|fence.*agent' | xargs -r rpm -qi" "$2/packages.txt"; then
        check_file "$2/packages.txt"
    fi
}

collect_selinux_info() {
    local node_ip="$1"
    local output_dir="$2"

    log_message 'INFO' 'Collecting: selinux-policy-sapenablement package status'
    if check_and_run_remote_command "${node_ip}" "zypper" "zypper se -s selinux-policy-sapenablement" "${output_dir}/zypper_se_selinux-policy-sapenablement.txt" "${LOG_FILE}"; then
        check_file "${output_dir}/zypper_se_selinux-policy-sapenablement.txt"
    fi

    if check_and_run_remote_command "${node_ip}" 'zypper' 'zypper info selinux-policy' "${output_dir}/zypper_info_selinux-policy.txt" "${LOG_FILE}"; then
        check_file "${output_dir}/zypper_info_selinux-policy.txt"
    fi

    log_message 'INFO' 'Collecting: semanage port list'
    if check_and_run_remote_command "${node_ip}" "semanage" "sudo semanage port -l" "${output_dir}/semanage_ports.txt" "${LOG_FILE}"; then
        check_file "${output_dir}/semanage_ports.txt"
    fi

    log_message 'INFO' 'Collecting: getenforce status'
    if check_and_run_remote_command "${node_ip}" "getenforce" "sudo getenforce" "${output_dir}/getenforce.txt" "${LOG_FILE}"; then
        check_file "${output_dir}/getenforce.txt"
    fi

    log_message 'INFO' 'Collecting: sestatus'
    if check_and_run_remote_command "${node_ip}" "sestatus" "sudo sestatus" "${output_dir}/sestatus.txt" "${LOG_FILE}"; then
        check_file "${output_dir}/sestatus.txt"
    fi

    log_message 'INFO' 'Collect list of AVC'
    if check_and_run_remote_command "${node_ip}" "ausearch" "timeout 5 sudo ausearch -ts boot -m avc,user_avc,selinux_err,user_selinux_err" "${output_dir}/ausearch.txt" "${LOG_FILE}"; then
        check_file "${output_dir}/ausearch.txt"
    fi

    log_message 'INFO' 'Collect auditallow'
    if check_and_run_remote_command "${node_ip}" "audit2allow" "timeout 5 sudo ausearch -ts today -m avc | audit2allow" "${output_dir}/audit2allow.txt" "${LOG_FILE}"; then
        check_file "${output_dir}/audit2allow.txt"
    fi

    log_message 'INFO' 'Collecting: SELinux denials from journalctl'
    if check_and_run_remote_command "${node_ip}" "journalctl" "sudo journalctl --boot | grep -E 'SELinux is preventing|setroubleshoot'" "${output_dir}/selinux_denials.log" "${LOG_FILE}"; then
        check_file "${output_dir}/selinux_denials.log"
    fi
}

collect_traces() {
    local node_ip=$1
    local output_dir=$2
    local trace_pattern=$3
    local output_file="$output_dir/${trace_pattern}_trace.log"

    log_message 'INFO' "Collecting ${trace_pattern} traces"
    local remote_command="sudo find /usr/sap/${SAP_SID}/HDB${INSTANCE_NUM}/ -name '${trace_pattern}_*.trc' -print0 | while IFS= read -r -d '' file; do echo -e \"\n\n=== \${file} ===\n\"; sudo tail -n 200 \"\${file}\"; done"
    if check_and_run_remote_command "${node_ip}" "find" "${remote_command}" "${output_file}"; then
        check_file "${output_file}"
    fi
}

collect_listening_ports() {
    local node_ip=$1
    local output_dir=$2
    local tool_name='ss'
    local remote_command='sudo ss -tlnp'
    local output_file="${output_dir}/ss_tlnp.txt"

    log_message 'INFO' 'Collecting: Listening Ports (ss -tlnp)'
    if check_and_run_remote_command "${node_ip}" "${tool_name}" "${remote_command}" "${output_file}" "${LOG_FILE}"; then
        check_file "${output_file}"
        return $? # Return the status of check_file
    else
        log_message 'ERROR' "Failed to collect listening ports on ${node_ip}."
        return 1
    fi
}

detect_hana_replication_port() {
    local node_ip=$1
    local output_dir=$2
    local ss_output_file="${output_dir}/ss_tlnp.txt"
    local detected_port=''

    if [[ -f $ss_output_file ]]; then
        # Try to find an external IP for hdbnameserver first, exclude 127.0.0.1 and 0.0.0.0
        detected_port=$(grep 'hdbnameserver' "$ss_output_file" | grep -v -E '127.0.0.1|0.0.0.0' | grep -oP ':\K\d+' | head -n 1)
        # If not found, try 0.0.0.0
        if [[ -z $detected_port ]]; then
            detected_port=$(grep -E 'hdbnameserver.*0.0.0.0' "$ss_output_file" | grep -oP ':\K\d+' | head -n 1)
        fi
        # If still not found, try localhost
        if [[ -z $detected_port ]]; then
            detected_port=$(grep -E 'hdbnameserver.*127.0.0.1' "$ss_output_file" | grep -oP ':\K\d+' | head -n 1)
        fi
        # If still not found, log an error, but don't echo anything to stdout for the variable assignment
        if [[ -z $detected_port ]]; then
            log_message 'ERROR' "Not possible to detect HANA replication port for $node_ip from $ss_output_file."
        fi
    else
        log_message 'ERROR' "Missing $ss_output_file for $node_ip. Cannot detect HANA replication port."
    fi

    echo "$detected_port" # Will be empty if port not found or file missing, preventing error messages from being assigned.
}

collect_stonith_info() {
    local node_ip=$1
    local output_dir=$2

    log_message 'INFO' 'Collecting pacemaker logs'
    if check_and_run_remote_command "${node_ip}" "journalctl" "sudo journalctl -u pacemaker --since '1 day ago'" "${output_dir}/pacemaker.log" "${LOG_FILE}"; then
        check_file "${output_dir}/pacemaker.log"
    fi

    log_message 'INFO' 'Collecting STONITH resource configuration'
    if check_and_run_remote_command "${node_ip}" "crm" "sudo crm configure show ${STONITH_RESOURCE}" "${output_dir}/stonith_resource.conf" "${LOG_FILE}"; then
        check_file "${output_dir}/stonith_resource.conf"
    fi

    log_message 'INFO' 'Collecting full cluster configuration'
    if check_and_run_remote_command "${node_ip}" "crm" "sudo crm configure show" "${output_dir}/cluster.conf" "${LOG_FILE}"; then
        check_file "${output_dir}/cluster.conf"
    fi
}

collect_hana_sr_manage_provider() {
    local node_ip="$1"
    local node_dir="$2"
    local provider
    local output_file
    local -a PROVIDERS=(
        'sushanasr'
        'suschksrv'
        'sustkover'
        'SAPHanaSR'
        'sushanasrmultitarget'
    )

    for provider in "${PROVIDERS[@]}"; do
        log_message 'INFO' "Collecting: SAPHanaSR-manageProvider --show --provider=${provider} on ${node_ip}"
        output_file="${node_dir}/SAPHanaSR-manageProvider_${provider}.txt"
        # shellcheck disable=SC2029
        if ssh "${SSH_USER}@${node_ip}" "sudo su - ${SAP_SID,,}adm -c \"/usr/bin/SAPHanaSR-manageProvider --show --provider=${provider}\"" >"$output_file" 2>>"$LOG_FILE"; then
            log_message 'SUCCESS' "Collected: $output_file"
        else
            log_message 'ERROR' "Failed to collect: $output_file"
        fi
    done
}

check_ssh_connectivity() {
    local node_ip="$1"
    log_message 'INFO' "Testing SSH connectivity to $node_ip (user: ${SSH_USER})"
    if ssh "${SSH_USER}@${node_ip}" "true" &>/dev/null; then
        log_message 'SUCCESS' "SSH connection to $node_ip successful."
        return 0
    else
        log_message 'ERROR' "SSH connection to $node_ip FAILED. Check credentials, firewalls, or SSH service."
        return 1
    fi
}

CONFIG_FILE=''
SAP_SID_OPT=''      # Option variable for SID
INSTANCE_NUM_OPT='' # Option variable for Instance Number
BASE_FOLDER=''

# Parse named arguments
while getopts 'b:c:s:n:' opt; do
    case ${opt} in
    b)
        BASE_FOLDER=$OPTARG
        ;;
    c)
        CONFIG_FILE=$OPTARG
        ;;
    s)
        SAP_SID_OPT=$OPTARG
        ;;
    n)
        INSTANCE_NUM_OPT=$OPTARG
        ;;
    \?)
        log_message 'ERROR' 'Invalid option.'
        echo "Usage: $0 [-b <BASE_FOLDER>] [-c <CONFIG_FILE>] [-s <SAP_SID>] [-n <INSTANCE_NUM>] <PRIMARY_IP> <SECONDARY_IP>" | tee -a "$LOG_FILE"
        exit 1
        ;;
    esac
done
shift $((OPTIND - 1)) # Remove named arguments from the positional parameter list

# Capture positional arguments
PRIMARY_IP_POS="$1"
SECONDARY_IP_POS="$2"

# Initialize final variables with values from options/positional arguments
PRIMARY_IP="$PRIMARY_IP_POS"
SECONDARY_IP="$SECONDARY_IP_POS"
SAP_SID="$SAP_SID_OPT"
INSTANCE_NUM="$INSTANCE_NUM_OPT"
LOG_FILE='/dev/stdout' # Temporary before to have the log folder

# Process -b and -c first to potentially override PRIMARY_IP and SECONDARY_IP from inventory
if [[ -n $BASE_FOLDER && -n $CONFIG_FILE ]]; then
    # Validate BASE_FOLDER
    if [[ ! -d $BASE_FOLDER ]]; then
        log_message 'ERROR' "Base folder '$BASE_FOLDER' not found or is not a directory."
        exit 1
    fi

    if [[ $CONFIG_FILE != /* ]]; then
        log_message 'ERROR' "Config file path '$CONFIG_FILE' must be an absolute path."
        exit 1
    fi
    if [[ ! -f $CONFIG_FILE ]]; then
        log_message 'ERROR' "Config file '$CONFIG_FILE' not found."
        exit 1
    fi
    if [[ ! -r $CONFIG_FILE ]]; then
        log_message 'ERROR' "Config file '$CONFIG_FILE' is not readable."
        exit 1
    fi

    log_message 'INFO' "Parsing config file for provider: $CONFIG_FILE"
    read -r -a config_data <<<"$(parse_config_file "$CONFIG_FILE")"
    provider_val="${config_data[2]}" # Provider is the third element

    if [[ -z $provider_val ]]; then
        log_message 'ERROR' "Could not determine provider from config file: $CONFIG_FILE"
        exit 1
    fi

    INVENTORY_PATH="${BASE_FOLDER}/terraform/${provider_val}/inventory.yaml"
    log_message 'INFO' "Constructed inventory path: $INVENTORY_PATH"

    if [[ ! -f $INVENTORY_PATH ]]; then
        log_message 'ERROR' "Inventory file not found at $INVENTORY_PATH"
        exit 1
    fi
    if [[ ! -r $INVENTORY_PATH ]]; then
        log_message 'ERROR' "Inventory file '$INVENTORY_PATH' is not readable."
        exit 1
    fi

    log_message 'INFO' "Parsing inventory file for IPs: $INVENTORY_PATH"
    read -r inv_primary_ip inv_secondary_ip inv_ssh_user <<<"$(parse_inventory_file "$INVENTORY_PATH")"

    if [[ -z $inv_primary_ip || -z $inv_secondary_ip ]]; then
        log_message 'ERROR' "Could not extract primary and/or secondary IPs from inventory file: $INVENTORY_PATH. Cannot proceed."
        exit 1
    fi

    PRIMARY_IP="$inv_primary_ip"
    SECONDARY_IP="$inv_secondary_ip"
    SSH_USER="$inv_ssh_user" # Override SSH_USER with value from inventory
    log_message 'INFO' "Primary IP overridden from inventory: $PRIMARY_IP"
    log_message 'INFO' "Secondary IP overridden from inventory: $SECONDARY_IP"
    log_message 'INFO' "SSH user overridden from inventory: $SSH_USER"
fi

if [[ -n $CONFIG_FILE ]]; then
    # Validate CONFIG_FILE (already done above if -b also present, but re-validate for -c only case)
    if [[ $CONFIG_FILE != /* ]]; then
        log_message 'ERROR' "Config file path '$CONFIG_FILE' must be an absolute path."
        exit 1
    fi
    if [[ ! -f $CONFIG_FILE ]]; then
        log_message 'ERROR' "Config file '$CONFIG_FILE' not found."
        exit 1
    fi
    if [[ ! -r $CONFIG_FILE ]]; then
        log_message 'ERROR' "Config file '$CONFIG_FILE' is not readable."
        exit 1
    fi

    log_message 'INFO' "Parsing config file for SID and Instance Number: $CONFIG_FILE"
    read -r config_sid config_instance_num _ <<<"$(parse_config_file "$CONFIG_FILE")"
    if [[ -n $config_sid ]]; then
        SAP_SID="$config_sid"
        log_message 'INFO' "SAP_SID overridden from config file: $SAP_SID"
    fi
    if [[ -n $config_instance_num ]]; then
        INSTANCE_NUM="$config_instance_num"
        log_message 'INFO' "INSTANCE_NUM overridden from config file: $INSTANCE_NUM"
    fi
fi

# Final mandatory checks for PRIMARY_IP, SECONDARY_IP, SAP_SID, INSTANCE_NUM
if [[ -z $PRIMARY_IP || -z $SECONDARY_IP ]]; then
    log_message 'ERROR' "Missing mandatory IP arguments. IPs must be provided either as positional arguments or derived from the inventory file when -b and -c are used."
    echo "Usage: $0 [-b <BASE_FOLDER>] [-c <CONFIG_FILE>] [-s <SAP_SID>] [-n <INSTANCE_NUM>] <PRIMARY_IP> <SECONDARY_IP>" | tee -a "$LOG_FILE"
    exit 1
fi

if [[ -z $SAP_SID || -z $INSTANCE_NUM ]]; then
    log_message 'ERROR' "SAP_SID and INSTANCE_NUM must be provided either via -s/-n flags or in the config file when -c is used."
    echo "Usage: $0 [-b <BASE_FOLDER>] [-c <CONFIG_FILE>] [-s <SAP_SID>] [-n <INSTANCE_NUM>] <PRIMARY_IP> <SECONDARY_IP>" | tee -a "$LOG_FILE"
    exit 1
fi

print_header 'Performing initial connectivity checks'
check_ssh_connectivity "${PRIMARY_IP}" || exit 1
check_ssh_connectivity "${SECONDARY_IP}" || exit 1

HANA_REPLICATION_PORT="3${INSTANCE_NUM}15"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
REPORT_DIR="hana_sr_diag_${TIMESTAMP}"
PRIMARY_DIR="${REPORT_DIR}/primary_${PRIMARY_IP}"
SECONDARY_DIR="${REPORT_DIR}/secondary_${SECONDARY_IP}"

log_message 'INFO' "Creating report directory: ${REPORT_DIR}"
mkdir -p "$PRIMARY_DIR" "$SECONDARY_DIR"
LOG_FILE="${REPORT_DIR}/collection.log" # Re-assign LOG_FILE to the actual file
log_message 'INFO' "Logging to: $LOG_FILE"

log_message 'INFO' "Collecting system info"
collect_system_info "${PRIMARY_IP}" "${PRIMARY_DIR}"
collect_listening_ports "${PRIMARY_IP}" "${PRIMARY_DIR}" || log_message "WARNING" "Could not collect listening ports for primary node. HANA replication port detection might be affected."
collect_firewall_rules "${PRIMARY_IP}" "${PRIMARY_DIR}/firewall.txt"
collect_selinux_info "${PRIMARY_IP}" "${PRIMARY_DIR}"

log_message 'INFO' 'Collecting: crm_mon -1r'
if check_and_run_remote_command "${PRIMARY_IP}" "crm_mon" "sudo crm_mon -1r" "${PRIMARY_DIR}/crm_mon.txt" "${LOG_FILE}"; then
    check_file "${PRIMARY_DIR}/crm_mon.txt"
fi

# Collect initial cluster status from primary
log_message 'INFO' 'Collecting: crm status'
if check_and_run_remote_command "${PRIMARY_IP}" "crm" "sudo crm status" "${PRIMARY_DIR}/crm_status.txt" "${LOG_FILE}"; then
    check_file "${PRIMARY_DIR}/crm_status.txt"
fi

collect_hdbnsutil_command "${PRIMARY_IP}" "${PRIMARY_DIR}" "-sr_state" "hdbnsutil_sr_state.txt"
collect_hdbsettings_script "${PRIMARY_IP}" "${PRIMARY_DIR}" "landscapeHostConfiguration.py"
collect_hdbnsutil_command "${PRIMARY_IP}" "${PRIMARY_DIR}" "-sr_stateConfiguration" "hdbnsutil_sr_stateConfiguration.txt"
collect_hdbsettings_script "${PRIMARY_IP}" "${PRIMARY_DIR}" "systemReplicationStatus.py"
collect_traces "${PRIMARY_IP}" "${PRIMARY_DIR}" "nameserver"
collect_traces "${PRIMARY_IP}" "${PRIMARY_DIR}" "indexserver"

print_header "Collecting data from SECONDARY node: ${SECONDARY_IP}"
collect_system_info "${SECONDARY_IP}" "${SECONDARY_DIR}"
collect_firewall_rules "${SECONDARY_IP}" "${SECONDARY_DIR}/firewall.txt"
collect_selinux_info "${SECONDARY_IP}" "${SECONDARY_DIR}"
collect_traces "${SECONDARY_IP}" "${SECONDARY_DIR}" "nameserver"
collect_traces "${SECONDARY_IP}" "${SECONDARY_DIR}" "indexserver"
collect_listening_ports "${SECONDARY_IP}" "${SECONDARY_DIR}" || log_message "WARNING" "Could not collect listening ports for secondary node. HANA replication port detection might be affected."

log_message 'INFO' 'Collecting: crm_mon -1r'
if check_and_run_remote_command "${SECONDARY_IP}" "crm_mon" "sudo crm_mon -1r" "${SECONDARY_DIR}/crm_mon.txt" "${LOG_FILE}"; then
    check_file "${SECONDARY_DIR}/crm_mon.txt"
fi

log_message 'INFO' 'Collecting: SAPHanaSR-showAttr'
if check_and_run_remote_command "${SECONDARY_IP}" "SAPHanaSR-showAttr" "sudo SAPHanaSR-showAttr" "${SECONDARY_DIR}/SAPHanaSR-showAttr.txt" "${LOG_FILE}"; then
    check_file "${SECONDARY_DIR}/SAPHanaSR-showAttr.txt"
fi

collect_hdbnsutil_command "${SECONDARY_IP}" "${SECONDARY_DIR}" "-sr_state" "hdbnsutil_sr_state.txt"
collect_hdbsettings_script "${SECONDARY_IP}" "${SECONDARY_DIR}" "landscapeHostConfiguration.py"
collect_hdbnsutil_command "${SECONDARY_IP}" "${SECONDARY_DIR}" "-sr_stateConfiguration" "hdbnsutil_sr_stateConfiguration.txt"

collect_hdbsettings_script "${SECONDARY_IP}" "${SECONDARY_DIR}" "systemReplicationStatus.py"

# Collect SAPHanaSR-manageProvider output for all providers
print_header "Collecting SAPHanaSR-manageProvider output for various providers"
collect_hana_sr_manage_provider "${PRIMARY_IP}" "${PRIMARY_DIR}"
collect_hana_sr_manage_provider "${SECONDARY_IP}" "${SECONDARY_DIR}"

log_message 'INFO' 'Collecting: global.ini'
if check_and_run_remote_command "${SECONDARY_IP}" "cat" "sudo cat /usr/sap/${SAP_SID}/SYS/global/hdb/custom/config/global.ini" "${SECONDARY_DIR}/global.ini" "${LOG_FILE}"; then
    check_file "${SECONDARY_DIR}/global.ini"
fi

log_message 'INFO' 'Collecting: nameserver.ini'
if check_and_run_remote_command "${SECONDARY_IP}" "cat" "sudo cat /usr/sap/${SAP_SID}/SYS/global/hdb/custom/config/nameserver.ini" "${SECONDARY_DIR}/nameserver.ini" "${LOG_FILE}"; then
    check_file "${SECONDARY_DIR}/nameserver.ini"
fi
log_message 'INFO' 'Collecting: nameserver.ini'
if check_and_run_remote_command "${PRIMARY_IP}" "cat" "sudo cat /usr/sap/${SAP_SID}/SYS/global/hdb/custom/config/nameserver.ini" "${PRIMARY_DIR}/nameserver.ini" "${LOG_FILE}"; then
    check_file "${PRIMARY_DIR}/nameserver.ini"
fi

# Perform Network Tests between Nodes
print_header "Performing network tests between nodes"
log_message 'INFO' 'Getting internal IPs'
PRIMARY_INTERNAL_IP=$(ssh "${SSH_USER}@${PRIMARY_IP}" "ip -4 addr show scope global | grep inet | awk '{print \$2}' | cut -d / -f 1 | head -n 1")
SECONDARY_INTERNAL_IP=$(ssh "${SSH_USER}@${SECONDARY_IP}" "ip -4 addr show scope global | grep inet | awk '{print \$2}' | cut -d / -f 1 | head -n 1")
log_message 'INFO' "Primary internal IP: ${PRIMARY_INTERNAL_IP}"
log_message 'INFO' "Secondary internal IP: ${SECONDARY_INTERNAL_IP}"

print_header 'Performing network tests from PRIMARY to SECONDARY'
log_message 'INFO' "Running: ping -c 5 ${SECONDARY_INTERNAL_IP}"
if check_and_run_remote_command "${PRIMARY_IP}" "ping" "ping -c 5 ${SECONDARY_INTERNAL_IP}" "${REPORT_DIR}/ping_primary_to_secondary.txt" "${LOG_FILE}"; then
    check_file "${REPORT_DIR}/ping_primary_to_secondary.txt"
fi

log_message 'INFO' "Running: traceroute ${SECONDARY_INTERNAL_IP}"
if check_and_run_remote_command "${PRIMARY_IP}" "traceroute" "sudo traceroute ${SECONDARY_INTERNAL_IP}" "${REPORT_DIR}/traceroute_primary_to_secondary.txt" "${LOG_FILE}"; then
    check_file "${REPORT_DIR}/traceroute_primary_to_secondary.txt"
fi

SECONDARY_HANA_PORT=$(detect_hana_replication_port "${SECONDARY_IP}" "${SECONDARY_DIR}")
if [[ -z $SECONDARY_HANA_PORT ]]; then
    log_message 'WARNING' "Could not detect HANA replication port for secondary. Using default: ${HANA_REPLICATION_PORT}"
    SECONDARY_HANA_PORT="${HANA_REPLICATION_PORT}"
fi

if [[ -n $SECONDARY_HANA_PORT ]]; then
    log_message 'INFO' "Running: nc -zv -w 5 ${SECONDARY_INTERNAL_IP} ${SECONDARY_HANA_PORT}"
    if check_and_run_remote_command "${PRIMARY_IP}" "nc" "nc -zv -w 5 ${SECONDARY_INTERNAL_IP} ${SECONDARY_HANA_PORT}" "${REPORT_DIR}/netcat_primary_to_secondary.txt" "${LOG_FILE}"; then
        check_file "${REPORT_DIR}/netcat_primary_to_secondary.txt"
    fi
else
    log_message 'WARNING' "Skipping netcat from primary to secondary as HANA replication port is empty."
fi

print_header 'Performing network tests from SECONDARY to PRIMARY'
log_message 'INFO' "Running: ping -c 5 ${PRIMARY_INTERNAL_IP}"
if check_and_run_remote_command "${SECONDARY_IP}" "ping" "ping -c 5 ${PRIMARY_INTERNAL_IP}" "${REPORT_DIR}/ping_secondary_to_primary.txt" "${LOG_FILE}"; then
    check_file "${REPORT_DIR}/ping_secondary_to_primary.txt"
fi

log_message 'INFO' "Running: traceroute ${PRIMARY_INTERNAL_IP}"
if check_and_run_remote_command "${SECONDARY_IP}" "traceroute" "traceroute ${PRIMARY_INTERNAL_IP}" "${REPORT_DIR}/traceroute_secondary_to_primary.txt" "${LOG_FILE}"; then
    check_file "${REPORT_DIR}/traceroute_secondary_to_primary.txt"
fi

PRIMARY_HANA_PORT=$(detect_hana_replication_port "${PRIMARY_IP}" "${PRIMARY_DIR}")
if [[ -z $PRIMARY_HANA_PORT ]]; then
    log_message 'WARNING' "Could not detect HANA replication port for primary. Using default: ${HANA_REPLICATION_PORT}"
    PRIMARY_HANA_PORT="${HANA_REPLICATION_PORT}"
fi

if [[ -n $PRIMARY_HANA_PORT ]]; then
    log_message 'INFO' "Running: nc -zv -w 5 ${PRIMARY_INTERNAL_IP} ${PRIMARY_HANA_PORT}"
    if check_and_run_remote_command "${SECONDARY_IP}" "nc" "nc -zv -w 5 ${PRIMARY_INTERNAL_IP} ${PRIMARY_HANA_PORT}" "${REPORT_DIR}/netcat_secondary_to_primary.txt" "${LOG_FILE}"; then
        check_file "${REPORT_DIR}/netcat_secondary_to_primary.txt"
    fi
else
    log_message 'WARNING' 'Skipping netcat from secondary to primary as HANA replication port is empty.'
fi

# Finalizing
print_header 'Packaging results'
tar -czvf "${REPORT_DIR}.tar.gz" "$REPORT_DIR"
log_message 'INFO' "All diagnostic data has been collected and packaged into ${REPORT_DIR}.tar.gz"
log_message 'INFO' "You can now inspect the files in the '${REPORT_DIR}' directory."
log_message 'INFO' 'Done.'
