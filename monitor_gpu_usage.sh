#!/bin/bash
# ============================================================================
# GPU Monitor Script with DingTalk Alerts
# 
# This script monitors NVIDIA GPU utilization and memory usage, sending alerts
# via DingTalk webhook when certain thresholds are met (e.g., total memory < 20%
# or all GPUs idle). It does not require administrator privileges in standard
# setups, as it relies on 'nvidia-smi' which can be run by regular users.
#
# Features:
# - Monitors GPU utilization and memory.
# - Sends alerts with cooldown periods to avoid spam.
# - Configurable via command-line arguments or environment variables.
# - Secure handling of sensitive information, such as alert prefixes.
#
# Requirements:
# - nvidia-smi (from NVIDIA drivers)
# - bc (for calculations)
# - curl (for sending DingTalk messages)
#
# Usage:
#   ./gpu_monitor.sh [options]
#   Options:
#     -i <SERVER_IP>        Set server IP (default: from env var or prompt)
#     -t <THRESHOLD_PERCENT> Set decline threshold percentage (default: 40)
#     -c <GPU_COUNT>        Set number of GPUs (default: 8)
#     -o <COOLDOWN_ORIGINAL> Set original cooldown in seconds (default: 300)
#     -n <COOLDOWN_NEW>     Set new cooldown in seconds (default: 7200)
#     -p <ALERT_PREFIX>     Set alert prefix for messages 
#     -h                    Show this help message
#
# Environment Variables:
#   WEBHOOK_URL: Set your DingTalk webhook URL
#   ENV_SERVER_IP: Set server IP
#   ENV_THRESHOLD_PERCENT: Set threshold percentage
#   ENV_GPU_COUNT: Set GPU count
#   ENV_COOLDOWN_TIME_ORIGINAL: Set original cooldown
#   ENV_COOLDOWN_TIME_NEW: Set new cooldown
#   ENV_ALERT_PREFIX: Set alert prefix (e.g., for sensitive info)
#   LAST_TOTAL_MEMORY_FILE: Path for last memory file (default: ./last_total_memory_used)
#   LAST_SEND_TIME_FILE: Path for original alert time file (default: ./last_gpu_alert_time)
#   LAST_SEND_TIME_FILE_NEW: Path for new alert time file (default: ./last_new_alert_time)
#
# License: MIT License (see below)
# ============================================================================

# MIT License
#
# Copyright (c) [Year] [Your Name]
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

# Default values
DEFAULT_SERVER_IP=""
DEFAULT_THRESHOLD_PERCENT=40
DEFAULT_GPU_COUNT=4
DEFAULT_COOLDOWN_ORIGINAL=300
DEFAULT_COOLDOWN_NEW=7200
DEFAULT_ALERT_PREFIX=""
DEFAULT_LAST_TOTAL_MEMORY_FILE="./last_total_memory_used"
DEFAULT_LAST_SEND_TIME_FILE="./last_gpu_alert_time"
DEFAULT_LAST_SEND_TIME_FILE_NEW="./last_new_alert_time"

show_help() {
    echo "Usage: $0 [options]"
    echo "Options:"
    echo "  -i <SERVER_IP>        Server IP address"
    echo "  -t <THRESHOLD_PERCENT> Decline threshold percentage (default: $DEFAULT_THRESHOLD_PERCENT)"
    echo "  -c <GPU_COUNT>        Number of GPUs (default: $DEFAULT_GPU_COUNT)"
    echo "  -o <COOLDOWN_ORIGINAL> Original cooldown in seconds (default: $DEFAULT_COOLDOWN_ORIGINAL)"
    echo "  -n <COOLDOWN_NEW>     New cooldown in seconds (default: $DEFAULT_COOLDOWN_NEW)"
    echo "  -p <ALERT_PREFIX>     Alert prefix for messages (default: \"$DEFAULT_ALERT_PREFIX\")"
    echo "  -h                    Show this help message"
    exit 0
}

# Parse command-line arguments
while getopts "i:t:c:o:n:p:h" opt; do  # Added 'p' for ALERT_PREFIX
    case $opt in
        i) SERVER_IP=$OPTARG ;;
        t) THRESHOLD_PERCENT=$OPTARG ;;
        c) GPU_COUNT=$OPTARG ;;
        o) COOLDOWN_TIME_ORIGINAL=$OPTARG ;;
        n) COOLDOWN_TIME_NEW=$OPTARG ;;
        p) ALERT_PREFIX=$OPTARG ;;  # New case for alert prefix
        h) show_help ;;
        *) echo "Invalid option"; show_help ;;
    esac
done

# Fallback to environment variables or defaults
SERVER_IP=${SERVER_IP:-${ENV_SERVER_IP:-$DEFAULT_SERVER_IP}}
THRESHOLD_PERCENT=${THRESHOLD_PERCENT:-${ENV_THRESHOLD_PERCENT:-$DEFAULT_THRESHOLD_PERCENT}}
GPU_COUNT=${GPU_COUNT:-${ENV_GPU_COUNT:-$DEFAULT_GPU_COUNT}}
COOLDOWN_TIME_ORIGINAL=${COOLDOWN_TIME_ORIGINAL:-${ENV_COOLDOWN_TIME_ORIGINAL:-$DEFAULT_COOLDOWN_ORIGINAL}}
COOLDOWN_TIME_NEW=${COOLDOWN_TIME_NEW:-${ENV_COOLDOWN_TIME_NEW:-$DEFAULT_COOLDOWN_NEW}}
ALERT_PREFIX=${ALERT_PREFIX:-${ENV_ALERT_PREFIX:-$DEFAULT_ALERT_PREFIX}}  # New line for alert prefix
LAST_TOTAL_MEMORY_FILE=${LAST_TOTAL_MEMORY_FILE:-${ENV_LAST_TOTAL_MEMORY_FILE:-$DEFAULT_LAST_TOTAL_MEMORY_FILE}}
LAST_SEND_TIME_FILE=${LAST_SEND_TIME_FILE:-${ENV_LAST_SEND_TIME_FILE:-$DEFAULT_LAST_SEND_TIME_FILE}}
LAST_SEND_TIME_FILE_NEW=${LAST_SEND_TIME_FILE_NEW:-${ENV_LAST_SEND_TIME_FILE_NEW:-$DEFAULT_LAST_SEND_TIME_FILE_NEW}}
WEBHOOK_URL=${WEBHOOK_URL:-""}  # Must be set via environment variable

# Validate required variables
if [ -z "$WEBHOOK_URL" ]; then
    echo "Error: WEBHOOK_URL environment variable is required."
    exit 1
fi

if [ -z "$SERVER_IP" ]; then
    echo "Error: SERVER_IP is required. Use -i option or set ENV_SERVER_IP."
    exit 1
fi

# Check for dependencies
command -v nvidia-smi >/dev/null 2>&1 || { echo "Error: nvidia-smi is not installed."; exit 1; }
command -v bc >/dev/null 2>&1 || { echo "Error: bc is not installed."; exit 1; }
command -v curl >/dev/null 2>&1 || { echo "Error: curl is not installed."; exit 1; }

# Function: Get and parse GPU data
get_gpu_data() {
    nvidia-smi --query-gpu=utilization.gpu,memory.used,memory.total --format=csv,noheader,nounits
}

# Main logic
GPU_DATA=$(get_gpu_data 2>/dev/null)
if [ $? -ne 0 ] || [ -z "$GPU_DATA" ]; then
    echo "Error: Failed to retrieve GPU data. Ensure NVIDIA drivers are installed."
    exit 1
fi

# Check GPU count
if [ $(echo "$GPU_DATA" | wc -l) -ne "$GPU_COUNT" ]; then
    echo "Error: Detected GPU count ($(echo "$GPU_DATA" | wc -l)) does not match expected ($GPU_COUNT)."
    exit 1
fi

TOTAL_MEMORY_USED=0
TOTAL_MEMORY_TOTAL=0
ALL_UTILIZATIONS=()
ALL_GPU_DATA=""

i=0
while read -r line; do
    UTILIZATION=$(echo "$line" | awk -F ',' '{print $1}')
    MEMORY_USED=$(echo "$line" | awk -F ',' '{print $2}')
    MEMORY_TOTAL=$(echo "$line" | awk -F ',' '{print $3}')
    
    TOTAL_MEMORY_USED=$(echo "$TOTAL_MEMORY_USED + $MEMORY_USED" | bc)
    TOTAL_MEMORY_TOTAL=$(echo "$TOTAL_MEMORY_TOTAL + $MEMORY_TOTAL" | bc)
    ALL_UTILIZATIONS+=("$UTILIZATION")
    ALL_GPU_DATA+="GPU $i: Utilization: $UTILIZATION%, Memory Used: $MEMORY_USED MB / $MEMORY_TOTAL MB\n"
    i=$((i + 1))
done <<< "$GPU_DATA"

# New alert logic
NEW_ALERT_TRIGGERED=false
NEW_MESSAGE_CONTENT=""

if [ "$TOTAL_MEMORY_TOTAL" -gt 0 ]; then
    TOTAL_MEMORY_PERCENT=$(echo "scale=2; ($TOTAL_MEMORY_USED / $TOTAL_MEMORY_TOTAL) * 100" | bc)
    
    if (( $(echo "$TOTAL_MEMORY_PERCENT < 20" | bc -l) )); then
        NEW_ALERT_TRIGGERED=true
        NEW_MESSAGE_CONTENT="【$ALERT_PREFIX】IP: $SERVER_IP Warning: Total memory usage below 20%!\n\nTotal Memory: $TOTAL_MEMORY_USED MB / $TOTAL_MEMORY_TOTAL MB ($TOTAL_MEMORY_PERCENT%)\n\n$ALL_GPU_DATA\nPlease check the server."  # Updated with $ALERT_PREFIX
    fi
    
    ALL_BELOW_THRESHOLD=true
    for UTIL in "${ALL_UTILIZATIONS[@]}"; do
        if (( $(echo "$UTIL >= 1" | bc -l) )); then
            ALL_BELOW_THRESHOLD=false
            break
        fi
    done
    
    if [ "$ALL_BELOW_THRESHOLD" = true ]; then
        NEW_ALERT_TRIGGERED=true
        if [ -z "$NEW_MESSAGE_CONTENT" ]; then
            NEW_MESSAGE_CONTENT="【$ALERT_PREFIX】IP: $SERVER_IP GPUs are idle!\n\n$ALL_GPU_DATA\nPlease check the server."  # Updated with $ALERT_PREFIX
        else
            NEW_MESSAGE_CONTENT+="\nAdditionally, 【$ALERT_PREFIX】IP: $SERVER_IP GPUs are idle!"
        fi
    fi
    
    if [ "$NEW_ALERT_TRIGGERED" = true ]; then
        CURRENT_TIME=$(date +%s)
        if [ -f "$LAST_SEND_TIME_FILE_NEW" ]; then
            LAST_SEND_TIME_NEW=$(cat "$LAST_SEND_TIME_FILE_NEW")
            ELAPSED_TIME_NEW=$((CURRENT_TIME - LAST_SEND_TIME_NEW))
            if [ "$ELAPSED_TIME_NEW" -ge "$COOLDOWN_TIME_NEW" ]; then
                curl -H "Content-Type: application/json" -X POST -d "{\"msgtype\": \"text\", \"text\": {\"content\": \"$NEW_MESSAGE_CONTENT\"}}" "$WEBHOOK_URL"
                if [ $? -eq 0 ]; then
                    echo "$CURRENT_TIME" > "$LAST_SEND_TIME_FILE_NEW"
                    echo "New alert sent successfully."
                else
                    echo "Failed to send new alert."
                fi
            else
                echo "New alert cooldown active. Waiting $(($COOLDOWN_TIME_NEW - ELAPSED_TIME_NEW)) seconds."
            fi
        else
            curl -H "Content-Type: application/json" -X POST -d "{\"msgtype\": \"text\", \"text\": {\"content\": \"$NEW_MESSAGE_CONTENT\"}}" "$WEBHOOK_URL"
            if [ $? -eq 0 ]; then
                echo "$CURRENT_TIME" > "$LAST_SEND_TIME_FILE_NEW"
                echo "New alert sent successfully."
            else
                echo "Failed to send new alert."
            fi
        fi
    fi
fi

# Original alert logic (updated similarly)
# Note: Ensure to update any other message strings if needed.
MESSAGE_CONTENT_ORIGINAL="【$ALERT_PREFIX】IP: $SERVER_IP Warning: Total memory usage declined over $THRESHOLD_PERCENT%!\n\n$ALL_GPU_DATA\nTotal memory from last $LAST_TOTAL_MEMORY_USED MB to $TOTAL_MEMORY_USED MB.\nPlease check the server."  # Updated with $ALERT_PREFIX

# The rest of the original logic remains the same.
