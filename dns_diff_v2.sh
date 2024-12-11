#!/bin/bash

# 設定變數
ZONE_FILE="taifo_v1.txt"
A_SERVER="127.0.0.1"
B_SERVER="10.8.38.77"
WORK_DIR="/tmp/dns_compare"
DATE=$(date +%Y%m%d_%H%M%S)

# 創建工作目錄
mkdir -p ${WORK_DIR}

# 分隔線
SEPARATOR="~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"

# 函數：清理記錄格式
clean_record() {
    # 移除結尾點號，統一空白，移除註解
    sed 's/\.$//' | tr -s ' ' | grep -v '^;' | grep -v '^$'
}

# 函數：從AXFR提取記錄
extract_records() {
    local server=$1
    local zone=$2
    local output_file=$3
    
    # 執行 AXFR 查詢並過濾出所需記錄
    dig @${server} AXFR ${zone} | \
    grep -E "IN\s+(A|CNAME|TXT|NS|SOA|PTR|MX)" | \
    clean_record > ${output_file}
}

# 函數：比較記錄
compare_records() {
    local zone=$1
    local a_file=$2
    local b_file=$3
    local output_file="${WORK_DIR}/${zone}_compare_${DATE}.txt"
    
    echo "正在比對 ${zone} 的記錄..."
    
    # 讀取並排序 A Server 的記錄
    declare -A a_records
    while IFS= read -r line; do
        name=$(echo "$line" | awk '{print $1}')
        type=$(echo "$line" | awk '{print $4}')
        value=$(echo "$line" | awk '{$1=$2=$3=$4=""; print $0}' | sed 's/^[ \t]*//')
        key="${name} ${type}"
        if [[ -v "a_records[$key]" ]]; then
            a_records[$key]="${a_records[$key]}"$'\n'"$value"
        else
            a_records[$key]="$value"
        fi
    done < "$a_file"
    
    # 讀取並排序 B Server 的記錄
    declare -A b_records
    while IFS= read -r line; do
        name=$(echo "$line" | awk '{print $1}')
        type=$(echo "$line" | awk '{print $4}')
        value=$(echo "$line" | awk '{$1=$2=$3=$4=""; print $0}' | sed 's/^[ \t]*//')
        key="${name} ${type}"
        if [[ -v "b_records[$key]" ]]; then
            b_records[$key]="${b_records[$key]}"$'\n'"$value"
        else
            b_records[$key]="$value"
        fi
    done < "$b_file"
    
    # 比較記錄並輸出結果
    {
        echo "比對時間: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "A Server: ${A_SERVER}"
        echo "B Server: ${B_SERVER}"
        echo "Zone: ${zone}"
        echo "${SEPARATOR}"
        
        # 比較所有唯一的鍵值
        for key in "${!a_records[@]}" "${!b_records[@]}"; do
            name=$(echo "$key" | cut -d' ' -f1)
            type=$(echo "$key" | cut -d' ' -f2)
            
            a_values=$(echo "${a_records[$key]}" | sort)
            b_values=$(echo "${b_records[$key]}" | sort)
            
            if [[ "$a_values" == "$b_values" ]]; then
                if [[ -n "$a_values" ]]; then
                    echo "${name} IN ${type} 比對ok"
                    echo "$a_values"
                    echo "${SEPARATOR}"
                fi
            else
                echo "${name} ${type}紀錄不同於A Server"
                echo "A Server:"
                echo "$a_values"
                echo "B Server:"
                echo "$b_values"
                echo "${SEPARATOR}"
            fi
        done
    } > "$output_file"
    
    echo "比對結果已保存到: $output_file"
}

# 主程序
while read -r ZONE; do
    echo "處理 zone: ${ZONE}"
    
    # 建立暫存檔案
    A_FILE="${WORK_DIR}/${ZONE}_${DATE}_a.txt"
    B_FILE="${WORK_DIR}/${ZONE}_${DATE}_b.txt"
    
    # 從兩台伺服器獲取記錄
    extract_records "${A_SERVER}" "${ZONE}" "${A_FILE}"
    extract_records "${B_SERVER}" "${ZONE}" "${B_FILE}"
    
    # 比較記錄
    compare_records "${ZONE}" "${A_FILE}" "${B_FILE}"
    
    # 清理暫存檔案
    rm -f "${A_FILE}" "${B_FILE}"
    
done < ${ZONE_FILE}

# 最後清理工作目錄中超過 7 天的檔案
find ${WORK_DIR} -type f -mtime +7 -exec rm {} \;
