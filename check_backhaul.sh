#!/bin/bash

clear
echo "========================================================="
echo "          粤沪京三网 【回程路由】检测【AS号专业版】"
echo "      支持：Debian Ubuntu Rocky AlmaLinux CentOS"
echo "========================================================="

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

result_summary=()

# ==============================================
# 检查系统 + mtr 依赖
# ==============================================
check_dependency() {
    if command -v mtr &> /dev/null; then
        echo -e "${GREEN}mtr 已安装${NC}"
        sleep 1
        return
    fi

    echo -e "${YELLOW}未检测到 mtr，需要安装才能正常检测回程路由${NC}"
    read -p "是否现在安装 mtr？(y/n): " yn
    case $yn in
        [Yy]* ) ;;
        [Nn]* )
            echo -e "${RED}退出脚本，未安装依赖${NC}"
            exit 0
            ;;
        * )
            echo -e "${RED}输入错误，退出脚本${NC}"
            exit 1
            ;;
    esac

    if [ -f /etc/debian_version ]; then
        echo -e "${GREEN}系统：Debian/Ubuntu${NC}"
        apt update -y
        apt install -y mtr
    elif [ -f /etc/redhat-release ]; then
        echo -e "${GREEN}系统：RHEL/Rocky/AlmaLinux/CentOS${NC}"
        yum install -y mtr
    else
        echo -e "${RED}不支持的系统${NC}"
        exit 1
    fi

    if ! command -v mtr &> /dev/null; then
        echo -e "${RED}mtr 安装失败，退出${NC}"
        exit 1
    fi
    echo -e "${GREEN}mtr 安装成功${NC}"
    sleep 1
    clear
}

# ==============================================
# 回程路由检测函数
# ==============================================
check_backhaul() {
    local name="$1"
    local host="$2"
    echo -e "${YELLOW}===== 【回程】检测 ${name} =====${NC}"
    echo "目标：$host"

    res=$(mtr -z --tcp -P 80 -w -c 3 "$host" 2>/dev/null)
    echo "$res" | awk 'NF>3 {print substr($0,1,65)}'

    echo -n "回程线路类型："
    if echo "$res" | grep -q "AS4809"; then
        line_type="电信CN2精品回程"
        line_color=$GREEN
    elif echo "$res" | grep -q "AS9929"; then
        line_type="联通9929精品回程"
        line_color=$GREEN
    elif echo "$res" | grep -q "AS58807"; then
        line_type="移动CMIN2精品回程"
        line_color=$GREEN
    elif echo "$res" | grep -q "AS4134"; then
        line_type="电信163普通回程"
        line_color=$YELLOW
    elif echo "$res" | grep -q "AS58453"; then
        line_type="移动CMI普通回程"
        line_color=$YELLOW
    elif echo "$res" | grep -q "AS4837"; then
        line_type="联通169普通回程"
        line_color=$YELLOW
    else
        line_type="普通中转/路由隐藏"
        line_color=$RED
    fi

    echo -e "${line_color}${line_type}${NC}"
    result_summary+=("$name|$line_type|$line_color")
    echo
}

# ==============================================
# 开始执行
# ==============================================
check_dependency

# 广东
check_backhaul "广东电信" "gd-ct-v4.ip.zstaticcdn.com"
check_backhaul "广东联通" "gd-cu-v4.ip.zstaticcdn.com"
check_backhaul "广东移动" "gd-cm-v4.ip.zstaticcdn.com"

# 上海
check_backhaul "上海电信" "sh-ct-v4.ip.zstaticcdn.com"
check_backhaul "上海联通" "sh-cu-v4.ip.zstaticcdn.com"
check_backhaul "上海移动" "sh-cm-v4.ip.zstaticcdn.com"

# 北京
check_backhaul "北京电信" "bj-ct-v4.ip.zstaticcdn.com"
check_backhaul "北京联通" "bj-cu-v4.ip.zstaticcdn.com"
check_backhaul "北京移动" "bj-cm-v4.ip.zstaticcdn.com"

# ==============================================
# 回程线路汇总
# ==============================================
echo "========================================================="
echo -e "${GREEN}                 【回程路由】最终汇总                 ${NC}"
echo "========================================================="

for item in "${result_summary[@]}"; do
    IFS='|' read -r name line_type color <<< "$item"
    printf "  %-10s " "$name"
    echo -e "${color}${line_type}${NC}"
done

echo "========================================================="
echo " 说明：本结果为服务器回程路由，反映回国线路质量"
echo " AS4809=电信CN2  | AS9929=联通9929 | AS58807=移动CMIN2"
echo " AS4134=电信163  | AS4837=联通169  | AS58453=移动CMI"
echo "========================================================="