#!/bin/bash

# ==========================================
# 設定: ここに「期待するモデル名」を書く
EXPECTED_MODEL="Qwen/Qwen3-4B"
# ==========================================

URL="http://localhost:8000/v1/models"

echo "Checking vLLM status without restart..."

# 1. サーバーが応答するか確認
if ! curl -s "$URL" > /dev/null; then
    echo ""
    echo "❌ [ERROR] サーバーに応答がありません。"
    echo "   vLLMが起動していないか、クラッシュしています。"
    exit 1
fi

# 2. 現在のモデル名を取得
# PythonワンライナーでJSONパース
RESPONSE=$(curl -s "$URL")
CURRENT_MODEL=$(echo "$RESPONSE" | python3 -c "import sys, json; print(json.load(sys.stdin)['data'][0]['id'])" 2>/dev/null)

# 3. 判定ロジック
echo "----------------------------------------"
echo "  期待するモデル : $EXPECTED_MODEL"
echo "  稼働中のモデル : $CURRENT_MODEL"
echo "----------------------------------------"

if [ "$EXPECTED_MODEL" = "$CURRENT_MODEL" ]; then
    echo "✅ [OK] モデルは一致しています。"
    echo "   ベンチマークを開始しても安全です。"
    exit 0
else
    echo "⚠️  [MISMATCH] モデルが違います！"
    echo "   期待値と異なるモデルがロードされています。"
    echo "   ベンチマークを実行する前に設定を見直して再起動してください。"
    exit 1
fi
