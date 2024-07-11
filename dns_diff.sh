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

            # 對B Server進行SOA查詢
            B_RESULT=$(dig @${B_IP} SOA ${RECORD_NAME} +short)
            
            # 解析B Server的SOA回應
            B_MNAME=$(echo $B_RESULT | awk '{print $1}')
            B_RNAME=$(echo $B_RESULT | awk '{print $2}')

            # 比對SOA紀錄的各個部分，只比對MNAME和RNAME
            if [ "$MNAME" == "$B_MNAME" ] && [ "$RNAME" == "$B_RNAME" ]; then
                echo -e "${SEPARATOR}\n${RECORD_NAME} ${TTL} IN SOA ${MNAME} ${RNAME} 比對ok" >> ${OUTPUT_FILE}
            else
                echo -e "${SEPARATOR}\n${RECORD_NAME} SOA紀錄不同於A Server" >> ${OUTPUT_FILE}
                echo "A Server: ${MNAME} ${RNAME}" >> ${OUTPUT_FILE}
                echo "B Server: ${B_MNAME} ${B_RNAME}" >> ${OUTPUT_FILE}
            fi
        elif [ "$RECORD_TYPE" == "NS" ]; then
            # 查詢A Server的NS紀錄
            A_NS_RESULT=$(dig @${A_IP} NS ${ZONE} +short | sort)
            # 查詢B Server的NS紀錄
            B_NS_RESULT=$(dig @${B_IP} NS ${ZONE} +short | sort)
            
            # 比對NS紀錄
            if [ "$A_NS_RESULT" == "$B_NS_RESULT" ]; then
                echo -e "${SEPARATOR}\n${RECORD_NAME} ${TTL} IN NS ${A_NS_RESULT} 比對ok" >> ${OUTPUT_FILE}
            else
                echo -e "${SEPARATOR}\n${RECORD_NAME} NS紀錄不同於A Server" >> ${OUTPUT_FILE}
                echo "A Server NS紀錄" >> ${OUTPUT_FILE}
                echo "${A_NS_RESULT}" | tr ' ' '\n' >> ${OUTPUT_FILE}
                echo "B Server NS紀錄" >> ${OUTPUT_FILE}
                echo "${B_NS_RESULT}" | tr ' ' '\n' >> ${OUTPUT_FILE}
            fi
        elif [ "$RECORD_TYPE" == "TXT" ] || [ "$RECORD_TYPE" == "PTR" ]; then
            # 查詢A Server的TXT或PTR紀錄
            A_TXT_PTR_RESULT=$(dig @${A_IP} ${RECORD_TYPE} ${RECORD_NAME} +short | sort | tr '\n' ' ')
            # 查詢B Server的TXT或PTR紀錄
            B_TXT_PTR_RESULT=$(dig @${B_IP} ${RECORD_TYPE} ${RECORD_NAME} +short | sort | tr '\n' ' ')
            
            # 比對TXT或PTR紀錄
            if [ "$A_TXT_PTR_RESULT" == "$B_TXT_PTR_RESULT" ]; then
                echo -e "${SEPARATOR}\n${RECORD_NAME} ${TTL} IN ${RECORD_TYPE} ${A_TXT_PTR_RESULT} 比對ok" >> ${OUTPUT_FILE}
            else
                echo -e "${SEPARATOR}\n${RECORD_NAME} ${RECORD_TYPE}紀錄不同於A Server" >> ${OUTPUT_FILE}
                echo "A Server ${RECORD_TYPE}紀錄" >> ${OUTPUT_FILE}
                echo "${A_TXT_PTR_RESULT}" | tr ' ' '\n' >> ${OUTPUT_FILE}
                echo "B Server ${RECORD_TYPE}紀錄" >> ${OUTPUT_FILE}
                echo "${B_TXT_PTR_RESULT}" | tr ' ' '\n' >> ${OUTPUT_FILE}
            fi
        elif [ "$RECORD_TYPE" == "MX" ]; then
            # 查詢A Server的MX紀錄
            A_MX_RESULT=$(dig @${A_IP} MX ${RECORD_NAME} +short | sort)
            # 查詢B Server的MX紀錄
            B_MX_RESULT=$(dig @${B_IP} MX ${RECORD_NAME} +short | sort)
            
            # 比對MX紀錄
            if [ "$A_MX_RESULT" == "$B_MX_RESULT" ]; then
                echo -e "${SEPARATOR}\n${RECORD_NAME} ${TTL} IN MX ${A_MX_RESULT} 比對ok" >> ${OUTPUT_FILE}
            else
                echo -e "${SEPARATOR}\n${RECORD_NAME} MX紀錄不同於A Server" >> ${OUTPUT_FILE}
                echo "A Server MX紀錄" >> ${OUTPUT_FILE}
                echo "${A_MX_RESULT}" | tr ' ' '\n' >> ${OUTPUT_FILE}
                echo "B Server MX紀錄" >> ${OUTPUT_FILE}
                echo "${B_MX_RESULT}" | tr ' ' '\n' >> ${OUTPUT_FILE}
            fi
        else
            RECORD_DATA=$(echo $line | awk '{print $5}')
            
            # 對B Server進行查詢
            B_RESULT=$(dig @${B_IP} ${RECORD_TYPE} ${RECORD_NAME} +short)
            
            # 比對結果
            if [ "${RECORD_DATA}" == "${B_RESULT}" ]; then
                echo -e "${SEPARATOR}\n${RECORD_NAME} ${TTL} IN ${RECORD_TYPE} ${RECORD_DATA} 比對ok" >> ${OUTPUT_FILE}
            else
                # 解析並排序多個結果
                A_DATA_SORTED=$(echo "${RECORD_DATA}" | tr ' ' '\n' | sort | tr '\n' ' ')
                B_DATA_SORTED=$(echo "${B_RESULT}" | tr ' ' '\n' | sort | tr '\n' ' ')

                if [ "$A_DATA_SORTED" == "$B_DATA_SORTED" ]; then
                    echo -e "${SEPARATOR}\n${RECORD_NAME} ${TTL} IN ${RECORD_TYPE} ${A_DATA_SORTED} 比對ok" >> ${OUTPUT_FILE}
                else
                    echo -e "${SEPARATOR}\n${RECORD_NAME} DNS紀錄不同於A Server" >> ${OUTPUT_FILE}
                    echo "A Server: ${RECORD_DATA}" >> ${OUTPUT_FILE}
                    echo "B Server: ${B_RESULT}" >> ${OUTPUT_FILE}
                fi
            fi
        fi
    done < a_records_${ZONE}.txt

    # 清理暫存檔案
    rm -f a_records_${ZONE}.txt

done < ${ZONE_FILE}

