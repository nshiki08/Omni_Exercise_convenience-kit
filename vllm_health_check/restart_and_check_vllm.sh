#!/bin/bash

# 設定: テストするモデル名
MODEL_NAME="Qwen/Qwen3-4B"

echo "=========================================="
echo " vLLM 再起動 & モデル整合性チェック"
echo " Target Model (設定値): $MODEL_NAME"
echo "=========================================="

# 1. 再起動
echo "[1/4] サービスを再起動しています..."
sudo systemctl daemon-reload
sudo systemctl restart vllm

# 2. ステータス表示
echo "[2/4] systemdステータスを確認中..."
sudo systemctl status vllm.service --no-pager | grep "Active:"

# 3. 起動待機 & モデル確認ループ
echo "[3/4] モデルロード完了を待機し、整合性をチェックします..."
echo "      (初回はダウンロードに数分かかる場合があります)"

MAX_RETRIES=30
COUNT=0
ACTUAL_MODEL=""

while [ $COUNT -lt $MAX_RETRIES ]; do
    # v1/models を叩いてレスポンスを取得
    RESPONSE=$(curl -s http://localhost:8000/v1/models)

    # curlが成功し、かつJSONっぽいレスポンス(object="list")が返ってきたか簡易チェック
    if echo "$RESPONSE" | grep -q "object"; then
        echo ""
        echo " -> サーバー接続成功！モデル情報を取得しました。"

        # Pythonを使ってJSONからモデルIDを抽出 (jqコマンド依存を避けるためPythonを使用)
        ACTUAL_MODEL=$(echo "$RESPONSE" | python3 -c "import sys, json; print(json.load(sys.stdin)['data'][0]['id'])" 2>/dev/null)
        break
    fi

    # まだ繋がらない場合
    echo -n "."
    sleep 10
    COUNT=$((COUNT+1))
done

# タイムアウト判定
if [ $COUNT -eq $MAX_RETRIES ]; then
    echo ""
    echo "❌ タイムアウトしました。"
    echo "ログを確認してください: sudo journalctl -u vllm.service -n 50"
    exit 1
fi

# --- ここが追加機能：モデル名の整合性チェック ---
echo "------------------------------------------"
echo "【モデル整合性チェック】"
echo "  期待するモデル: $MODEL_NAME"
echo "  実際のモデル  : $ACTUAL_MODEL"

if [ "$MODEL_NAME" != "$ACTUAL_MODEL" ]; then
    echo ""
    echo "⚠️  WARNING: モデルが一致しません！ ⚠️"
    echo "systemdの起動コマンド(--model引数)が古いか、環境変数が間違っている可能性があります。"
    echo "意図したテストにならないため、処理を中断します。"
    exit 1
else
    echo "✅ モデル一致確認。テストを続行します。"
fi
echo "------------------------------------------"
# ------------------------------------------------

# 4. 推論テスト
echo ""
echo "[4/4] 推論テストを実行します..."
RESPONSE=$(curl -s -X POST http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d "{
    \"model\": \"$MODEL_NAME\",
    \"messages\": [{\"role\": \"user\", \"content\": \"Hello!\"}],
    \"max_tokens\": 20
  }")

# 結果表示
echo "レスポンス:"
echo $RESPONSE | grep -o '"content":".*"'
echo "=========================================="
echo "完了"
