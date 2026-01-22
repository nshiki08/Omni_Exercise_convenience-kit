#!/bin/bash
# ALFWorld データ削減スクリプト
# Usage: ./scripts/alfworld_shave.sh <samples_per_type> [random|fixed] [seed]
# Example: ./scripts/alfworld_shave.sh 4 random 42
# Example: ./scripts/alfworld_shave.sh 2 fixed

set -e

# デフォルト値
SAMPLES_PER_TYPE=${1:-4}
MODE=${2:-random}
SEED=${3:-42}

# ファイルパス
INPUT_FILE="data/alfworld/standard.json"
OUTPUT_FILE="data/alfworld/s_${SAMPLES_PER_TYPE}.json"

# 入力ファイルの存在確認
if [ ! -f "$INPUT_FILE" ]; then
    echo "Error: $INPUT_FILE not found"
    exit 1
fi

# jqの存在確認
if ! command -v jq &> /dev/null; then
    echo "Error: jq is not installed. Please install jq."
    exit 1
fi

echo "=================================="
echo "ALFWorld データ削減"
echo "=================================="
echo "入力:            $INPUT_FILE"
echo "各タイプから:    $SAMPLES_PER_TYPE サンプル"
echo "モード:          $MODE"
if [ "$MODE" = "random" ]; then
    echo "シード:          $SEED"
fi
echo "出力:            $OUTPUT_FILE"
echo "=================================="

# タスクタイプ一覧
TASK_TYPES=(
    "pick_and_place"
    "pick_clean_then_place"
    "pick_heat_then_place"
    "pick_cool_then_place"
    "look_at_obj"
    "pick_two_obj"
)

# 一時ディレクトリ作成
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

# 各タスクタイプごとに処理
echo ""
echo "各タスクタイプの処理:"
for TASK_TYPE in "${TASK_TYPES[@]}"; do
    # 元のサンプル数取得
    TOTAL=$(jq -r ".$TASK_TYPE | length" "$INPUT_FILE")
    
    # サンプル数チェック
    if [ "$SAMPLES_PER_TYPE" -gt "$TOTAL" ]; then
        echo "  $TASK_TYPE: $TOTAL サンプル → $TOTAL サンプル (全て使用)"
        ACTUAL_SAMPLES=$TOTAL
    else
        echo "  $TASK_TYPE: $TOTAL サンプル → $SAMPLES_PER_TYPE サンプル"
        ACTUAL_SAMPLES=$SAMPLES_PER_TYPE
    fi
    
    # タスクタイプのデータを抽出して一時ファイルに保存
    jq -r ".$TASK_TYPE[]" "$INPUT_FILE" > "$TEMP_DIR/${TASK_TYPE}_all.txt"
    
    # サンプリング
    if [ "$MODE" = "random" ]; then
        # ランダムサンプリング
        shuf --random-source=<(yes $SEED) -n "$ACTUAL_SAMPLES" "$TEMP_DIR/${TASK_TYPE}_all.txt" > "$TEMP_DIR/${TASK_TYPE}_sampled.txt"
    elif [ "$MODE" = "fixed" ]; then
        # 固定サンプリング（先頭からN個）
        head -n "$ACTUAL_SAMPLES" "$TEMP_DIR/${TASK_TYPE}_all.txt" > "$TEMP_DIR/${TASK_TYPE}_sampled.txt"
    else
        echo "Error: Unknown mode '$MODE'. Use 'random' or 'fixed'"
        exit 1
    fi
done

# JSON形式で結合
echo ""
echo "JSONファイル生成中..."
echo "{" > "$OUTPUT_FILE"

FIRST=true
for TASK_TYPE in "${TASK_TYPES[@]}"; do
    if [ "$FIRST" = true ]; then
        FIRST=false
    else
        echo "," >> "$OUTPUT_FILE"
    fi
    
    echo -n "  \"$TASK_TYPE\": [" >> "$OUTPUT_FILE"
    
    # サンプルを配列形式で追加
    FIRST_ITEM=true
    while IFS= read -r line; do
        if [ "$FIRST_ITEM" = true ]; then
            FIRST_ITEM=false
            echo "" >> "$OUTPUT_FILE"
        else
            echo "," >> "$OUTPUT_FILE"
        fi
        echo -n "    \"$line\"" >> "$OUTPUT_FILE"
    done < "$TEMP_DIR/${TASK_TYPE}_sampled.txt"
    
    echo "" >> "$OUTPUT_FILE"
    echo -n "  ]" >> "$OUTPUT_FILE"
done

echo "" >> "$OUTPUT_FILE"
echo "}" >> "$OUTPUT_FILE"

# 総サンプル数計算
TOTAL_SAMPLES=0
for TASK_TYPE in "${TASK_TYPES[@]}"; do
    COUNT=$(wc -l < "$TEMP_DIR/${TASK_TYPE}_sampled.txt")
    TOTAL_SAMPLES=$((TOTAL_SAMPLES + COUNT))
done

echo ""
echo "✓ Created: $OUTPUT_FILE"
echo "  Total samples: $TOTAL_SAMPLES"
if [ "$MODE" = "random" ]; then
    echo "  Random sampling with seed=$SEED"
else
    echo "  Fixed sampling (first N from each type)"
fi

echo "=================================="
echo "完了"
echo "=================================="
echo ""
echo "設定ファイルでの使用方法:"
echo "  alfworld-s${SAMPLES_PER_TYPE}:"
echo "    parameters:"
echo "      name: alfworld-s${SAMPLES_PER_TYPE}"
echo "      split: \"s_${SAMPLES_PER_TYPE}\""
