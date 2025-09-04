#!/bin/bash
# ia_up.sh - Upload files listed in file_list.txt to Internet Archive

ROOT_URL="https://mirrors-obs-2.lolinet.com/firmware/nec/"  # Root URL for prefixing
COLLECTION="nec-mobile-devices-firmware-2018-2019"  # IA collection name
LIST_FILE="$HOME/ia_project/file_list.txt"
LOG_DIR="$HOME/ia_project/logs"

mkdir -p "$LOG_DIR"

if [[ -z "$ROOT_URL" || -z "$COLLECTION" ]]; then
    echo "Usage: $0 <ia_collection>"
    exit 1
fi

while read -r url; do
    [[ -z "$url" || "$url" =~ ^# ]] && continue

    # Generate prefixed file name
    REL_PATH="${url#"$ROOT_URL"}"
    PREFIXED_FILE=$(echo "$REL_PATH" | tr '/' '_' | sed 's/^_//')

    echo ">>> Uploading: $url -> $PREFIXED_FILE"

    TMP_FILE=$(mktemp)

    # Download file to temporary file
    curl -sL "$url" -o "$TMP_FILE"
    if [[ $? -ne 0 ]]; then
        echo "!!! Download failed: $url"
        continue
    fi

    # Upload to IA
    ia upload "$COLLECTION" "$PREFIXED_FILE" \
       --metadata="mediatype:software" \
       --metadata="collection:$COLLECTION" \
       --retries=3 \
       &> "$LOG_DIR/${PREFIXED_FILE}.log"

    if [[ $? -eq 0 ]]; then
        echo ">>> Upload succeeded: $PREFIXED_FILE"
    else
        echo "!!! Upload failed: $PREFIXED_FILE (see log $LOG_DIR/${PREFIXED_FILE}.log)"
    fi

    # Remove temporary file
    rm -f "$TMP_FILE"

done < "$LIST_FILE"

echo "=== All files processed ==="
