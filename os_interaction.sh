#!/bin/bash
# OS Interaction データ削減スクリプト
# Usage: ./scripts/os_interaction_shave.sh [random|fixed] [seed]
# Example: ./scripts/os_interaction_shave.sh random 42

set -e

# ============================================================
# 設定セクション（ここを編集）
# ============================================================

# Dir 1-3, 5-7: 削減率 (0.5 = 50%削減)
DIR1_RATIO=0.5  # 元: 7アイテム
DIR2_RATIO=0.5  # 元: 5アイテム
DIR3_RATIO=0.5  # 元: 6アイテム
DIR5_RATIO=0.5  # 元: 10アイテム
DIR6_RATIO=0.5  # 元: 9アイテム
DIR7_RATIO=0.5  # 元: 88アイテム

# Dir 4: 各ファイルごとの目標アイテム数
declare -A DIR4_TARGETS
DIR4_TARGETS["N4.json"]=1      # 元: 1アイテム
DIR4_TARGETS["N11.json"]=1     # 元: 1アイテム
DIR4_TARGETS["N37.json"]=1     # 元: 1アイテム
DIR4_TARGETS["N41.json"]=2     # 元: 4アイテム
DIR4_TARGETS["N225.json"]=1    # 元: 1アイテム
DIR4_TARGETS["Q09.json"]=1     # 元: 1アイテム
DIR4_TARGETS["Q19.json"]=1     # 元: 1アイテム
DIR4_TARGETS["Q30.json"]=3     # 元: 6アイテム
DIR4_TARGETS["Q47.json"]=1     # 元: 1アイテム
DIR4_TARGETS["Q49.json"]=1     # 元: 2アイテム

# ============================================================
# スクリプト本体（通常は編集不要）
# ============================================================

MODE=${1:-random}
SEED=${2:-42}

if ! command -v jq &> /dev/null; then
    echo "Error: jq is not installed"
    exit 1
fi

echo "=================================="
echo "OS Interaction データ削減"
echo "=================================="
echo "モード:       $MODE"
if [ "$MODE" = "random" ]; then
    echo "シード:       $SEED"
fi
echo "出力先:       data/os_interaction/s_data/"
echo "=================================="

OUTPUT_BASE="data/os_interaction/s_data"
rm -rf "$OUTPUT_BASE"

TOTAL_ORIGINAL=0
TOTAL_REDUCED=0

# ディレクトリ処理関数
process_dir() {
    local DIR_NUM=$1
    local RATIO=$2
    
    INPUT_DIR="data/os_interaction/data/$DIR_NUM"
    OUTPUT_DIR="$OUTPUT_BASE/$DIR_NUM"
    
    if [ ! -d "$INPUT_DIR" ]; then
        echo "Warning: Directory $INPUT_DIR not found"
        return
    fi
    
    mkdir -p "$OUTPUT_DIR"
    
    echo ""
    echo "📁 Dir $DIR_NUM (削減率: ${RATIO}):"
    
    local DIR_ORIGINAL=0
    local DIR_REDUCED=0
    
    for json_file in "$INPUT_DIR"/*.json; do
        if [ ! -f "$json_file" ]; then
            continue
        fi
        
        filename=$(basename "$json_file")
        
        # アイテム数カウント
        if jq -e 'type == "array"' "$json_file" > /dev/null 2>&1; then
            ITEM_COUNT=$(jq 'length' "$json_file")
        else
            ITEM_COUNT=1
        fi
        
        DIR_ORIGINAL=$((DIR_ORIGINAL + ITEM_COUNT))
        
        # 削減後のアイテム数計算
        TARGET_COUNT=$(echo "$ITEM_COUNT * $RATIO" | bc | cut -d'.' -f1)
        
        # 最低1は残す
        if [ "$TARGET_COUNT" -lt 1 ]; then
            TARGET_COUNT=1
        fi
        
        if [ "$TARGET_COUNT" -gt "$ITEM_COUNT" ]; then
            TARGET_COUNT=$ITEM_COUNT
        fi
        
        # サンプリング
        if [ "$ITEM_COUNT" -eq "$TARGET_COUNT" ]; then
            cp "$json_file" "$OUTPUT_DIR/$filename"
        else
            if [ "$MODE" = "random" ]; then
                jq -c '.[]' "$json_file" | shuf --random-source=<(yes $SEED) -n "$TARGET_COUNT" | jq -s '.' > "$OUTPUT_DIR/$filename"
            else
                jq ".[:$TARGET_COUNT]" "$json_file" > "$OUTPUT_DIR/$filename"
            fi
        fi
        
        echo "  $filename: $ITEM_COUNT → $TARGET_COUNT"
        DIR_REDUCED=$((DIR_REDUCED + TARGET_COUNT))
    done
    
    echo "  合計: $DIR_ORIGINAL → $DIR_REDUCED"
    TOTAL_ORIGINAL=$((TOTAL_ORIGINAL + DIR_ORIGINAL))
    TOTAL_REDUCED=$((TOTAL_REDUCED + DIR_REDUCED))
}

# Dir 1-3の処理
process_dir 1 $DIR1_RATIO
process_dir 2 $DIR2_RATIO
process_dir 3 $DIR3_RATIO

# Dir 4の処理（個別設定）
INPUT_DIR="data/os_interaction/data/4"
OUTPUT_DIR="$OUTPUT_BASE/4"

if [ -d "$INPUT_DIR" ]; then
    mkdir -p "$OUTPUT_DIR"
    
    echo ""
    echo "📁 Dir 4 (個別設定):"
    
    DIR_ORIGINAL=0
    DIR_REDUCED=0
    
    for json_file in "$INPUT_DIR"/*.json; do
        if [ ! -f "$json_file" ]; then
            continue
        fi
        
        filename=$(basename "$json_file")
        
        # アイテム数カウント
        if jq -e 'type == "array"' "$json_file" > /dev/null 2>&1; then
            ITEM_COUNT=$(jq 'length' "$json_file")
        else
            ITEM_COUNT=1
        fi
        
        DIR_ORIGINAL=$((DIR_ORIGINAL + ITEM_COUNT))
        
        # 設定から目標数を取得
        if [ -n "${DIR4_TARGETS[$filename]}" ]; then
            TARGET_COUNT="${DIR4_TARGETS[$filename]}"
        else
            # 設定がない場合はそのまま
            TARGET_COUNT=$ITEM_COUNT
            echo "  $filename: $ITEM_COUNT → $TARGET_COUNT (設定なし、保持)"
        fi
        
        # サンプリング
        if [ "$TARGET_COUNT" -ge "$ITEM_COUNT" ]; then
            cp "$json_file" "$OUTPUT_DIR/$filename"
            echo "  $filename: $ITEM_COUNT → $ITEM_COUNT"
            DIR_REDUCED=$((DIR_REDUCED + ITEM_COUNT))
        else
            if [ "$MODE" = "random" ]; then
                jq -c '.[]' "$json_file" | shuf --random-source=<(yes $SEED) -n "$TARGET_COUNT" | jq -s '.' > "$OUTPUT_DIR/$filename"
            else
                jq ".[:$TARGET_COUNT]" "$json_file" > "$OUTPUT_DIR/$filename"
            fi
            echo "  $filename: $ITEM_COUNT → $TARGET_COUNT"
            DIR_REDUCED=$((DIR_REDUCED + TARGET_COUNT))
        fi
    done
    
    echo "  合計: $DIR_ORIGINAL → $DIR_REDUCED"
    TOTAL_ORIGINAL=$((TOTAL_ORIGINAL + DIR_ORIGINAL))
    TOTAL_REDUCED=$((TOTAL_REDUCED + DIR_REDUCED))
fi

# Dir 5-7の処理
process_dir 5 $DIR5_RATIO
process_dir 6 $DIR6_RATIO
process_dir 7 $DIR7_RATIO

echo ""
echo "=================================="
echo "完了"
echo "=================================="
echo "総サンプル数: $TOTAL_ORIGINAL → $TOTAL_REDUCED"
if [ "$TOTAL_ORIGINAL" -gt 0 ]; then
    REDUCTION_PERCENT=$((100 - (TOTAL_REDUCED * 100 / TOTAL_ORIGINAL)))
    echo "削減率: ${REDUCTION_PERCENT}%"
fi
echo ""
echo "設定ファイルでの使用方法:"
echo "  os_interaction-s:"
echo "    data_config:"
echo "      files:"
for i in {1..7}; do
    if [ -d "$OUTPUT_BASE/$i" ]; then
        echo "        - problem_file: data/os_interaction/s_data/$i/*.json"
        echo "          script_dir: data/os_interaction/scripts/$i/"
        echo "          index_prefix: \"s-00$i-\""
    fi
done

