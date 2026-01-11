#!/bin/bash

# ==========================================
# AgentBench サービス管理スクリプト
# 使用法: 
#   ./manage_agentbench.sh          -> 状態確認のみ
#   ./manage_agentbench.sh -r       -> 再起動してから確認
# ==========================================

# 対象サービスリスト
SERVICES=(
    "agentbench-controller.service"
    "agentbench-worker-alfworld.service"
    "agentbench-worker-webshop.service"
    "agentbench-worker-dbbench.service"
    "agentbench-worker-os-interaction.service"
)

# 引数のチェック
MODE="CHECK"
if [[ "$1" == "-r" || "$1" == "--restart" ]]; then
    MODE="RESTART"
fi

echo "=========================================="
if [ "$MODE" == "RESTART" ]; then
    echo " 🔄 AgentBench サービス再起動 & 状態確認"
else
    echo " 🔍 AgentBench サービス状態確認 (死活監視)"
fi
echo "=========================================="

for SERVICE in "${SERVICES[@]}"; do
    echo ""
    echo "▶ Target: $SERVICE"

    # --- 再起動モードの場合の処理 ---
    if [ "$MODE" == "RESTART" ]; then
        echo "   [Restarting...] 再起動コマンド送信中..."
        if sudo systemctl restart $SERVICE; then
            echo "   -> 再起動コマンド送信成功。起動を待機します(3秒)..."
            sleep 3
        else
            echo "❌ -> 再起動コマンドの送信に失敗しました。"
        fi
    fi

    # --- ステータス確認処理 ---
    # is-active で稼働判定
    if systemctl is-active --quiet $SERVICE; then
        echo "   ✅ STATUS: RUNNING (正常稼働)"
        
        # 詳細ログを表示 (直近5行)
        echo "   --- Recent Logs ---"
        sudo journalctl -u $SERVICE -n 5 --no-pager | sed 's/^/      /'
    else
        echo "   ❌ STATUS: STOPPED or FAILED (停止/異常)"
        
        # エラー時は多めにログを表示
        echo "   --- Recent Logs (Error Check) ---"
        sudo journalctl -u $SERVICE -n 15 --no-pager | sed 's/^/      /'
    fi
    echo "------------------------------------------"
done

echo ""
if [ "$MODE" == "RESTART" ]; then
    echo "全ての再起動と確認が完了しました。"
else
    echo "状態確認が完了しました。再起動するには '-r' を付けて実行してください。"
fi
