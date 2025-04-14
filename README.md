# Dingtalk-GPU-Monitor
An open-source Bash script for monitoring NVIDIA GPU utilization and memory usage. It sends notifications via DingTalk webhook. The script is designed to run without administrator privileges, making it suitable for automated monitoring in server environments.
The script emphasizes configurability and security, for example:
- Custom configuration through command-line parameters or environment variables.
- Handling sensitive information (such as alert prefixes) using variables to avoid hardcoding.
- Including a cooldown mechanism to prevent alert message spam.
This script is suitable for data centers, AI training servers, or other GPU-dependent scenarios, helping users timely detect idle or abnormal GPU resources.

## Features

- **Real-time Monitoring**: Uses the `nvidia-smi` command to retrieve GPU utilization and memory usage data.
- **Alert Mechanism**:
  - If total memory usage is below 20%, send a warning.
  - If all GPU utilization is below 1%, send an idle alert.
  - If total memory usage drops by more than a specified percentage compared to the last time (default 40%), send a drop alert.
- **Cooldown Control**: Sets cooldown periods for different alert types to avoid frequent notifications.
- **Configurability**: Supports configuration via command-line options and environment variables, including server IP, thresholds, GPU count, cooldown periods, and alert prefixes.
- **Security**: Sensitive information (such as DingTalk webhook URL and alert prefixes) is set through environment variables or parameters, not hardcoded in the script.
- **Error Handling**: Automatically checks dependencies and configurations to ensure stable script operation.
- **Open-Source Friendly**: Uses the MIT license, making it easy to extend and contribute.

## Logic
This script is designed with two sets of logic to handle GPU monitoring and alerts, ensuring the system operates efficiently in different scenarios:

**Original Logic**: Focuses on real-time monitoring of GPU memory usage, immediately sending a DingTalk alert when memory drops below a preset threshold (such as defined by ENV_THRESHOLD_PERCENT). Cooldown period is ENV_COOLDOWN_TIME_ORIGINAL.
**New Logic**: Sends a notification prompt when video memory is below the threshold or GPU occupancy is below the threshold. Cooldown period is ENV_COOLDOWN_TIME_NEW.

## Requirements

### System Requirements
- **Operating System**: Linux systems (tested on Ubuntu/Debian series).
- **Permissions**: No root privileges required, but the user must be able to run the `nvidia-smi` command (typically requires NVIDIA drivers to be installed).
- **Dependencies**:
  - `nvidia-smi`: Part of the NVIDIA driver, used for querying GPU data.
  - `bc`: For mathematical calculations (installation command: `sudo apt install bc`).
  - `curl`: For sending HTTP requests to DingTalk webhook (installation command: `sudo apt install curl`).
  - Bash 4.0+ (default installed on most Linux systems).

### Configuration Requirements
- DingTalk webhook URL: Must be set via the environment variable `WEBHOOK_URL`.
- Other configurations: Can be set via command-line parameters or environment variables (see below).

## Installation
1. **Clone the Repository**:
   ```
   git clone https://github.com/yourusername/gpu-dingtalk-alert.git
   cd gpu-dingtalk-alert
   ```
2. **Grant Execution Permissions**:
   ```
   chmod +x gpu_monitor.sh
   ```
3. **Set Environment Variables**:
   Before running the script, set the necessary environment variables. For example:
   ```
   export WEBHOOK_URL="https://oapi.dingtalk.com/robot/send?access_token=your_token_here"
   export ENV_SERVER_IP="your_server_ip"
   export ENV_ALERT_PREFIX="SecureServer"  # DingTalk robot security prefix setting
   ```
   - These variables can be saved in your shell configuration file (such as `~/.bashrc`) for persistence.

## Usage Instructions

### Running the Script
Basic command:
```
./gpu_monitor.sh [options]
```

The script will automatically execute the monitoring logic and send DingTalk messages when conditions are met.

### Automated Running with Crontab
To achieve continuous monitoring, we recommend setting the script to run every 10 minutes using crontab scheduled tasks. This helps periodically check GPU status in the background without manual intervention.

#### Steps:
1. **Edit Crontab**:
   Run the following command to edit your crontab file:
   ```
   crontab -e
   ```
   - If this is your first time, the system will prompt you to select an editor (such as nano or vim).

2. **Add Crontab Entry**:  
   **Add the following line to the crontab file, which includes all environment variables supported by the script.** This ensures that the variables are set correctly when the task runs. Please replace placeholders with your actual values.  
   ```
   */10 * * * * WEBHOOK_URL="your_webhook_url" ENV_SERVER_IP="your_server_ip" ENV_THRESHOLD_PERCENT="40" ENV_GPU_COUNT="4" ENV_COOLDOWN_TIME_ORIGINAL="300" ENV_COOLDOWN_TIME_NEW="7200" ENV_ALERT_PREFIX="your_alert_prefix" /path/to/your/gpu_monitor.sh >> /path/to/log/file.log 2>&1
   ```
   - **Explanation**:
     - `*/10 * * * *`: Indicates execution every 10 minutes.
     - **Environment Variable List**:
       - `WEBHOOK_URL="your_webhook_url"`: DingTalk webhook URL (required; do not use actual values in the example).
       - `ENV_SERVER_IP="your_server_ip"`: Server internal IP address.
       - `ENV_THRESHOLD_PERCENT="40"`: Memory drop threshold percentage (default 40).
       - `ENV_GPU_COUNT="4"`: Number of GPUs on the server (default 4).
       - `ENV_COOLDOWN_TIME_ORIGINAL="300"`: Original alert cooldown period (default 300 seconds, i.e., 5 minutes).
       - `ENV_COOLDOWN_TIME_NEW="7200"`: New alert cooldown period (default 7200 seconds, i.e., 2 hours).
       - `ENV_ALERT_PREFIX="your_alert_prefix"`: Message prefix.
     - `/path/to/your/gpu_monitor.sh`: Replace with the actual path to the script, for example, `/home/user/gpu-dingtalk-alert/gpu_monitor.sh`.
     - `>> /path/to/log/file.log 2>&1`: Redirects output to a log file, for example, `/var/log/gpu_monitor.log`, for recording and debugging.

3. **Save and Exit**:
   - Save the file in the editor (e.g., in nano, press Ctrl+O then Ctrl+X).
   - Crontab will automatically load the new entry.

#### Notes:
- **Environment Variable Handling**: Crontab tasks do not inherit your shell environment variables, so each variable must be explicitly defined in the entry as shown above. This prevents the script from failing due to missing configurations.
- **Permissions and Paths**: Ensure the crontab user has permission to execute the script and access dependencies. If the log file directory requires special permissions, adjust accordingly.
- **Testing**: After setting, run `crontab -l` to view the entries, then manually execute the command (e.g., `WEBHOOK_URL="your_webhook_url" ... /path/to/your/gpu_monitor.sh`) to verify.
- **Potential Issues**: Entries may be long; if variable values contain special characters (such as "&"), enclose them in quotes.
