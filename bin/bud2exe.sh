#!/bin/bash


RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'



version="v3.0.0"
CURRENT_DIR=$(cd "$(dirname "$0")" || exit; pwd) # 当前脚本所在目录
PARENT_DIR=$(dirname "$CURRENT_DIR") # 当前脚本所在目录的上级目录
ROOT_DIR=$(dirname "$PARENT_DIR") # 当前脚本所在目录的上上级目录
Releases_DIR="${ROOT_DIR}/Releases" # 编译文件目录
Executable_DIR="${ROOT_DIR}/bin/Src" # 可执行文件目录
LogsPATH="$PARENT_DIR/logs" # 日志目录



# 初始化函数
initialize() {
    # 设置脚本的运行环境
    set -o errexit  # 如果任何命令失败，则退出脚本
    set -o nounset  # 如果使用了未定义的变量，则退出脚本
    set -o pipefail # 如果管道中的任何命令失败，则整个管道失败

    # 设置内存限制为 64MB
    ulimit -m 65536

    if [ ! -z "$Releases_DIR" ]; then
        mkdir -p "$Releases_DIR"

    fi
    if [ ! -z "$LogsPATH" ]; then
        mkdir -p "$LogsPATH"

    fi


}


initialize

# 获取配置文件路径
get_Script_dir_Config() {
    local config_path="./Config_env.json"
    echo $config_path
    if [ -f "$config_path" ]; then
        log "配置文件存在：$config_path"
    else
        log "配置文件不存在：$config_path，使用默认路径：$config_path"
    fi
    echo "$config_path"
}

# 函数声明: 使用 shc 编译脚本
b2bin() {
    
    local bud_ver
    bud_ver=$(get_Config_newVer)
    local outputDir
    outputDir=$(get_Config_outputDir)
    local output_file="$1"
    local input_file="$2"

    local outputFile_Name="${outputDir}/${output_file}_shc_v${bud_ver}"

    CLAGS="-static" shc -r -f "$input_file" -o "${outputFile_Name}"
    # 删除中间文件
    cleanC "$input_file"
    if [ $? -eq 0 ]; then
        log "脚本编译成功,保存在${outputFile_Name}"
    else
        log "脚本编译失败."
        exit 1
    fi
}





# 函数声明: 使用 gcc 二重编译脚本
b2GCC() {
    local bud_ver
    bud_ver=$(get_Config_newVer)
    local outputDir
    outputDir=$(get_Config_outputDir)
    local output_file="$1"
    local input_file="$2"

    local outputFile_Name="${outputDir}/${output_file}_gcc_v${bud_ver}"

    # shc静态编译
    CLAGS="-static" shc -r -f "$input_file" -o "${outputFile_Name}"
    
    #gcc 再打包一层壳 静态编译
    gcc -static -o "${outputFile_Name}" "$input_file.x.c" -DVERSION="$bud_ver"
    if [ $? -eq 0 ]; then
        # 删除中间文件
        cleanC "$input_file"
        log "脚本编译成功,保存在${outputFile_Name}"
    else
        log "脚本编译失败."
        exit 1
    fi
}


b2WIN() {
    local bud_ver
    bud_ver=$(get_Config_newVer)
    local outputDir
    outputDir=$(get_Config_outputDir)
    local output_file="$1"
    local input_file="$2"

    local outputFile_Name="${outputDir}/${output_file}_x86_64_v${bud_ver}.exe"

    # 使用 MinGW-w64 交叉编译工具链编译
    shc -r -f "$input_file" -o "${input_file}.x"
    x86_64-w64-mingw32-gcc -o "${outputFile_Name}" "${input_file}.x.c"
    if [ $? -eq 0 ]; then
        log "脚本编译成功,保存在${outputFile_Name}"
        rm "${input_file}.x" "${input_file}.x.c"
    else
        log "脚本编译失败."
        exit 1
    fi
}

# 计算 SHA256 哈希函数
calculate_sha256() {
    local file=$1
    if [[ -f "$file" ]]; then
        sha256sum "$file" > "${file}.sha256"
    else
        log "ERROR" "文件未找到：$file"
    fi
}


# 清理函数
cleanC() {
    local SRC_DIR="$1"
    rm "$SRC_DIR.x.c"
    log "DEBUG" "所有中间缓存已清理"
}


# 清理函数
cleanLOGS() {
    find "$LogsPATH" -name "*.*" -delete
    log "DEBUG" "所有日志已清理"
}

# 清理函数
cleanBuilds() {
    find "$Releases_DIR" -name "*.*" -delete
    log "DEBUG" "所有编译文件已清理"
}

# 清理所有文件函数
cleanALL() {
    cleanC
    cleanLOGS
    cleanBuilds
    log "DEBUG" "所有文件已清理"
}

# 显示版本信息函数
version() {
    echo "当前版本: ${version}"
}

log() {
    local rr_debug
    local logs_time
    rr_debug=$(get_Config_debug)
    logs_time=$(get_Time)
    local message="[Aspnmy Log][$logs_time][$0]: $1"

    if [ "$rr_debug" -eq 0 ]; then
        # 如果 logs_debug 等于 0，log()函数只输出messages到终端，不写日志文件
        case "$1" in
            *"失败"*|*"错误"*|*"请使用 root 或 sudo 权限运行此脚本"*)
                echo -e "${RED}${message}${NC}"
                ;;
            *"成功"*)
                echo -e "${GREEN}${message}${NC}"
                ;;
            *"忽略"*|*"跳过"*)
                echo -e "${YELLOW}${message}${NC}"
                ;;
            *)
                echo -e "${BLUE}${message}${NC}"
                ;;
        esac
    elif [ "$rr_debug" -eq 1 ]; then
        # 如果 logs_debug 等于 1，log()函数只输出日志文件不输出message
        formatted_date=$(date +"%Y%m%d")
        LogFile="${LogsPATH}/Coder-man-$formatted_date.log"
        if [ ! -z "$LogFile" ]; then
            touch  "$LogFile"
        fi
        echo "$LogFile"
        echo "$message" | tee -a "${LogFile}"
    fi
}




# 定义安装函数
ck_install_tools() {
    local package_manager=""
    local install_command=""

    # 检测操作系统类型
    case "$(uname -s)" in
        Linux*)
            if [ -x "$(command -v apt-get)" ]; then
                package_manager="apt-get"
                install_command="sudo apt-get update && sudo apt-get install -y"
            elif [ -x "$(command -v yum)" ]; then
                package_manager="yum"
                install_command="sudo yum install -y"
            elif [ -x "$(command -v dnf)" ]; then
                package_manager="dnf"
                install_command="sudo dnf install -y"
            elif [ -x "$(command -v zypper)" ]; then
                package_manager="zypper"
                install_command="sudo zypper install -y"
            else
                log "不支持的 Linux 发行版，无法安装工具。" >&2
                exit 1
            fi
            ;;
        Darwin*)
            if [ -x "$(command -v brew)" ]; then
                package_manager="brew"
                install_command="brew install"
            else
                log "Homebrew 未安装，无法在 macOS 上安装工具。" >&2
                exit 1
            fi
            ;;
        FreeBSD*)
            if [ -x "$(command -v pkg)" ]; then
                package_manager="pkg"
                install_command="sudo pkg install -y"
            else
                log "pkg 未安装，无法在 FreeBSD 上安装工具。" >&2
                exit 1
            fi
            ;;
        *)
            log "不支持的操作系统，无法安装工具。" >&2
            exit 1
            ;;
    esac

    # 检查并安装缺失的组件
    for tool in gcc jq shc x86_64-w64-mingw32-gcc g++-mingw-w64-x86-64 binutils-mingw-w64-x86-64 tar; do
        if ! command -v "$tool" &> /dev/null; then
            log "正在安装 $tool..."
    if [ "$package_manager" == "apt-get" ]; then
        sudo apt-get update
            fi
            $install_command "$tool"
    else
            log "$tool 已经安装。"
    fi
    done

    log "所有组件检查并安装完成。"
}

get_Time() {
    formatted_date=$(date +"%Y-%m-%d %H:%M:%S")
    echo "$formatted_date"
}

get_Config_debug() {
    # 检查JSON文件是否存在
    local config_dir="./Config_env.json"

    if [ ! -f "$config_dir" ]; then
        log "JSON file not found!"
        exit 1
    fi
    # 使用jq解析JSON文件中的logs_debug字段
    res=$(jq -r '.["logs_debug"]' "$config_dir")
    echo "$res"
}

# coder的alpine基础镜像版本-未打包coder代码本身
# 需要构建更小的coder镜像需要，一般直接以coder官方镜像为基础进行打包
get_Config_newVer() {

    local config_dir="./Config_env.json"

    if [ ! -f "$config_dir" ]; then
        log "JSON file not found!"
        exit 1
    fi
    # 使用jq解析JSON文件中的alpinebaseVer字段
    res=$(jq -r '.["newVer"]' "$config_dir")
    echo "$res"
}
get_Config_outputDir() {

    local config_dir="./Config_env.json"

    if [ ! -f "$config_dir" ]; then
        log "JSON file not found!"
        exit 1
    fi
    # 使用jq解析JSON文件中的alpinebaseVer字段
    res=$(jq -r '.["outputDir"]' "$config_dir")
    if [ ! -f "$res" ]; then
        mkdir -p "$res"
    fi
    echo "$res"
}

# 新增函数: 使用 tar 打包文件
create_tar() {
    
    local output_tar="$1" # 打包后的文件名*.tar.gz
    local source_dir="$2" # 被打包的目录
    if [ -d "$source_dir" ]; then
        tar -czvf "$output_tar" -C "$source_dir" .
        if [ $? -eq 0 ]; then
            log "文件打包成功,保存在${output_tar}"
            exit 0
        else
            log "文件打包失败."
            exit 1
        fi
    else
        log "ERROR" "目录未找到：$source_dir"
        exit 1
    fi
}

# 显示文档函数
doc() {
    echo "文档路径: ./docs/docs.md"
    cat ./docs/docs.md
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
 *  ╚═════╝  ╚═════╝ ╚═════╝ ╚══════╝╚═╝  ╚═╝╚══════╝
 *  "author: aspnmy@gmail.com"
 *
 *    "bud2exe,一个简单的二进制编译工具-免费版"
 *    "Tg讨论组:https://t.me/+BqvlH6BDOWE3NjQ1"
 *    "赞助我们:TKqTUNcBWiRDdczuHoQstMD4XRyFgNwHiF 【TRX/USDT】"
 *    "1 b2bin/编译脚本成为一个1层加壳的二进制文件-需要shc组件/用法: bud2exe -s b2bin -o output_file -f input_file "
 *    "2 b2GCC/用GCC再次编译脚本成为一个2层加壳的二进制文件-需要gcc组件 /用法: bud2exe -s b2GCC -o output_file -f input_file "
 *    "3 b2WIN/编译脚本成为一个64位exe文件-需要安装MinGW-w64 交叉编译工具链，使用此函数的时候如果被编译的是shell脚本需要win系统支持bin/bash环境 /用法: bud2exe -s b2WIN -o output_file -f input_file "
 *    "4 create_tar/打包目录成为一个tar.gz文件/用法: bud2exe -s create_tar -o output_tar -f source_dir "
 *    "5 清理所有编译文件/用法: bud2exe -s cleanBuilds"
 *    "6 清理所有日志文件/用法: bud2exe -s cleanLOGS"
 *    "7 清理所有中间文件/用法: bud2exe -s cleanC"
 *    "8 清理所有文件/用法: bud2exe -s cleanALL"
 *    "9 查看版本/用法: bud2exe -s version"
 *    "a 查看帮助/用法: bud2exe -s help"
 *    "b 安装所有组件/用法: bud2exe -s ck_install_tools"
 *    "c 查看文档/用法: bud2exe -s doc"
 *    "0 退出"
 * */${NC}"
}

main(){
    show_menu
    
# 解析命令行选项
while getopts "vhs:o:f:h" opt; do
    case "${opt}" in
        h)
            echo "${version}"
            ;;
        s)
            sub_command="${OPTARG}"
            ;;
        o)
            output_file="${OPTARG}"
            ;;
        f)
            input_file="${OPTARG}"
            ;;
        h)
            show_menu
            exit 0
            ;;
        *)
            echo "Usage: bud2exe -s <b2bin|b2gcc|b2win|create_tar> -o output_file -f input_file "
            exit 1
            ;;
    esac
done

# 检查是否提供了所有必需的参数
if [ -z "${sub_command}" ]; then
    echo "Error: Sub-command must be provided."
    echo "Usage: bud2exe -s <b2bin|b2gcc|b2win|create_tar> -o output_file -f input_file "
    exit 1
fi

if [[ "${sub_command}" != "cleanBuilds" && "${sub_command}" != "cleanLOGS" && "${sub_command}" != "cleanC" && "${sub_command}" != "cleanALL" && "${sub_command}" != "version" && "${sub_command}" != "ck_install_tools" && "${sub_command}" != "doc" && "${sub_command}" != "help" ]]; then
    if [ -z "${output_file}" ] || [ -z "${input_file}" ]; then
        echo "Error: Output file and input file must be provided."
        echo "Usage: bud2exe -s <b2bin|b2gcc|b2win|create_tar> -o output_file -f input_file "
        exit 1
    fi
fi

# 根据子命令执行相应的函数
case "${sub_command}" in
    b2bin)
        b2bin "${output_file}" "${input_file}"
        ;;
    b2gcc)
        b2GCC "${output_file}" "${input_file}"
        ;;
    b2win)
        b2WIN "${output_file}" "${input_file}"
        ;;
    create_tar)
        create_tar "${input_file}" "${output_file}"
        ;;
    cleanBuilds)
        cleanBuilds
        ;;
    cleanLOGS)
        cleanLOGS
        ;;
    cleanC)
        cleanC
        ;;
    cleanALL)
        cleanALL
        ;;
    version)
        version
        ;;
    ck_install_tools)
        ck_install_tools
        ;;
    doc)
        doc
        ;;
    help)
        show_menu
        ;;
    *)
        echo "Invalid sub-command: ${sub_command}"
        echo "Usage: bud2exe -s <b2bin|b2gcc|b2win|create_tar> -o output_file -f input_file "
        exit 1
        ;;
esac
}

main "$@"
