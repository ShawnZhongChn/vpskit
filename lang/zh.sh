#!/bin/bash
# ============================================
# VPS Kit - Chinese (zh)
# ============================================

_ZH_LANG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
if [ -f "${_ZH_LANG_DIR}/en.sh" ]; then
    # shellcheck source=lang/en.sh
    . "${_ZH_LANG_DIR}/en.sh"
fi

LANG_CODE="zh"
LANG_YES_CHARS="yY是"
LANG_YES_PROMPT="(y/N)"

# ============================================
# VPSKIT.SH
# ============================================

MSG_VPSKIT_MENU_TITLE="=== 请选择要执行的操作 ==="
MSG_VPSKIT_MENU_1="初始化或更新 VPS"
MSG_VPSKIT_MENU_2="部署应用"
MSG_VPSKIT_MENU_3="查看 VPS 和应用状态"
MSG_VPSKIT_MENU_4="备份 / 恢复应用"
MSG_VPSKIT_MENU_5="安全审计"
MSG_VPSKIT_MENU_6="设置"
MSG_VPSKIT_MENU_7="退出"
MSG_VPSKIT_CHOICE_PROMPT="请输入选项 (1-7，或 q 退出): "
MSG_VPSKIT_BYE="已退出。"
MSG_VPSKIT_INVALID_CHOICE="无效选项，请输入 1 到 7，或输入 q 退出"
MSG_VPSKIT_DOWNLOADING="正在下载 %s..."
MSG_VPSKIT_DOWNLOAD_FAILED="无法下载 %s"
MSG_VPSKIT_NO_CURL_WGET="需要安装 curl 或 wget"
MSG_VPSKIT_EMPTY_FILE="下载的文件为空"
MSG_VPSKIT_SYNTAX_ERROR="下载的脚本存在语法错误"
MSG_VPSKIT_DOWNLOADED="脚本已下载并通过校验"
MSG_VPSKIT_UNKNOWN_CMD="未知命令：%s"
MSG_VPSKIT_USAGE="用法：bash vpskit.sh [setup|deploy|status|backup|security|settings]"
MSG_VPSKIT_SCRIPT_NOT_FOUND="找不到脚本：%s"
MSG_VPSKIT_TAGLINE="初始化。加固。部署。"

# ============================================
# SETTINGS.SH
# ============================================

MSG_SETTINGS_BANNER_TITLE="VPS Kit 设置"
MSG_SETTINGS_BANNER_SUBTITLE="管理偏好设置和本地会话"
MSG_SETTINGS_SESSION_ACTIVE="当前会话：%s@%s (key: %s)"
MSG_SETTINGS_MENU_TITLE="=== 设置 ==="
MSG_SETTINGS_MENU_1="管理 SSH 快捷方式 (~/.ssh/config)"
MSG_SETTINGS_MENU_2="管理 SSH 密钥 (~/.ssh/)"
MSG_SETTINGS_MENU_3="切换语言"
MSG_SETTINGS_MENU_4="清除本地会话"
MSG_SETTINGS_MENU_5="设置自动部署"
MSG_SETTINGS_MENU_6="设置远程备份"
MSG_SETTINGS_MENU_7="返回"
MSG_SETTINGS_CHOICE_PROMPT="请输入选项 (1-7): "
MSG_SETTINGS_BACK="返回。"
MSG_SETTINGS_INVALID_CHOICE="无效选项，请输入 1 到 7"
MSG_SETTINGS_LANG_CURRENT="当前语言：%s (%s)"
MSG_SETTINGS_LANG_AVAILABLE="可用语言："
MSG_SETTINGS_LANG_ACTIVE_TAG="[当前]"
MSG_SETTINGS_LANG_UPDATED="语言已更新：%s (%s)"
MSG_SETTINGS_CANCEL="已取消。"
MSG_SETTINGS_RBACKUP_REMOTE_FAILED="远程备份配置在 VPS 上执行失败。"

# ============================================
# COMMON LOCAL FLOWS
# ============================================

MSG_SETUP_BANNER_SUBTITLE="初始化并加固你的服务器"
MSG_SETUP_BANNER_SUBTITLE2="按步骤执行，可中断后继续"
MSG_SETUP_OS_MAC="检测到 macOS"
MSG_SETUP_OS_LINUX="检测到 Linux"
MSG_SETUP_OS_WINDOWS_GITBASH="检测到 Windows Git Bash"
MSG_SETUP_OS_WSL="检测到 WSL"
MSG_SETUP_MODE_NEW="1) 初始化一台新 VPS"
MSG_SETUP_MODE_UPDATE="2) 更新已有 VPS"
MSG_SETUP_MODE_PROMPT="请选择模式 (1/2): "
MSG_SETUP_POSTSETUP_TITLE="连接信息"
MSG_SETUP_POSTSETUP_CONNECT_HINT="现在可以使用下面的命令连接服务器："
MSG_SETUP_POSTSETUP_SHORTCUT_PROMPT="是否创建 SSH 快捷方式？(y/N): "

MSG_DEPLOY_TITLE="把应用部署到 VPS"
MSG_DEPLOY_SESSION_FOUND="检测到 vpskit 会话："
MSG_DEPLOY_SESSION_CONFIRM_PROMPT="这是你的服务器吗？(y/N): "
MSG_DEPLOY_ACTION_PROMPT="请选择部署操作："
MSG_DEPLOY_REPO_URL_PROMPT="Git 仓库地址："
MSG_DEPLOY_DOMAIN_PROMPT="域名："
MSG_DEPLOY_PORT_PROMPT="应用端口 (默认 3000): "
MSG_DEPLOY_CONFIRM_LAUNCH_PROMPT="开始部署？(y/N): "
MSG_DEPLOY_SCRIPT_SENDING="正在发送部署脚本..."
MSG_DEPLOY_EXECUTING="正在远程执行部署..."
MSG_DEPLOY_DONE_TITLE="部署完成"
MSG_DEPLOY_DONE_URL="应用地址："

MSG_STATUS_HEADER="查看 VPS 和应用状态"
MSG_STATUS_SESSION_FOUND="检测到 vpskit 会话："
MSG_STATUS_SESSION_CONFIRM="这是你的服务器吗？(y/N): "
MSG_STATUS_CONNECTING="正在连接服务器..."
MSG_STATUS_SENDING="正在发送状态检查脚本..."

MSG_SECURITY_HEADER="VPS 安全审计"
MSG_SECURITY_SESSION_FOUND="检测到 vpskit 会话："
MSG_SECURITY_SESSION_CONFIRM="这是你的服务器吗？(y/N): "
MSG_SECURITY_CONNECTING="正在连接服务器..."
MSG_SECURITY_SENDING="正在发送安全审计脚本..."

MSG_BACKUP_HEADER="应用备份与恢复"
MSG_BACKUP_SESSION_FOUND="检测到 vpskit 会话："
MSG_BACKUP_SESSION_CONFIRM="这是你的服务器吗？(y/N): "
MSG_BACKUP_ACTION_PROMPT="[>] 请选择操作："
MSG_BACKUP_ACTION_SAVE="    1) 备份一个或全部应用"
MSG_BACKUP_ACTION_RESTORE="    2) 从备份文件恢复应用"
MSG_BACKUP_ACTION_CHOICE="请输入选项："
MSG_BACKUP_CONNECTING="正在连接服务器..."
MSG_BACKUP_SENDING_SCRIPT="正在发送备份脚本..."
MSG_BACKUP_ERR_RETRIEVE="无法下载备份文件：%s"

# ============================================
# REMOTE SCRIPT COMMON MESSAGES
# ============================================

RMSG_SETUP_FINAL_TITLE="服务器已准备就绪！"
RMSG_SETUP_FINAL_INSTALLED="已安装 / 已配置："
RMSG_DEPLOY_DONE_TITLE="部署完成！"
RMSG_DEPLOY_ERR_ROLLBACK_HINT="  如果本次更新破坏了可用版本，请在部署菜单中选择回滚："
RMSG_DEPLOY_HEALTH_TITLE="检查应用状态"
RMSG_DEPLOY_HEALTH_WAIT="等待应用启动..."
RMSG_STATUS_DEPLOY_TYPE_LABEL="    部署方式：%s"
RMSG_STATUS_HEALTH_OK="健康状态：正常（HTTP %s）- %s"
RMSG_STATUS_HEALTH_WARN="健康状态：警告（HTTP %s）- %s"
RMSG_STATUS_HEALTH_ERR="健康状态：错误（HTTP %s）- %s"
RMSG_STATUS_HEALTH_URL_LABEL="    健康检查：%s"
RMSG_STATUS_HEALTH_UNKNOWN="未记录健康检查说明"
RMSG_STATUS_SERVER_SECTION="  服务器："
RMSG_STATUS_SECURITY_SECTION="  安全："
RMSG_SECURITY_TITLE="安全审计"
RMSG_SECURITY_SSH_SECTION="  SSH："
RMSG_SECURITY_FIREWALL_SECTION="  防火墙："
RMSG_SECURITY_SYSTEM_SECTION="  系统："
RMSG_SECURITY_DEPLOY_HEALTH_SECTION="  部署健康："
RMSG_SECURITY_DEPLOY_HEALTH_OK="%s（%s）：健康（HTTP %s）"
RMSG_SECURITY_DEPLOY_HEALTH_WARN="%s（%s）：警告（HTTP %s）- %s"
RMSG_SECURITY_DEPLOY_HEALTH_ERR="%s（%s）：失败（HTTP %s）- %s"
RMSG_SECURITY_DEPLOY_HEALTH_NONE="未找到部署健康元数据"
RMSG_SECURITY_DEPLOY_HEALTH_UNKNOWN="未记录健康检查说明"
RMSG_BACKUP_DONE="备份完成！"
