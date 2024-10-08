#!/bin/bash

# 設定變數
ZONE_FILE="taifo_v1.txt"
A_IP="103.31.196.3"  # A Server IP
B_IP="103.31.198.2"  # B Server IP

# 分隔線
SEPARATOR="~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"

# 從zone檔案中讀取每一個zone name
while read -r ZONE; do
    OUTPUT_FILE="${ZONE}_compare_result.txt"
    
    # 查詢A Server的所有DNS紀錄
    dig @${A_IP} axfr ${ZONE} | grep -E "IN\s+(A|CNAME|TXT|NS|SOA|PTR|MX)" > a_records_${ZONE}.txt

    # 創建一個關聯數組來存儲每個記錄名稱的所有記錄
    declare -A records

    # 讀取並處理每一筆紀錄
    while read -r line; do
        # 解析紀錄的各個部分
        RECORD_NAME=$(echo $line | awk '{print $1}')
        TTL=$(echo $line | awk '{print $2}')
        RECORD_TYPE=$(echo $line | awk '{print $4}')
        RECORD_DATA=$(echo $line | awk '{$1=$2=$3=$4=""; print $0}' | sed 's/^[ \t]*//')

        # 將記錄添加到關聯數組中
        if [[ -v "records[$RECORD_NAME $RECORD_TYPE]" ]]; then
            records["$RECORD_NAME $RECORD_TYPE"]+=$'\n'"$RECORD_DATA"
        else
            records["$RECORD_NAME $RECORD_TYPE"]="$RECORD_DATA"
        fi
    done < a_records_${ZONE}.txt

    # 處理每個唯一的記錄名稱和類型
    for key in "${!records[@]}"; do
        read RECORD_NAME RECORD_TYPE <<< "$key"
        A_RECORDS="${records[$key]}"

        if [ "$RECORD_TYPE" == "SOA" ]; then
            # 處理SOA記錄
            MNAME=$(echo "$A_RECORDS" | awk '{print $1}')
            RNAME=$(echo "$A_RECORDS" | awk '{print $2}')

            # 對B Server進行SOA查詢
            B_RESULT=$(dig @${B_IP} SOA ${RECORD_NAME} +short)
            
            # 解析B Server的SOA回應
            B_MNAME=$(echo $B_RESULT | awk '{print $1}')
            B_RNAME=$(echo $B_RESULT | awk '{print $2}')

            # 比對SOA紀錄的各個部分，只比對MNAME和RNAME
            if [ "$MNAME" == "$B_MNAME" ] && [ "$RNAME" == "$B_RNAME" ]; then
                echo -e "${SEPARATOR}\n${RECORD_NAME} IN SOA ${MNAME} ${RNAME} 比對ok" >> ${OUTPUT_FILE}
            else
                echo -e "${SEPARATOR}\n${RECORD_NAME} SOA紀錄不同於A Server" >> ${OUTPUT_FILE}
                echo "A Server: ${MNAME} ${RNAME}" >> ${OUTPUT_FILE}
                echo "B Server: ${B_MNAME} ${B_RNAME}" >> ${OUTPUT_FILE}
            fi
        elif [ "$RECORD_TYPE" == "NS" ] || [ "$RECORD_TYPE" == "MX" ] || [ "$RECORD_TYPE" == "TXT" ] || [ "$RECORD_TYPE" == "PTR" ]; then
            # 查詢B Server的記錄
            B_RESULT=$(dig @${B_IP} ${RECORD_TYPE} ${RECORD_NAME} +short)
            
            # 排序並比較結果
            A_SORTED=$(echo "$A_RECORDS" | sort)
            B_SORTED=$(echo "$B_RESULT" | sort)
            
            if [ "$A_SORTED" == "$B_SORTED" ]; then
                echo -e "${SEPARATOR}\n${RECORD_NAME} IN ${RECORD_TYPE} 比對ok" >> ${OUTPUT_FILE}
                echo "$A_SORTED" >> ${OUTPUT_FILE}
            else
                echo -e "${SEPARATOR}\n${RECORD_NAME} ${RECORD_TYPE}紀錄不同於A Server" >> ${OUTPUT_FILE}
                echo "A Server ${RECORD_TYPE}紀錄:" >> ${OUTPUT_FILE}
                echo "$A_SORTED" >> ${OUTPUT_FILE}
                echo "B Server ${RECORD_TYPE}紀錄:" >> ${OUTPUT_FILE}
                echo "$B_SORTED" >> ${OUTPUT_FILE}
            fi
        else  # A 和 CNAME 記錄
            # 查詢B Server的記錄
            B_RESULT=$(dig @${B_IP} ${RECORD_TYPE} ${RECORD_NAME} +short)
            
            # 排序並比較結果
            A_SORTED=$(echo "$A_RECORDS" | sort)
            B_SORTED=$(echo "$B_RESULT" | sort)
            
            if [ "$A_SORTED" == "$B_SORTED" ]; then
                echo -e "${SEPARATOR}\n${RECORD_NAME} IN ${RECORD_TYPE} 比對ok" >> ${OUTPUT_FILE}
                echo "$A_SORTED" >> ${OUTPUT_FILE}
            else
                echo -e "${SEPARATOR}\n${RECORD_NAME} ${RECORD_TYPE}紀錄不同於A Server" >> ${OUTPUT_FILE}
                echo "A Server:" >> ${OUTPUT_FILE}
                echo "$A_SORTED" >> ${OUTPUT_FILE}
                echo "B Server:" >> ${OUTPUT_FILE}
                echo "$B_SORTED" >> ${OUTPUT_FILE}
            fi
        fi
    done

    # 清理暫存檔案和關聯數組
    rm -f a_records_${ZONE}.txt
    unset records

done < ${ZONE_FILE}
