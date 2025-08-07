#!/bin/bash
# Claude Code 启动脚本
# 自动加载.env文件中的环境变量并启动Claude Code

# 检查.env文件是否存在
if [ ! -f ".env" ]; then
    echo "错误：.env文件不存在！"
    exit 1
fi

# 加载环境变量，只处理有效的变量定义
while IFS= read -r line; do
    # 跳过注释行和空行
    if [[ $line =~ ^[[:space:]]*# ]] || [[ -z "$line" ]]; then
        continue
    fi
    
    # 检查是否包含等号且格式正确
    if [[ $line =~ ^[A-Za-z_][A-Za-z0-9_]*= ]]; then
        # 移除行内注释
        clean_line=$(echo "$line" | sed 's/[[:space:]]*#.*$//')
        export "$clean_line"
    fi
done < .env

# 检查必需的环境变量
if [ -z "$ANTHROPIC_AUTH_TOKEN" ]; then
    echo "错误：ANTHROPIC_AUTH_TOKEN 未设置！"
    exit 1
fi

if [ -z "$ANTHROPIC_BASE_URL" ]; then
    echo "错误：ANTHROPIC_BASE_URL 未设置！"
    exit 1
fi

echo "✅ 环境变量已加载："
echo "   ANTHROPIC_BASE_URL: $ANTHROPIC_BASE_URL"
echo "   ANTHROPIC_AUTH_TOKEN: ${ANTHROPIC_AUTH_TOKEN:0:10}..."
echo ""

# 如果是测试连接
if [ "$1" = "--test" ]; then
    echo "🔍 测试Claude Code连接..."
    echo "正在测试Claude Code与API的连接..."
    timeout 10 claude --print "Hello, just testing connection" 2>/dev/null \
    && echo "✅ Claude Code连接正常" \
    || echo "❌ Claude Code连接超时或失败"
    exit 0
fi

# 启动Claude Code
echo "🚀 启动 Claude Code..."
claude "$@"
