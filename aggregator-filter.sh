#!/bin/bash
set -euo pipefail

# Constants
RAW_CONFIGS_URL="https://raw.githubusercontent.com/mahdibland/V2RayAggregator/master/sub/splitted/vmess.txt"

# Setup environment
SCRIPT_DIR="$(pwd)"
OUTPUT_DIR="${SCRIPT_DIR}/processed_config"
RAW_CONFIGS_FILE="${SCRIPT_DIR}/raw_configs.txt"
VMESS_CF_CONFIGS_FILE="${OUTPUT_DIR}/vmess_cf_configs.txt"
VMESS_CONFIGS_FILE="${OUTPUT_DIR}/vmess_configs.txt"

# Function to URL encode a string
urlencode() {
    local string="${1}"
    local strlen=${#string}
    local encoded=""
    local pos c o
    for (( pos=0 ; pos<strlen ; pos++ )); do
        c=${string:$pos:1}
        case "$c" in
            [-_.~a-zA-Z0-9] ) o="${c}" ;;
            * )               printf -v o '%%%02x' "'$c"
        esac
        encoded+="${o}"
    done
    echo "${encoded}"
}

# Create dirs
mkdir -p "${OUTPUT_DIR}"

# Download the latest subscriptions config
echo "Downloading raw configs..."
curl -sS "${RAW_CONFIGS_URL}" -o "${RAW_CONFIGS_FILE}"

# Process configs
echo "Processing configs..."
non_cf_count=1
cf_count=1

# Setup files
rm -f "${VMESS_CF_CONFIGS_FILE}"
rm -f "${VMESS_CONFIGS_FILE}"
touch "${VMESS_CF_CONFIGS_FILE}"
touch "${VMESS_CONFIGS_FILE}"

while IFS= read -r line; do
    echo "Processing config: ${line}"
    
    # Process the config
    decoded=$(echo "${line}" | sed 's/vmess:\/\///g' | base64 -d)
    
    # Check if it's a Cloudflare config
    if echo "${decoded}" | jq -r '.ps' | grep -q "🏁RELAY"; then
        processed=$(echo "${decoded}" | jq --arg count "${cf_count}" '.ps = "vmess-cf-" + $count')
        encoded=$(echo "${processed}" | base64 -w 0)
        echo "vmess://${encoded}" >> "${VMESS_CF_CONFIGS_FILE}"
        cf_count=$((cf_count + 1))
    else
        processed=$(echo "${decoded}" | jq --arg count "${non_cf_count}" '.ps = "vmess-" + $count')
        encoded=$(echo "${processed}" | base64 -w 0)
        echo "vmess://${encoded}" >> "${VMESS_CONFIGS_FILE}"
        non_cf_count=$((non_cf_count + 1))
    fi
done < "${RAW_CONFIGS_FILE}"

echo "Processing completed."
echo "Cloudflare VMess configs saved to ${VMESS_CF_CONFIGS_FILE}"
echo "Non-Cloudflare VMess configs saved to ${VMESS_CONFIGS_FILE}"
