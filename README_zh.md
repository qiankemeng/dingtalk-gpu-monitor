# Dingtalk-GPU-Monitor
**For the English version, please refer to [README.md](README.md).**
一个开源Bash脚本，用于监控NVIDIA GPU的利用率和内存使用情况。通过DingTalk webhook发送通知。该脚本设计为无需管理员权限即可运行，适合服务器环境中的自动化监控。
脚本强调可配置性和安全性，例如：
- 通过命令行参数或环境变量自定义配置。
- 使用变量处理敏感信息（如警报前缀），避免硬编码。
- 包括冷却期机制，防止警报消息 spam。
此脚本适用于数据中心、AI训练服务器或其他依赖GPU的场景，帮助用户及时发现GPU资源闲置或异常。

## 特性

- **实时监控**：使用 `nvidia-smi` 命令获取GPU利用率和内存使用数据。
- **警报机制**：
  - 如果总内存使用率低于20%，发送警告。
  - 如果所有GPU利用率低于1%，发送空闲警报。
  - 如果总内存使用率相对于上次下降超过指定百分比（默认40%），发送下降警报。
- **冷却期控制**：为不同警报类型设置冷却期，避免频繁通知。
- **可配置性**：支持命令行选项和环境变量配置，包括服务器IP、阈值、GPU数量、冷却期和警报前缀。
- **安全性**：敏感信息（如DingTalk webhook URL和警报前缀）通过环境变量或参数设置，不硬编码在脚本中。
- **错误处理**：自动检查依赖项和配置，确保脚本稳定运行。
- **开源友好**：使用MIT许可，易于扩展和贡献。
## 逻辑
本脚本设计了两套逻辑来处理GPU监控和警报，确保系统在不同场景下都能高效运行：

**原始逻辑**：专注于实时监控GPU内存使用情况，当内存下降超过预设阈值（如通过ENV_THRESHOLD_PERCENT定义）时立即发送DingTalk警报。冷静期为ENV_COOLDOWN_TIME_ORIGINAL
**新逻辑**：当显存低于阈值或GPU占用低于阈值即发送通知提示。冷静期为ENV_COOLDOWN_TIME_NEW

## 要求

### 系统要求
- **操作系统**：Linux系统（已测试于Ubuntu/Debian系列）。
- **权限**：无需root权限，但需要用户能运行 `nvidia-smi` 命令（通常需要安装NVIDIA驱动）。
- **依赖软件**：
  - `nvidia-smi`：NVIDIA驱动程序的一部分，用于查询GPU数据。
  - `bc`：用于数学计算（安装命令：`sudo apt install bc`）。
  - `curl`：用于发送HTTP请求到DingTalk webhook（安装命令：`sudo apt install curl`）。
  - Bash 4.0+（默认安装于大多数Linux系统）。

### 配置要求
- DingTalk webhook URL：必须通过环境变量 `WEBHOOK_URL` 设置。
- 其他配置：可以通过命令行参数或环境变量设置（详见下文）。


## 安装
1. **克隆仓库**：
   ```
   git clone https://github.com/yourusername/gpu-dingtalk-alert.git
   cd gpu-dingtalk-alert
   ```
2. **赋予执行权限**：
   ```
   chmod +x gpu_monitor.sh
   ```
3. **设置环境变量**：
   在运行脚本前，设置必要的环境变量。例如：
   ```
   export WEBHOOK_URL="https://oapi.dingtalk.com/robot/send?access_token=your_token_here"
   export ENV_SERVER_IP="your_server_ip"
   export ENV_ALERT_PREFIX="SecureServer"  # 钉钉机器人安全前缀设置
   ```
   - 这些变量可以保存在您的shell配置文件（如 `~/.bashrc`）中，以便持久化。

## 使用说明



### 运行脚本
基本命令：
```
./gpu_monitor.sh [选项]
```

脚本会自动执行监控逻辑，并在满足条件时发送DingTalk消息。


### 自动化运行使用Crontab
为了实现持续监控，我们推荐使用crontab定时任务将脚本设置为每10分钟执行一次。这有助于在后台定期检查GPU状态，而无需手动运行。

#### 步骤：
1. **编辑crontab**：
   运行以下命令以编辑您的crontab文件：
   ```
   crontab -e
   ```
   - 如果是首次使用，系统会提示选择编辑器（如nano或vim）。

2. **添加crontab条目**：  
   **在crontab文件中添加以下行，其中包含所有脚本支持的环境变量。** 这确保了变量在任务运行时被正确设置。请替换占位符为您的实际值。  
   ```
   */10 * * * * WEBHOOK_URL="your_webhook_url" ENV_SERVER_IP="your_server_ip" ENV_THRESHOLD_PERCENT="40" ENV_GPU_COUNT="4" ENV_COOLDOWN_TIME_ORIGINAL="300" ENV_COOLDOWN_TIME_NEW="7200" ENV_ALERT_PREFIX="your_alert_prefix" /path/to/your/gpu_monitor.sh >> /path/to/log/file.log 2>&1
   ```
   - **解释**：
     - `*/10 * * * *`：表示每10分钟执行一次。
     - **环境变量列表**：
       - `WEBHOOK_URL="your_webhook_url"`：DingTalk webhook URL。
       - `ENV_SERVER_IP="your_server_ip"`：服务器内网IP地址。
       - `ENV_THRESHOLD_PERCENT="40"`：内存下降阈值百分比（默认40）。
       - `ENV_GPU_COUNT="4"`：服务器上GPU的数量（默认4）。
       - `ENV_COOLDOWN_TIME_ORIGINAL="300"`：原始警报冷却期（默认300秒，即5分钟）。
       - `ENV_COOLDOWN_TIME_NEW="7200"`：新警报冷却期（默认7200秒，即2小时）。
       - `ENV_ALERT_PREFIX="your_alert_prefix"`：消息前缀。
     - `/path/to/your/gpu_monitor.sh`：替换为脚本的实际路径，例如 `/home/user/gpu-dingtalk-alert/gpu_monitor.sh`。
     - `>> /path/to/log/file.log 2>&1`：将输出重定向到日志文件，例如 `/var/log/gpu_monitor.log`，以便记录和调试。

3. **保存并退出**：
   - 在编辑器中保存文件（如在nano中按Ctrl+O然后Ctrl+X）。
   - Crontab会自动加载新条目。

#### 注意事项：
- **环境变量处理**：crontab任务不会继承您的shell环境变量，因此必须在条目中显式定义每个变量，如上所示。这可以防止脚本因缺少配置而失败。
- **权限和路径**：确保crontab用户有权执行脚本和访问依赖。如果日志文件目录需要特殊权限，请相应调整。
- **测试**：设置后，运行`crontab -l`查看条目，然后手动执行命令（例如：`WEBHOOK_URL="your_webhook_url" ... /path/to/your/gpu_monitor.sh`）以验证。
- **潜在问题**：条目可能会很长，如果变量值包含特殊字符（如"&"），请使用引号引用。


