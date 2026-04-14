#!/bin/bash

clear
echo "========================================================="
echo "          粤沪京三网 【回程路由】检测【AS号专业版】"
echo "      支持：Debian Ubuntu Rocky AlmaLinux CentOS"
echo "========================================================="
echo -e "${YELLOW}提示：地理路径通过API查询，可能存在一定误差，请以实际路由为准${NC}"
echo

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

result_summary=()

# ==============================================
# 检查系统 + 依赖
# ==============================================
check_dependency() {
    # 检查 mtr
    if command -v mtr &> /dev/null; then
        echo -e "${GREEN}mtr 已安装${NC}"
    else
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
            echo -e "${YELLOW}不支持的系统，请到软件包管理器手动安装 mtr${NC}"
        fi

        if ! command -v mtr &> /dev/null; then
            echo -e "${RED}mtr 安装失败，退出${NC}"
            exit 1
        fi
        echo -e "${GREEN}mtr 安装成功${NC}"
    fi
    
    # 检查 curl
    if command -v curl &> /dev/null; then
        echo -e "${GREEN}curl 已安装${NC}"
    else
        echo -e "${YELLOW}未检测到 curl，需要安装才能查询地理位置${NC}"
        read -p "是否现在安装 curl？(y/n): " yn
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
            apt install -y curl
        elif [ -f /etc/redhat-release ]; then
            echo -e "${GREEN}系统：RHEL/Rocky/AlmaLinux/CentOS${NC}"
            yum install -y curl
        else
            echo -e "${YELLOW}不支持的系统，请到软件包管理器手动安装 curl${NC}"
        fi

        if ! command -v curl &> /dev/null; then
            echo -e "${RED}curl 安装失败，退出${NC}"
            exit 1
        fi
        echo -e "${GREEN}curl 安装成功${NC}"
    fi
    
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

    # 显示回程线路类型
    echo -e "${line_color}${line_type}${NC}"

    # 提取并显示地理路径和AS路径
    echo -n "地理路径："
    geo_path=""
    as_path=""
    last_geo=""
    last_as=""
    

    
    # 逐行处理 mtr 输出（使用进程替换避免子 shell 问题）
    while read -r line; do
        # 检查是否是路由节点行（以数字开头）
        if [[ "$line" =~ ^[[:space:]]*[0-9]+\. ]]; then
            # 提取字段
            fields=($line)
            if [ ${#fields[@]} -ge 5 ]; then
                as=${fields[1]}
                host=${fields[2]}
                
                # 构建 AS 路径（只包含有效的 AS 号，去重连续重复）
                if [[ "$as" =~ ^AS[0-9]+$ ]]; then
                    if [ -z "$as_path" ]; then
                        as_path="$as"
                        last_as="$as"
                    elif [ "$as" != "$last_as" ]; then
                        as_path="$as_path -> $as"
                        last_as="$as"
                    fi
                fi
                
                # 构建地理路径
                location=""
                if [[ "$host" != *.*.*.* && "$host" != "???" ]]; then
                    # 跳过没有地理位置信息的主机名
                    continue
                elif [[ "$host" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                    # 检查是否是内网IP或回环IP
                    is_private_ip=false
                    if [[ "$host" =~ ^10\. || "$host" =~ ^172\.(1[6-9]|2[0-9]|3[0-1])\. || "$host" =~ ^192\.168\. || "$host" =~ ^127\. ]]; then
                        is_private_ip=true
                    fi
                    
                    # 跳过内网IP
                    if [ "$is_private_ip" = "true" ]; then
                        continue
                    fi
                    
                    # 是 IP 地址，使用 API 查询地理位置
                    if command -v curl &> /dev/null; then
                        # 获取国家信息（添加超时设置）
                        country=$(curl -s --max-time 5 "https://ipinfo.io/$host/country" 2>/dev/null)
                        # 检查返回结果是否是错误信息
                        if [ -z "$country" ]; then
                            location="API查询超时"
                        elif [[ "$country" =~ "status" ]] && [[ "$country" =~ "error" ]]; then
                            # 检查是否是API限流错误
                            if [[ "$country" =~ "429" ]] || [[ "$country" =~ "Rate limit" ]]; then
                                location="API查询受限"
                            else
                                location="API查询超时"
                            fi
                        else
                            if [ "$country" = "CN" ]; then
                                # 中国显示城市（添加超时设置）
                                city=$(curl -s --max-time 5 "https://ipinfo.io/$host/city" 2>/dev/null)
                                if [ -z "$city" ]; then
                                    location="API查询超时"
                                elif [[ "$city" =~ "status" ]] && [[ "$city" =~ "error" ]]; then
                                    # 检查是否是API限流错误
                                    if [[ "$city" =~ "429" ]] || [[ "$city" =~ "Rate limit" ]]; then
                                        location="API查询受限"
                                    else
                                        location="API查询超时"
                                    fi
                                else
                                    # 英文城市名转中文
                                    case "$city" in
                                        "Shanghai") location="上海" ;;
                                        "Beijing") location="北京" ;;
                                        "Guangzhou") location="广州" ;;
                                        "Shenzhen") location="深圳" ;;
                                        "Bao'an") location="深圳" ;;
                                        "Tianjin") location="天津" ;;
                                        "Jinrongjie") location="金融街" ;;
                                        *) location="$city" ;;
                                    esac
                                fi
                            else
                                # 国外和港澳台显示（添加超时设置）
                                country_name=$(curl -s --max-time 5 "https://ipinfo.io/$host/country" 2>/dev/null)
                                # 检查返回结果是否是错误信息
                                if [ -z "$country_name" ]; then
                                    location="API查询超时"
                                elif [[ "$country_name" =~ "status" ]] && [[ "$country_name" =~ "error" ]]; then
                                    # 检查是否是API限流错误
                                    if [[ "$country_name" =~ "429" ]] || [[ "$country_name" =~ "Rate limit" ]]; then
                                        location="API查询受限"
                                    else
                                        location="API查询超时"
                                    fi
                                else
                                    # 国家代码转中文
                                    case "$country_name" in
                                        "SG") location="新加坡" ;;
                                        "JP") location="日本" ;;
                                        "US") location="美国" ;;
                                        "GB") location="英国" ;;
                                        "FR") location="法国" ;;
                                        "DE") location="德国" ;;
                                        "NL") location="荷兰" ;;
                                        "KR") location="韩国" ;;
                                        "TW") location="台湾" ;;
                                        "HK") location="香港" ;;
                                        "MO") location="澳门" ;;
                                        "AU") location="澳大利亚" ;;
                                        "CA") location="加拿大" ;;
                                        "RU") location="俄罗斯" ;;
                                        "IN") location="印度" ;;
                                        *) location="$country_name" ;;
                                    esac
                                fi
                            fi
                        fi
                    else
                        location="$host"
                    fi
                fi
                
                # 地理路径去重连续重复
                if [ -n "$location" ]; then
                    if [ -z "$geo_path" ]; then
                        geo_path="$location"
                        last_geo="$location"
                    elif [ "$location" != "$last_geo" ]; then
                        geo_path="$geo_path -> $location"
                        last_geo="$location"
                    fi
                fi
            fi
        fi
    done < <(echo "$res")
    
    # 显示结果
    if [ -n "$geo_path" ]; then
        echo "$geo_path"
    else
        echo "未知"
        geo_path="未知"
    fi
    
    echo -n "自治系统路径："
    if [ -n "$as_path" ]; then
        echo "$as_path"
    else
        echo "未知"
        as_path="未知"
    fi
    
    result_summary+=("$name|$line_type|$line_color|$geo_path|$as_path")
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
    IFS='|' read -r name line_type color geo_path as_path <<< "$item"
    printf "  %-10s " "$name"
    echo -e "${color}${line_type}${NC}"
    echo "      地理路径：$geo_path"
    echo "      自治系统路径：$as_path"
    echo
done

echo "========================================================="
echo " 说明：本结果为服务器回程路由，反映回国线路质量"
echo " AS4809=电信CN2  | AS9929=联通9929 | AS58807=移动CMIN2"
echo " AS4134=电信163  | AS4837=联通169  | AS58453=移动CMI"
echo -e " ${YELLOW}提示：地理路径通过API查询，可能存在一定误差，请以实际路由为准${NC}"
echo "========================================================="
