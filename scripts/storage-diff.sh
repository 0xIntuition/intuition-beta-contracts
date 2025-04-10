#!/bin/bash

# Default values
RPC_URL=""
BASESCAN_API_KEY=""
INPUT_FILE="scripts/json/contracts.json"
QUIET=false
TOTAL_ISSUES=0
TOTAL_ERRORS=0
TOTAL_ERRORS_NEW_IMPLEMENTATION=0
TOTAL_OTHER_ERRORS=0
NEW_IMPLEMENTATION=false
LOCAL_IMPLEMENTATION=false
CONTRACT_ADDRESSES=()
NEW_IMPLEMENTATION_ADDRESSES=()
TOTAL_CONTRACTS_NO_NEW_IMPLEMENTATION=0

# Load environment variables from .env file if it exists
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
    RPC_URL=${BASE_RPC_URL:-$RPC_URL}
    BASESCAN_API_KEY=${BASESCAN_API_KEY:-$BASESCAN_API_KEY}
fi

# Help message
usage() {
    cat << EOF
Usage: bash $0 --rpc-url $RPC_URL --etherscan-key $BASESCAN_API_KEY --input $INPUT_FILE [--quiet] [--help]

Detects storage layout incompatibilities that could cause issues during upgrades.

Required:
    -r, --rpc-url <url>         RPC endpoint URL for the target network (default: .env BASE_RPC_URL).
    -e, --etherscan-key <key>   API key for Basescan to fetch contract data. (default: .env BASESCAN_API_KEY).

Options:
    -i, --input <file>          JSON file containing contract details, see format below (default: scripts/json/contracts.json).
                                If not provided, reads from stdin.
    -n, --new-implementation    Only compare the new implementation to the on-chain implementation.
    -l, --local-implementation  Only compare the local implementation to the on-chain implementation.
    -q, --quiet                 Suppress informational output.
    -h, --help                  Show this help message.

Input JSON format:
{
  "contracts": [
    {
      "name": "EthMultiVault",
      "address": "0x430BbF52503Bd4801E51182f4cB9f8F534225DE5",
      "new_implementation_address": "0x7499bFa918DBc73Ace4A05D6194a5Cd343AE32Dd" # Optional
    },
  ]
}
EOF
    exit 1
}

# Process command line arguments using a while loop and case statement.
while [[ $# -gt 0 ]]; do
    case $1 in
        -r|--rpc-url)
            RPC_URL="$2"
            shift 2
            ;;
        -e|--etherscan-key)
            BASESCAN_API_KEY="$2"
            shift 2
            ;;
        -i|--input)
            INPUT_FILE="$2"
            shift 2
            ;;
        -q|--quiet)
            QUIET=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        -n|--new-implementation)
            NEW_IMPLEMENTATION=true
            shift
            ;;
        -l|--local-implementation)
            LOCAL_IMPLEMENTATION=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            usage
            ;;
    esac
done

# Validate required arguments
if [ -z "$RPC_URL" ] || [ -z "$BASESCAN_API_KEY" ]; then
    echo "Error: RPC URL and Basescan API key are required"
    usage
fi

# Read JSON input
if [ -n "$INPUT_FILE" ]; then
    if [ ! -f "$INPUT_FILE" ]; then
        echo "Error: Input file not found: $INPUT_FILE"
        exit 1
    fi
    json_input=$(cat "$INPUT_FILE")
else
    json_input=$(cat)
fi

# Parse JSON values using jq
CONTRACTS=$(echo "$json_input" | jq -c '.contracts[]')

# Verify contracts are specified
if [ -z "$CONTRACTS" ]; then
    echo "Error: No contracts specified in JSON input"
    exit 1
fi

# Function to calculate number of slots a variable type occupies
calculate_slots() {
    local var_type=$1

    # Handle basic types
    case $var_type in
        *"uint256"*|*"int256"*|*"bytes32"*|*"address"*)
            echo 1
            ;;
        *"mapping"*)
            echo 1  # Mappings use 1 slot for the starting position
            ;;
        *"bytes"*|*"string"*)
            echo 1  # Dynamic types use 1 slot for length/pointer
            ;;
        *"array"*)
            echo 1  # Arrays use 1 slot for length/pointer, need to figure out how to parse slots consumed.
            ;;
        *)
            # Default to 1 slot if unknown
            echo 1
            ;;
    esac
}

# Function to analyze storage changes
analyze_storage_changes() {
    local onchain_file=$1
    local local_file=$2
    local contract_name=$3
    local TOTAL_ERRORS=0  # Changed from issues_found to TOTAL_ERRORS
    local warnings_found=0  # New counter for non-critical changes

    # Get the storage layouts as arrays
    local onchain_slots=$(jq -r '.storage[] | "\(.slot)|\(.label)|\(.offset)|\(.type)"' "$onchain_file")
    local local_slots=$(jq -r '.storage[] | "\(.slot)|\(.label)|\(.offset)|\(.type)"' "$local_file")

    echo "Storage Layout Analysis for $contract_name:"
    echo "----------------------------------------"

    # Create temporary files for our data structures
    local onchain_map_file=$(mktemp)
    local local_map_file=$(mktemp)
    local processed_slots_file=$(mktemp)
    local renamed_vars_file=$(mktemp)

    # Parse onchain slots
    echo "$onchain_slots" | while IFS='|' read -r slot label offset type; do
        if [[ -n "$slot" ]]; then
            echo "${slot}|${label}|${offset}|${type}" >> "$onchain_map_file"
        fi
    done

    # Parse local slots
    echo "$local_slots" | while IFS='|' read -r slot label offset type; do
        if [[ -n "$slot" ]]; then
            echo "${slot}|${label}|${offset}|${type}" >> "$local_map_file"
        fi
    done

    # First pass: Check for renames (same slot, same type, different name)
    while IFS='|' read -r slot local_label local_offset local_type; do
        if [[ -z "$slot" ]]; then continue; fi

        onchain_line=$(grep "^${slot}|" "$onchain_map_file")
        if [[ -n "$onchain_line" ]]; then
            IFS='|' read -r _ onchain_label onchain_offset onchain_type <<< "$onchain_line"

            if [[ "$local_label" != "$onchain_label" && "$local_type" == "$onchain_type" && "$local_offset" == "$onchain_offset" ]]; then
                echo "${slot}|${onchain_label}|${local_label}|${local_type}" >> "$renamed_vars_file"
                echo "$slot" >> "$processed_slots_file"
                warnings_found=$((warnings_found + 1))  # Renames are just warnings
            fi
        fi
    done < "$local_map_file"

    # Print renames first
    while IFS='|' read -r slot old_name new_name type; do
        if [[ -n "$slot" ]]; then
            echo -e "\033[36m📝 Variable renamed at slot $slot:\033[0m"
            echo -e "\033[36m   $old_name -> $new_name ($type)\033[0m"
        fi
    done < "$renamed_vars_file"

    # Analyze other differences
    while IFS='|' read -r slot local_label local_offset local_type; do
        if [[ -z "$slot" ]]; then continue; fi

        if grep -q "^${slot}$" "$processed_slots_file"; then
            continue
        fi

        onchain_line=$(grep "^${slot}|" "$onchain_map_file")
        if [[ -z "$onchain_line" ]]; then
            # New variable added - just a warning
            slots_needed=$(calculate_slots "$local_type")
            echo -e "\033[32m✨ New variable added: $local_label ($local_type) at slot $slot\033[0m"
            warnings_found=$((warnings_found + 1))
            if [ "$slots_needed" -gt 1 ]; then
                echo -e "\033[33m   📦 This variable occupies $slots_needed slots\033[0m"
            fi
        else
            IFS='|' read -r _ onchain_label onchain_offset onchain_type <<< "$onchain_line"

            if [[ "$local_label" != "$onchain_label" ]]; then
                # Only treat as critical error if we're not overriding a gap variable
                if [[ "$onchain_label" != "__gap" ]]; then
                    # Storage slot override is a critical error
                    echo -e "\033[31m🚨 CRITICAL: Storage slot override detected at slot $slot:\033[0m"
                    echo -e "\033[31m   Previous: $onchain_label ($onchain_type)\033[0m"
                    echo -e "\033[32m   New: $local_label ($local_type)\033[0m"
                    TOTAL_ERRORS=$((TOTAL_ERRORS + 1))

                    old_slots=$(calculate_slots "$onchain_type")
                    new_slots=$(calculate_slots "$local_type")
                    slot_diff=$((new_slots - old_slots))

                    if [ "$slot_diff" -gt 0 ]; then
                        echo -e "\033[31m   ⚠️ CRITICAL: This change will shift subsequent storage slots by +$slot_diff positions\033[0m"
                    elif [ "$slot_diff" -lt 0 ]; then
                        echo -e "\033[31m   ⚠️ CRITICAL: This change will shift subsequent storage slots by $slot_diff positions\033[0m"
                    fi
                else
                    # Just a warning for gap overrides
                    echo -e "\033[33m📝 Gap variable override at slot $slot:\033[0m"
                    echo -e "\033[33m   Previous: $onchain_label ($onchain_type)\033[0m"
                    echo -e "\033[33m   New: $local_label ($local_type)\033[0m"
                    warnings_found=$((warnings_found + 1))
                fi
            elif [[ "$local_type" != "$onchain_type" ]]; then
                # Type changes are critical errors
                echo -e "\033[31m🔄 CRITICAL: Type change detected for $local_label at slot $slot:\033[0m"
                echo -e "\033[31m   Previous: $onchain_type\033[0m"
                echo -e "\033[31m   New: $local_type\033[0m"
                TOTAL_ERRORS=$((TOTAL_ERRORS + 1))
            fi
        fi
        echo "$slot" >> "$processed_slots_file"
    done < "$local_map_file"

    # Check for removed variables
    while IFS='|' read -r slot onchain_label onchain_offset onchain_type; do
        if [[ -z "$slot" ]]; then continue; fi

        if grep -q "^${slot}$" "$processed_slots_file"; then
            continue
        fi

        if ! grep -q "^${slot}|" "$local_map_file"; then
            # Variable removal is a critical error
            echo -e "\033[31m➖ CRITICAL: Variable removed: $onchain_label ($onchain_type) from slot $slot\033[0m"
            TOTAL_ERRORS=$((TOTAL_ERRORS + 1))
        fi
    done < "$onchain_map_file"

    # Cleanup temporary files
    rm -f "$onchain_map_file" "$local_map_file" "$processed_slots_file" "$renamed_vars_file"

    if [ "$TOTAL_ERRORS" -gt 0 ]; then
        echo -e "\033[31mCritical storage layout errors found in $contract_name: $TOTAL_ERRORS\033[0m"
    else
        echo -e "\033[32mNo critical storage layout errors in $contract_name\033[0m"
    fi
    if [ "$warnings_found" -gt 0 ]; then
        echo "Non-critical changes found: $warnings_found"
    fi
    
    return $TOTAL_ERRORS  # Only return critical errors
}

# Function to process a single contract
process_contract() {
    local contract_name=$1
    local contract_address=$2
    local new_implementation_address=$3
    local issues_found=0

    # Create directories for storing layouts and diffs
    mkdir -p "storage-report/layouts" "storage-report/diffs"
    local local_file="storage-report/layouts/${contract_name}_local.json"
    local onchain_file="storage-report/layouts/${contract_name}_onchain.json"
    local new_implementation_file="storage-report/layouts/${contract_name}_new_implementation.json"

    local diff_file="storage-report/diffs/${contract_name}.diff"
    local diff_new_implementation_file="storage-report/diffs/${contract_name}_new_implementation.diff"
  

    # Generate storage layouts
    if ! forge inspect "$contract_name" storage --json > "$local_file" 2>/dev/null; then
        echo "Error: forge inspect failed for contract: $contract_name"
        TOTAL_OTHER_ERRORS=$((TOTAL_OTHER_ERRORS + 1))
        return 1
    fi

    if ! cast storage "$contract_address" --rpc-url "$RPC_URL" --etherscan-api-key "$BASESCAN_API_KEY" --json > "$onchain_file" 2>/dev/null; then
        echo "Error: cast storage failed for address: $contract_address"
        TOTAL_OTHER_ERRORS=$((TOTAL_OTHER_ERRORS + 1))
        return 1
    fi

    # Only process new implementation if address is provided
    if [ "$new_implementation_address" != "null" ]; then
  
        if ! cast storage "$new_implementation_address" --rpc-url "$RPC_URL" --etherscan-api-key "$BASESCAN_API_KEY" --json > "$new_implementation_file" 2>/dev/null; then
            echo "Error: cast storage failed for address: $new_implementation_address"
            TOTAL_OTHER_ERRORS=$((TOTAL_OTHER_ERRORS + 1))
            return 1
        fi
    fi

    # Delete the first line of $onchain_file
    sed '1d' "$onchain_file" > "$onchain_file.tmp" && mv "$onchain_file.tmp" "$onchain_file" 

    # Filter out astId and contract fields from local and onchain files, and normalize type identifiers
    jq 'del(.types, .values, .storage[].astId, .storage[].contract) | .storage[].type |= gsub("\\([^)]+\\)[0-9]+"; "")' "$local_file" > "${local_file}.tmp" && mv "${local_file}.tmp" "$local_file"
    jq 'del(.types, .values, .storage[].astId, .storage[].contract) | .storage[].type |= gsub("\\([^)]+\\)[0-9]+"; "")' "$onchain_file" > "${onchain_file}.tmp" && mv "${onchain_file}.tmp" "$onchain_file"
    
    if [ "$new_implementation_address" != "null" ]; then
        jq 'del(.types, .values, .storage[].astId, .storage[].contract) | .storage[].type |= gsub("\\([^)]+\\)[0-9]+"; "")' "$new_implementation_file" > "${new_implementation_file}.tmp" && mv "${new_implementation_file}.tmp" "$new_implementation_file"
    fi

    if [ "$QUIET" = false ]; then
        echo "----------------------------------------"
        echo "Local contract:  $contract_name"
        echo "Chain address:   $contract_address"
        if [ "$new_implementation_address" != "null" ]; then
            echo "New implementation address:   $new_implementation_address"
        fi
        echo "Network RPC:     $RPC_URL"
        echo "JSON files stored in: storage-report/layouts/"
        echo "Diffs stored in: storage-report/diffs/"
        echo "----------------------------------------"
    fi

    # Generate and store diff
    diff -u "$onchain_file" "$local_file" > "$diff_file" 2>/dev/null || true
    
    if [ "$new_implementation_address" != "null" ]; then
        diff -u "$new_implementation_file" "$local_file" > "$diff_new_implementation_file" 2>/dev/null || true
    fi
    
    # Analyze storage changes
    echo "----------------------------------------"
    echo "Analyzing local implementation"
    analyze_storage_changes "$onchain_file" "$local_file" "$contract_name"
    issues_found=$?
    TOTAL_ERRORS=$((TOTAL_ERRORS + issues_found))

    if [ "$new_implementation_address" != "null" ]; then
        issues_found=0
        echo "----------------------------------------"
        echo "Analyzing new implementation: $new_implementation_address"
        analyze_storage_changes "$onchain_file" "$new_implementation_file" "$contract_name"
        issues_found=$?
        TOTAL_ERRORS_NEW_IMPLEMENTATION=$((TOTAL_ERRORS_NEW_IMPLEMENTATION + issues_found))
    fi

    return $issues_found
}

# Process each contract from the JSON input
while IFS= read -r contract; do
    contract_name=$(echo "$contract" | jq -r '.name')
    contract_address=$(echo "$contract" | jq -r '.address')
    new_implementation_address=$(echo "$contract" | jq -r '.new_implementation_address')

    if [ -z "$contract_name" ] || [ -z "$contract_address" ]; then
        echo "Error: Each contract must specify both name and address"
        TOTAL_OTHER_ERRORS=$((TOTAL_OTHER_ERRORS + 1))
        continue
    fi

    if [ "$NEW_IMPLEMENTATION" = true ] && [ "$new_implementation_address" == "null" ]; then
        echo "Error: Each contract must specify new_implementation_address when using --new-implementation flag"
        TOTAL_OTHER_ERRORS=$((TOTAL_OTHER_ERRORS + 1))
        continue
    fi

    # Store addresses for later printing
    if [ "$new_implementation_address" != "null" ]; then
        CONTRACT_ADDRESSES+=("$contract_address")
        NEW_IMPLEMENTATION_ADDRESSES+=("$new_implementation_address")
    else
        TOTAL_CONTRACTS_NO_NEW_IMPLEMENTATION=$((TOTAL_CONTRACTS_NO_NEW_IMPLEMENTATION + 1))
    fi

    if [ "$QUIET" = false ]; then
        echo "Processing contract: $contract_name at $contract_address"
    fi
    process_contract "$contract_name" "$contract_address" "$new_implementation_address"
    TOTAL_ISSUES=$((TOTAL_ISSUES + $?))
done <<< "$CONTRACTS"

EXIT_CODE=0
if [ "$TOTAL_OTHER_ERRORS" -gt 0 ]; then
    echo -e "\n\033[31m🚨 Total other errors found: $TOTAL_OTHER_ERRORS\033[0m"
    EXIT_CODE=1
fi

if [ "$TOTAL_ERRORS" -gt 0 ]; then
    echo -e "\n\033[31m🚨 Total critical storage layout errors found: $TOTAL_ERRORS\033[0m"
    EXIT_CODE=1
else
    echo -e "\n\033[32m✅ No critical storage layout errors found\033[0m"
fi

if [ "$TOTAL_ERRORS_NEW_IMPLEMENTATION" -gt 0 ]; then
    echo -e "\n\033[31m🚨 Total critical storage layout errors found in new implementation: $TOTAL_ERRORS_NEW_IMPLEMENTATION\033[0m"
    EXIT_CODE=1
else
    echo -e "\n\033[32m✅ No critical storage layout errors found in new implementation\033[0m"
fi

exit $EXIT_CODE