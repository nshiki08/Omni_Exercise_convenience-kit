#!/bin/bash
# DBBench データ削減スクリプト
# Usage: ./scripts/db_bench_shave.sh <sample_size> [random|fixed] [seed]
# Example: ./scripts/db_bench_shave.sh 150 random 42
# Example: ./scripts/db_bench_shave.sh 100 fixed

set -e

# デフォルト値
SAMPLE_SIZE=${1:-150}
MODE=${2:-random}  # random or fixed
SEED=${3:-42}

# ファイルパス
INPUT_FILE="data/dbbench/standard.jsonl"
OUTPUT_FILE="data/dbbench/s_${SAMPLE_SIZE}.jsonl"

# 入力ファイルの存在確認
if [ ! -f "$INPUT_FILE" ]; then
    echo "Error: $INPUT_FILE not found"
    exit 1
fi

# 総行数取得
TOTAL_LINES=$(wc -l < "$INPUT_FILE")

echo "=================================="
echo "DBBench データ削減"
echo "=================================="
echo "入力:        $INPUT_FILE"
echo "総サンプル数: $TOTAL_LINES"
echo "削減後:      $SAMPLE_SIZE サンプル"
echo "モード:      $MODE"
if [ "$MODE" = "random" ]; then
    echo "シード:      $SEED"
fi
echo "出力:        $OUTPUT_FILE"
echo "=================================="

# サンプル数チェック
if [ "$SAMPLE_SIZE" -gt "$TOTAL_LINES" ]; then
    echo "Error: Sample size ($SAMPLE_SIZE) exceeds total lines ($TOTAL_LINES)"
    exit 1
fi

# サンプリング実行
if [ "$MODE" = "random" ]; then
    # ランダムサンプリング（shufコマンド使用）
    shuf --random-source=<(yes $SEED) -n "$SAMPLE_SIZE" "$INPUT_FILE" > "$OUTPUT_FILE"
    echo "✓ Created: $OUTPUT_FILE"
    echo "  Sampled $SAMPLE_SIZE/$TOTAL_LINES lines ($((SAMPLE_SIZE*100/TOTAL_LINES))%)"
    echo "  Random sampling with seed=$SEED"
elif [ "$MODE" = "fixed" ]; then
    # 固定サンプリング（先頭からN行）
    head -n "$SAMPLE_SIZE" "$INPUT_FILE" > "$OUTPUT_FILE"
    echo "✓ Created: $OUTPUT_FILE"
    echo "  Sampled $SAMPLE_SIZE/$TOTAL_LINES lines ($((SAMPLE_SIZE*100/TOTAL_LINES))%)"
    echo "  Fixed sampling (first $SAMPLE_SIZE lines)"
else
    echo "Error: Unknown mode '$MODE'. Use 'random' or 'fixed'"
    exit 1
fi

echo "=================================="
echo "完了"
echo "=================================="
echo ""
echo "設定ファイルでの使用方法:"
echo "  dbbench-s${SAMPLE_SIZE}:"
echo "    parameters:"
echo "      name: dbbench-s${SAMPLE_SIZE}"
echo "      data_file: \"data/dbbench/s_${SAMPLE_SIZE}.jsonl\""

