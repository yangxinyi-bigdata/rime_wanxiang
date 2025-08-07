# Rime Lua API 正确使用指南

## 配置读取最佳实践

根据 Rime 官方文档，我们现在使用正确的 API 方法来读取配置。

### ConfigMap 遍历

**正确的方法：**
```lua
local chat_triggers_config = config:get_map("ai_assistant/chat_triggers")
if chat_triggers_config then
    -- 使用 keys() 方法获取所有键名
    local trigger_keys = chat_triggers_config:keys()
    logger.info("找到 " .. #trigger_keys .. " 个触发器配置")
    
    -- 遍历所有键
    for _, trigger_name in ipairs(trigger_keys) do
        local trigger_value = config:get_string("ai_assistant/chat_triggers/" .. trigger_name)
        -- 处理配置值...
    end
else
    logger.warn("未找到 chat_triggers 配置")
end
```

**之前错误的方法：**
```lua
-- ❌ 这些方法不存在于 Rime Lua API 中
local iter = chat_triggers_config:begin()
while not iter:exhausted() do
    local trigger_name = iter:get_key()
    iter:next()
end
```

### ConfigMap 属性和方法

根据文档，`ConfigMap` 具有以下属性和方法：

**属性：**
- `size`: number - 映射大小
- `type`: string - 类型标识，如 "kMap"

**方法：**
- `keys()`: table - 返回所有键名的数组
- `get(key)`: ConfigItem - 获取指定键的配置项
- `get_value(key)`: ConfigValue - 获取指定键的配置值
- `has_key(key)`: boolean - 检查是否存在指定键
- `empty()`: boolean - 检查是否为空
- `clear()` - 清空映射

### 实际应用示例

**读取完整的 AI 助手配置：**
```lua
-- 1. 获取 chat_triggers 映射
local chat_triggers_config = config:get_map("ai_assistant/chat_triggers")
if chat_triggers_config and not chat_triggers_config:empty() then
    local trigger_keys = chat_triggers_config:keys()
    
    for _, trigger_name in ipairs(trigger_keys) do
        -- 2. 读取触发器前缀
        local trigger_prefix = config:get_string("ai_assistant/chat_triggers/" .. trigger_name)
        
        -- 3. 读取回复消息
        local reply_message = config:get_string("ai_assistant/reply_messages/" .. trigger_name)
        
        -- 4. 读取回复标签
        local reply_tag = config:get_string("ai_assistant/reply_tags/" .. trigger_name)
        
        -- 5. 存储到环境配置中
        if trigger_prefix then
            env.ai_assistant_config.chat_triggers[trigger_name] = trigger_prefix
            logger.info("加载触发器: " .. trigger_name .. " -> " .. trigger_prefix)
        end
        
        if reply_message then
            env.ai_assistant_config.reply_messages[trigger_name] = reply_message
        end
        
        if reply_tag then
            env.ai_assistant_config.reply_tags[trigger_name] = reply_tag
        end
    end
else
    logger.warn("chat_triggers 配置为空或不存在")
end
```

### 配置检查和验证

**检查配置是否存在：**
```lua
-- 检查配置路径是否存在
if not config:is_null("ai_assistant/chat_triggers") then
    local chat_triggers = config:get_map("ai_assistant/chat_triggers")
    if chat_triggers and chat_triggers:has_key("simple_ai_chat") then
        local prefix = config:get_string("ai_assistant/chat_triggers/simple_ai_chat")
        logger.info("简单对话触发器: " .. prefix)
    end
end
```

**检查配置类型：**
```lua
-- 确保配置是映射类型
if config:is_map("ai_assistant/chat_triggers") then
    local triggers = config:get_map("ai_assistant/chat_triggers")
    logger.info("chat_triggers 是映射类型，包含 " .. triggers.size .. " 个触发器")
else
    logger.error("chat_triggers 不是映射类型")
end
```

### 错误处理

**健壮的配置读取：**
```lua
local function load_ai_config(config, env)
    env.ai_assistant_config = {}
    env.ai_assistant_config.chat_triggers = {}
    env.ai_assistant_config.reply_messages = {}
    env.ai_assistant_config.reply_tags = {}
    
    -- 检查 AI 助手是否启用
    if not config:get_bool("ai_assistant/enabled") then
        logger.info("AI 助手未启用")
        return false
    end
    
    -- 读取触发器配置
    if not config:is_map("ai_assistant/chat_triggers") then
        logger.error("chat_triggers 配置不是映射类型")
        return false
    end
    
    local chat_triggers = config:get_map("ai_assistant/chat_triggers")
    if not chat_triggers or chat_triggers:empty() then
        logger.warn("chat_triggers 配置为空")
        return false
    end
    
    local trigger_keys = chat_triggers:keys()
    logger.info("开始加载 " .. #trigger_keys .. " 个触发器")
    
    for _, trigger_name in ipairs(trigger_keys) do
        local success, error_msg = pcall(function()
            local prefix = config:get_string("ai_assistant/chat_triggers/" .. trigger_name)
            local message = config:get_string("ai_assistant/reply_messages/" .. trigger_name)
            local tag = config:get_string("ai_assistant/reply_tags/" .. trigger_name)
            
            if prefix then
                env.ai_assistant_config.chat_triggers[trigger_name] = prefix
                env.ai_assistant_config.reply_messages[trigger_name] = message or (prefix .. " AI")
                env.ai_assistant_config.reply_tags[trigger_name] = tag or trigger_name
                logger.info("✓ 加载触发器: " .. trigger_name)
            else
                logger.warn("✗ 触发器前缀为空: " .. trigger_name)
            end
        end)
        
        if not success then
            logger.error("加载触发器失败: " .. trigger_name .. " - " .. error_msg)
        end
    end
    
    return true
end
```

### 性能优化建议

1. **一次性读取**：在初始化时一次性读取所有配置，避免重复调用
2. **配置缓存**：将配置存储在 `env` 中，避免重复解析
3. **错误处理**：使用 `pcall` 保护配置读取过程
4. **日志记录**：详细记录配置加载过程，便于调试

### 总结

使用正确的 Rime Lua API：
- ✅ `config:get_map()` 获取配置映射
- ✅ `map:keys()` 获取所有键名
- ✅ `config:get_string()` 获取字符串值
- ✅ `config:is_map()` 检查类型
- ❌ 避免使用不存在的迭代器方法

这样可以确保代码的兼容性和稳定性。
