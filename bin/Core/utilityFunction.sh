#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

CURRENT_DIR=$(cd "$(dirname "$0")" || exit; pwd)
LogsPATH="${CURRENT_DIR}/logs"
SRC_DIR="../Src"
output_path="../../Releases"
LOG_DIR="../logs"

ck_files() {
    [ ! -d "${LogsPATH}" ] && log "创建日志目录：${LogsPATH}" && mkdir -p "${LogsPATH}"
    LogFile="${LogsPATH}/Coder-man-$(date +"%Y%m%d").log"
    [ ! -f "${LogFile}" ] && log "创建日志文件：${LogFile}" && touch "${LogFile}" && chmod 644 "${LogFile}"
}

get_Script_dir_Config() {
    local config_path="./Config_env.json"
    [ -f "$config_path" ] && log "配置文件存在：$config_path" || log "配置文件不存在：$config_path，使用默认路径：$config_path"
    echo "$config_path"
}

# 函数声明: 使用 shc 编译脚本
b2bin() {
    ck_tools
    local bud_ver
    bud_ver=$(get_Config_newVer)
    local output_file="$1"
    local input_file="$2"
    CLAGS="-static" shc -r -f "$input_file" -o "${output_file}_v${bud_ver}"
    # 删除中间文件
    cleanC
    if [ $? -eq 0 ]; then
        echo "脚本编译成功,保存在${output_file}_v${bud_ver}"
    else
        echo "脚本编译失败."
        exit 1
    fi
}
# 函数声明: 使用 gcc 二重编译脚本
b2GCC() {
    ck_tools
    local bud_ver
    bud_ver=$(get_Config_newVer)
    local output_file="$1"
    local input_file="$2"
    CLAGS="-static" shc -r -f "$input_file" -o "$output_file"
    gcc -static -o "${output_file}_v${bud_ver}" "${input_file}.x.c" -DVERSION="$bud_ver"
    # 删除中间文件
    cleanC
    if [ $? -eq 0 ]; then
        rm "$output_file"
        echo "脚本编译成功,保存在${output_file}_v${bud_ver}"
    else
        echo "脚本编译失败."
        exit 1
    fi
}


b2WIN() {
    echo "正在开发中,敬请期待"
}
# 编译自身所有脚本函数
compile_all() {
    local input_file=$1
    local output_name=$2
    sudo bash ./bud2exe -s b2bin -o "$output_path/${output_name}_sfh_linux" -f "./$input_file" && \
    sudo bash ./bud2exe -s b2GCC -o "$output_path/${output_name}_gcc_linux" -f "./$input_file"
    if [[ $? -ne 0 ]]; then
        log_message "ERROR" "编译失败：$input_file"
        return 1
    fi
}


# 清理函数
cleanC() {
    find "$SRC_DIR" -name "*.x.c" -delete
    log_message "DEBUG" "所有中间缓存已清理"
}

# 计算 SHA256 哈希函数
calculate_sha256() {
    local file=$1
    if [[ -f "$file" ]]; then
        sha256sum "$file" > "${file}.sha256"
    else
        log_message "ERROR" "文件未找到：$file"
    fi
}


# 清理函数
cleanLOGS() {
    find "$LOG_DIR" -name "*.*" -delete
    log_message "DEBUG" "所有日志已清理"
}

# 清理函数
cleanBuilds() {
    find "$output_path" -name "*.*" -delete
    log_message "DEBUG" "所有编译文件已清理"
}


log() {
    local rr_debug
    rr_debug=$(get_Config_debug)
    local logs_time
    logs_time=$(date +"%Y-%m-%d %H:%M:%S")
    local message="[Aspnmy Log][$logs_time][$0]: $1"

    if [ "$rr_debug" -eq 0 ]; then
        case "$1" in
            *"失败"*|*"错误"*|*"请使用 root 或 sudo 权限运行此脚本"*) echo -e "${RED}${message}${NC}" ;;
            *"成功"*) echo -e "${GREEN}${message}${NC}" ;;
            *"忽略"*|*"跳过"*) echo -e "${YELLOW}${message}${NC}" ;;
            *) echo -e "${BLUE}${message}${NC}" ;;
        esac
    else
        ck_files
        echo "$message" >> "${LogsPATH}/Coder-man-$(date +"%Y%m%d").log"
    fi
}

ck_install() {
    local pkg_name=$1
    local install_cmd=$2
    if ! command -v "$pkg_name" >/dev/null 2>&1; then
        echo "$pkg_name 未安装，正在安装..."
        eval "$install_cmd"
        command -v "$pkg_name" >/dev/null 2>&1 && echo "$pkg_name 安装成功。" || { echo "$pkg_name 安装失败，请手动安装 $pkg_name。" >&2; exit 1; }
    else
        echo "$pkg_name 已安装。"
    fi
}

ck_install_jq() {
    ck_install "jq" "case \"\$(uname -s)\" in
        Linux*) [ -x \$(command -v apt-get) ] && sudo apt-get update && sudo apt-get install -y jq || [ -x \$(command -v yum) ] && sudo yum install -y jq || [ -x \$(command -v dnf) ] && sudo dnf install -y jq || [ -x \$(command -v zypper) ] && sudo zypper install -y jq ;;
        Darwin*) [ -x \$(command -v brew) ] && brew install jq ;;
        FreeBSD*) [ -x \$(command -v pkg) ] && sudo pkg install -y jq ;;
        *) echo \"不支持的操作系统，安装 jq 失败。\" >&2; exit 1 ;;
    esac"
}

ck_install_shc() {
    ck_install "shc" "case \"\$(uname -s)\" in
        Linux*) [ -x \$(command -v apt-get) ] && sudo apt-get update && sudo apt-get install -y shc || [ -x \$(command -v yum) ] && sudo yum install -y shc || [ -x \$(command -v dnf) ] && sudo dnf install -y shc || [ -x \$(command -v zypper) ] && sudo zypper install -y shc ;;
        Darwin*) [ -x \$(command -v brew) ] && brew install shc ;;
        FreeBSD*) [ -x \$(command -v pkg) ] && sudo pkg install -y shc ;;
        *) echo \"不支持的操作系统，安装 shc 失败。\" >&2; exit 1 ;;
    esac"
}

ck_install_gcc() {
    ck_install "gcc" "case \"\$(uname -s)\" in
        Linux*) [ -x \$(command -v apt-get) ] && sudo apt-get update && sudo apt-get install -y gcc || [ -x \$(command -v yum) ] && sudo yum install -y gcc || [ -x \$(command -v dnf) ] && sudo dnf install -y gcc || [ -x \$(command -v zypper) ] && sudo zypper install -y gcc ;;
        Darwin*) [ -x \$(command -v brew) ] && brew install gcc ;;
        FreeBSD*) [ -x \$(command -v pkg) ] && sudo pkg install -y gcc ;;
        *) echo \"不支持的操作系统，安装 gcc 失败。\" >&2; exit 1 ;;
    esac"
}

get_Config_debug() {
    local config_dir
    config_dir=$(get_Script_dir_Config)
    [ ! -f "$config_dir" ] && log "JSON file not found!" && exit 1
    jq -r '.["logs_debug"]' "$config_dir"
}

get_Config_newVer() {
    local config_dir
    config_dir=$(get_Script_dir_Config)
    [ ! -f "$config_dir" ] && log "JSON file not found!" && exit 1
    jq -r '.["newVer"]' "$config_dir"
}



# 显示菜单函数
show_menu() {
    echo -e "${BLUE}
/*
 *  ██████╗ ██╗   ██╗██████╗ ██████╗ ███████╗██╗  ██╗███████╗
 *  ██╔══██╗██║   ██║██╔══██╗╚════██╗██╔════╝╚██╗██╔╝██╔════╝
 *  ██████╔╝██║   ██║██║  ██║ █████╔╝█████╗   ╚███╔╝ █████╗
 *  ██╔══██╗██║   ██║██║  ██║██╔═══╝ ██╔══╝   ██╔██╗ ██╔══╝
 *  ██████╔╝╚██████╔╝██████╔╝███████╗███████╗██╔╝ ██╗███████╗
 *  ╚═════╝  ╚═════╝ ╚═════╝ ╚══════╝╚══════╝╚═╝  ╚═╝╚══════╝
 *  'author': 'aspnmy@gmail.com'
 */${NC}"
    echo "bud2exe,一个简单的二进制编译工具-免费版"
    echo "Tg讨论组:https://t.me/+BqvlH6BDOWE3NjQ1"
    echo "赞助我们:TKqTUNcBWiRDdczuHoQstMD4XRyFgNwHiF (TRX/USDT)"
    echo "1)b2bin/编译脚本成为一个1层加壳的二进制文件(需要shc组件)/用法: bud2exe -s b2bin -o output_file -f input_file "
    echo "2)b2GCC/用GCC再次编译脚本成为一个2层加壳的二进制文件(需要gcc组件)/用法: bud2exe -s b2GCC -o output_file -f input_file "
    echo "3)b2WIN/编译脚本成为一个64位exe文件(需要安装MinGW-w64 交叉编译工具链)/用法: bud2exe -s b2WIN -o output_file -f input_file "
    echo "0)退出"
}