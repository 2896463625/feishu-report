#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL_DIR="$SCRIPT_DIR/skills/feishu-report"
DATA_FILE="/tmp/lark_report_data_$(date +%Y%m%d_%H%M%S).json"
REPORT_FILE="/tmp/lark_report_$(date +%Y%m%d_%H%M%S).md"

MODE="${1:-daily}"
CHAT_ID="${2:-}"

echo "=========================================="
echo "  📋 飞书智能日报/周报生成器"
echo "  模式: $MODE | 时间: $(date '+%Y-%m-%d %H:%M')"
echo "=========================================="
echo ""

echo "[1/3] 正在采集工作数据..."
python3 "$SKILL_DIR/scripts/collect.py" --mode "$MODE" > "$DATA_FILE" 2>&1
echo ""

echo "[2/3] 正在生成报告..."
python3 "$SKILL_DIR/scripts/generate.py" --data "$DATA_FILE" --output "$REPORT_FILE"
echo ""

if [ -n "$CHAT_ID" ]; then
    echo "[3/3] 正在发布报告（文档 + 群聊）..."
    python3 "$SKILL_DIR/scripts/publish.py" --report "$REPORT_FILE" --mode both --chat-id "$CHAT_ID"
else
    echo "[3/3] 正在发布报告（文档）..."
    python3 "$SKILL_DIR/scripts/publish.py" --report "$REPORT_FILE" --mode doc
fi

echo ""
echo "=========================================="
echo "  ✅ 报告生成完成！"
echo "  数据文件: $DATA_FILE"
echo "  报告文件: $REPORT_FILE"
echo "=========================================="

rm -f "$DATA_FILE"
