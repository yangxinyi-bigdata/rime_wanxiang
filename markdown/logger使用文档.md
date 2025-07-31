# Rime 日志工具使用文档

## 概述

`logger.lua` 是为 Rime 输入法开发的统一日志记录工具模块，提供了灵活的日志输出控制功能。

## 功能特性

- **多种输出模式**：支持统一日志文件和分离日志文件两种模式
- **日志级别控制**：支持 DEBUG、INFO、WARN、ERROR 四个级别的过滤
- **控制台输出**：可选择同时输出到控制台，便于调试
- **灵活配置**：支持自定义日志目录、文件名、时间戳格式等

## 日志级别

日志级别按优先级从低到高排列：

| 级别  | 数值 | 用途           |
|-------|------|----------------|
| DEBUG | 1    | 调试信息       |
| INFO  | 2    | 一般信息       |
| WARN  | 3    | 警告信息       |
| ERROR | 4    | 错误信息       |

**注意**：只有大于等于设置级别的日志才会被输出。例如，设置为 `INFO` 级别时，`DEBUG` 级别的日志不会输出。

## 基本使用

### 1. 引入模块

```lua
local logger = require("logger")
```

### 2. 创建日志记录器

```lua
-- 使用默认配置创建
local log = logger.create("my_module")

-- 使用自定义配置创建
local log = logger.create("my_module", {
    enabled = true,
    log_level = "DEBUG",
    console_output = true
})
```

### 3. 记录日志

```lua
-- 使用便捷函数
log.debug("这是调试信息")
log.info("这是普通信息")
log.warn("这是警告信息")
log.error("这是错误信息")

-- 使用通用写入函数
log.write("自定义消息", "INFO")
```

## 配置管理

### 全局配置设置

```lua
local logger = require("logger")

-- 设置日志级别（全局）
logger.set_log_level("DEBUG")  -- 输出所有级别
logger.set_log_level("INFO")   -- 输出 INFO、WARN、ERROR
logger.set_log_level("WARN")   -- 输出 WARN、ERROR
logger.set_log_level("ERROR")  -- 只输出 ERROR

-- 设置统一日志模式
logger.set_unified_mode(true, "all_modules.log")  -- 所有模块输出到同一文件
logger.set_unified_mode(false)  -- 每个模块使用独立文件

-- 设置控制台输出
logger.set_console_output(true)   -- 同时输出到控制台
logger.set_console_output(false)  -- 只输出到文件

-- 获取当前配置
local config = logger.get_config()
print("当前日志级别:", config.log_level)
```

### 单个记录器配置

```lua
-- 创建时传入配置
local log = logger.create("my_module", {
    enabled = true,           -- 是否启用日志
    log_level = "DEBUG",      -- 日志级别
    console_output = true,    -- 是否输出到控制台
    unique_file_log = false,      -- 是否使用统一日志文件
    log_dir = "/custom/path/" -- 自定义日志目录
})
```

## 实际使用示例

### 示例 1：基础使用

```lua
-- aux_code_filter.lua
local logger = require("logger")
local log = logger.create("aux_code_filter")

function some_function()
    log.info("开始处理辅助码过滤")
    
    local success, result = pcall(function()
        -- 一些可能出错的操作
        return process_data()
    end)
    
    if success then
        log.debug("处理成功，结果: " .. tostring(result))
    else
        log.error("处理失败: " .. tostring(result))
    end
    
    log.info("辅助码过滤处理完成")
end
```

### 示例 2：调试模式

```lua
-- 在开发调试时
local logger = require("logger")

-- 设置为调试级别，并启用控制台输出
logger.set_log_level("DEBUG")
logger.set_console_output(true)

local log = logger.create("debug_module")

log.debug("这条消息会显示在控制台和文件中")
log.info("普通信息")
log.warn("警告信息")
log.error("错误信息")
```

### 示例 3：生产环境配置

```lua
-- 在生产环境中
local logger = require("logger")

-- 只记录警告和错误
logger.set_log_level("WARN")
-- 不输出到控制台
logger.set_console_output(false)
-- 使用统一日志文件
logger.set_unified_mode(true, "production.log")

local log = logger.create("production_module")

log.debug("这条消息不会被记录")  -- 级别太低
log.info("这条消息不会被记录")   -- 级别太低
log.warn("这条警告会被记录")     -- 会被记录
log.error("这条错误会被记录")    -- 会被记录
```

### 示例 4：条件日志记录

```lua
local logger = require("logger")
local log = logger.create("conditional_module")

function process_items(items)
    log.info("开始处理 " .. #items .. " 个项目")
    
    for i, item in ipairs(items) do
        -- 只在调试模式下记录详细信息
        log.debug("处理第 " .. i .. " 个项目: " .. tostring(item))
        
        local result = process_single_item(item)
        
        if not result then
            log.warn("项目 " .. i .. " 处理失败")
        end
    end
    
    log.info("所有项目处理完成")
end
```

### 示例 5：错误处理和恢复

```lua
local logger = require("logger")
local log = logger.create("error_handler")

function safe_operation()
    log.info("开始执行安全操作")
    
    local max_retries = 3
    local retry_count = 0
    
    while retry_count < max_retries do
        retry_count = retry_count + 1
        log.debug("尝试第 " .. retry_count .. " 次操作")
        
        local success, error_msg = pcall(risky_operation)
        
        if success then
            log.info("操作成功完成")
            return true
        else
            log.warn("第 " .. retry_count .. " 次尝试失败: " .. tostring(error_msg))
            
            if retry_count >= max_retries then
                log.error("所有尝试都失败了，放弃操作")
                return false
            end
            
            -- 等待一段时间后重试
            os.execute("sleep 1")
        end
    end
end
```

## 日志文件管理

### 清空日志文件

```lua
local log = logger.create("my_module")

-- 清空当前模块的日志文件
local success = log.clear()
if success then
    print("日志文件已清空")
else
    print("清空日志文件失败")
end
```

### 日志文件位置

- **统一模式**：`/Users/yangxinyi/Library/Rime/log/all_modules.log`
- **分离模式**：`/Users/yangxinyi/Library/Rime/log/{模块名}.log`

## 最佳实践

### 1. 日志级别使用建议

- **DEBUG**：详细的执行流程、变量值、中间结果
- **INFO**：重要的业务操作、状态变化
- **WARN**：可能的问题、降级操作、资源不足
- **ERROR**：明确的错误、异常、失败操作

### 2. 性能考虑

```lua
-- 避免在循环中使用 DEBUG 级别（除非必要）
for i = 1, 10000 do
    -- 不推荐：每次循环都写日志
    -- log.debug("处理第 " .. i .. " 项")
    
    process_item(i)
end

-- 推荐：批量记录或定期记录
log.debug("开始批量处理 10000 个项目")
for i = 1, 10000 do
    process_item(i)
    
    -- 每 1000 个记录一次进度
    if i % 1000 == 0 then
        log.debug("已处理 " .. i .. " 个项目")
    end
end
log.debug("批量处理完成")
```

### 3. 敏感信息保护

```lua
-- 避免记录敏感信息
local password = "secret123"
log.debug("用户登录，密码: " .. password)  -- 不安全

-- 推荐做法
log.debug("用户登录验证")
if validate_password(password) then
    log.info("用户登录成功")
else
    log.warn("用户登录失败")
end
```

## 故障排除

### 常见问题

1. **日志文件没有创建**
   - 检查日志目录是否存在且有写入权限
   - 确认 `enabled` 配置为 `true`

2. **某些级别的日志没有输出**
   - 检查当前设置的日志级别
   - 确认消息级别不低于设置级别

3. **日志文件太大**
   - 定期清空日志文件：`log.clear()`
   - 提高日志级别，减少输出量
   - 考虑实现日志轮转（需要额外开发）

### 调试日志系统本身

```lua
local logger = require("logger")

-- 获取并打印当前配置
local config = logger.get_config()
for k, v in pairs(config) do
    print(k .. ": " .. tostring(v))
end

-- 测试各个级别
local log = logger.create("test_module")
log.debug("测试 DEBUG 级别")
log.info("测试 INFO 级别")
log.warn("测试 WARN 级别")
log.error("测试 ERROR 级别")
```

## 版本历史

- **v1.0** - 基础日志功能
- **v1.1** - 添加日志级别控制功能
- **v1.2** - 改进错误处理和文档

---

更多信息请参考源代码中的注释或联系开发者。
