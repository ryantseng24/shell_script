#!/bin/bash

# 設定變數
ZONE="example.com"
A_IP="10.8.38.186"  # A Server IP
B_IP="10.8.38.186"  # B Server IP

# 查詢A Server的所有DNS紀錄
dig @${A_IP} axfr ${ZONE} | grep -E "IN\s+(A|CNAME|TXT|NS|SOA)" > a_records.txt

# 讀取並處理每一筆紀錄
while read -r line; do
    # 解析紀錄的各個部分
    RECORD_NAME=$(echo $line | awk '{print $1}')
    TTL=$(echo $line | awk '{print $2}')
    RECORD_TYPE=$(echo $line | awk '{print $4}')

    if [ "$RECORD_TYPE" == "SOA" ]; then
        # 解析SOA紀錄的各個部分
        MNAME=$(echo $line | awk '{print $5}')
        RNAME=$(echo $line | awk '{print $6}')
        SERIAL=$(echo $line | awk '{print $7}')
        REFRESH=$(echo $line | awk '{print $8}')
        RETRY=$(echo $line | awk '{print $9}')
        EXPIRE=$(echo $line | awk '{print $10}')
        MINIMUM=$(echo $line | awk '{print $11}')

        # 對B Server進行SOA查詢
        B_RESULT=$(dig @${B_IP} SOA ${RECORD_NAME} +short)

        # 解析B Server的SOA回應
        B_MNAME=$(echo $B_RESULT | awk '{print $1}')
        B_RNAME=$(echo $B_RESULT | awk '{print $2}')
        B_SERIAL=$(echo $B_RESULT | awk '{print $3}')
        B_REFRESH=$(echo $B_RESULT | awk '{print $4}')
        B_RETRY=$(echo $B_RESULT | awk '{print $5}')
        B_EXPIRE=$(echo $B_RESULT | awk '{print $6}')
        B_MINIMUM=$(echo $B_RESULT | awk '{print $7}')

        # 比對SOA紀錄的各個部分
        if [ "$MNAME" == "$B_MNAME" ] && [ "$RNAME" == "$B_RNAME" ] && [ "$SERIAL" == "$B_SERIAL" ] && \
           [ "$REFRESH" == "$B_REFRESH" ] && [ "$RETRY" == "$B_RETRY" ] && [ "$EXPIRE" == "$B_EXPIRE" ] && \
           [ "$MINIMUM" == "$B_MINIMUM" ]; then
            echo "${RECORD_NAME} ${TTL} IN SOA ${MNAME} ${RNAME} ${SERIAL} ${REFRESH} ${RETRY} ${EXPIRE} ${MINIMUM} 比對ok"
        else
            echo "${RECORD_NAME} SOA紀錄不同於A Server"
        fi
        else
        RECORD_DATA=$(echo $line | awk '{print $5}')

        # 對B Server進行查詢
        B_RESULT=$(dig @${B_IP} ${RECORD_TYPE} ${RECORD_NAME} +short)

        # 比對結果
        if [ "${RECORD_DATA}" == "${B_RESULT}" ]; then
            echo "${RECORD_NAME} ${TTL} IN ${RECORD_TYPE} ${RECORD_DATA} 比對ok"
        else
            echo "${RECORD_NAME} DNS紀錄不同於A Server"
        fi
    fi
done < a_records.txt

# 清理暫存檔案
rm -f a_records.txt

      
