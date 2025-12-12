#!/bin/bash
# ia_stream_upload_checked.sh

ROOT_URL="https://mirrors.lolinet.com/firmware/lenowow/2025/"
COLLECTION="lenovo-mobile-devices-firmware-2025"
LIST_FILE="$HOME/ia_project/file_list.txt"
LOG_DIR="$HOME/ia_project/logs"
TMP_DIR="$HOME/ia_project/tmp"

mkdir -p "$LOG_DIR" "$TMP_DIR"

if [[ -z "$ROOT_URL" || -z "$COLLECTION" ]]; then
    echo "Usage: $0 <ia_collection>"
    exit 1
fi

while read -r url; do
    [[ -z "$url" || "$url" =~ ^# ]] && continue

    # 生成 _ 前缀文件名
    REL_PATH=${url#"$ROOT_URL"}
    PREFIXED_FILE=$(echo "$REL_PATH" | sed 's|/|_|g')
    TMP_FILE="$TMP_DIR/$PREFIXED_FILE"

    echo ">>> 下载: $url -> $TMP_FILE"
    if ! curl -L "$url" -o "$TMP_FILE"; then
        echo "!!! 下载失败: $url" | tee "$LOG_DIR/${PREFIXED_FILE}.log"
        continue
    fi

    # 下载校验（文件大小>0）
    if [[ ! -s "$TMP_FILE" ]]; then
        echo "!!! 下载校验失败: 文件为空 $TMP_FILE" | tee -a "$LOG_DIR/${PREFIXED_FILE}.log"
        rm -f "$TMP_FILE"
        continue
    fi

    echo ">>> 上传: $TMP_FILE -> $PREFIXED_FILE"
    if ! ia upload "$COLLECTION" "$TMP_FILE" \
            --metadata="mediatype:software" \
            --metadata="collection:$COLLECTION" \
            --retries=3 &>> "$LOG_DIR/${PREFIXED_FILE}.log"; then
        echo "!!! 上传失败: $PREFIXED_FILE" | tee -a "$LOG_DIR/${PREFIXED_FILE}.log"
        rm -f "$TMP_FILE"
        continue
    fi

    # 上传校验（文件大小）
    SIZE_LOCAL=$(stat -c%s "$TMP_FILE")
    SIZE_REMOTE=$(ia metadata "$COLLECTION" "$PREFIXED_FILE" | jq '.files[0].size')
    if [[ "$SIZE_LOCAL" -ne "$SIZE_REMOTE" ]]; then
        echo "!!! 上传校验失败: $PREFIXED_FILE (local=$SIZE_LOCAL, remote=$SIZE_REMOTE)" \
            | tee -a "$LOG_DIR/${PREFIXED_FILE}.log"
    else
        echo ">>> 上传校验通过: $PREFIXED_FILE" | tee -a "$LOG_DIR/${PREFIXED_FILE}.log"
    fi

    rm -f "$TMP_FILE"

done < "$LIST_FILE"

echo "=== 所有文件处理完成 ==="
