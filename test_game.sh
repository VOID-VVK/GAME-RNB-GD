#!/bin/bash

# 游戏自动测试脚本

echo "=== 开始游戏测试 ==="
echo ""

# 运行游戏
godot --path /Users/void/Documents/GAME-RNB-GD --run > /tmp/game_test_full.log 2>&1 &
GAME_PID=$!

echo "游戏已启动 (PID: $GAME_PID)"
echo "等待 10 秒后自动关闭..."
sleep 10

# 关闭游戏
kill $GAME_PID 2>/dev/null
wait $GAME_PID 2>/dev/null

echo ""
echo "=== 测试结果 ==="
echo ""

# 检查错误
ERROR_COUNT=$(grep -c "ERROR:" /tmp/game_test_full.log 2>/dev/null || echo "0")
WARNING_COUNT=$(grep -c "WARNING:" /tmp/game_test_full.log 2>/dev/null || echo "0")

echo "错误数量: $ERROR_COUNT"
echo "警告数量: $WARNING_COUNT"
echo ""

if [ "$ERROR_COUNT" -eq 0 ]; then
    echo "✓ 没有错误！"
else
    echo "✗ 发现错误："
    grep "ERROR:" /tmp/game_test_full.log | head -10
fi

echo ""
echo "=== 关键日志 ==="
grep -E "===|进入|切换|战斗|玩家|怪物" /tmp/game_test_full.log | head -30

echo ""
echo "完整日志保存在: /tmp/game_test_full.log"
