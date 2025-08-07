# Spans Manager 使用说明

## 概述

`spans_manager.lua` 是一个专门用于管理 Rime 输入法中候选词 spans 信息的模块。它提供了统一的接口来保存、获取、清除和管理 spans 信息，解决了多个脚本之间 spans 信息管理混乱的问题。

## bug排查
应该知道,只要是被我替换过的候选词,其原来的spans信息都会消失,而我并没有办法重新添加spans信息.
应该是在于第一个候选词的`spans`,信息,所以一定是我的哪一个脚本替换了候选词.

确定了punct_eng_chinese_filter就是这个,


## 主要功能

### 1. 统一的 spans 信息管理
- 统一的属性命名规范
- 来源优先级管理
- 自动冲突检测和解决

### 2. 智能的生命周期管理
- 自动检测何时应该清除 spans 信息
- 防止内存泄漏
- 支持调试和监控

### 3. 光标跳转支持
- 基于 spans 信息的智能光标跳转
- 支持前进和后退跳转
- 兼容现有的 Tab 键跳转功能

## API 接口

### spans_manager.save_spans(context, vertices, input, source)
保存 spans 信息到 context 属性中。

**参数：**
- `context`: 上下文对象
- `vertices`: 分割点数组
- `input`: 对应的输入内容
- `source`: 来源脚本名称

**返回值：**
- `boolean`: 是否成功保存

**示例：**
```lua
local spans_manager = require("spans_manager")

-- 从候选词中提取spans信息并保存
local spans = cand:spans()
local vertices = spans.vertices
spans_manager.save_spans(context, vertices, input, "baidu_filter")
```

### spans_manager.get_spans(context)
获取已保存的 spans 信息。

**参数：**
- `context`: 上下文对象

**返回值：**
- `table` 或 `nil`: 包含 vertices_str, input, source, timestamp, vertices 的表

**示例：**
```lua
local spans_info = spans_manager.get_spans(context)
if spans_info then
    print("来源:", spans_info.source)
    print("输入:", spans_info.input)
    print("分割点:", table.concat(spans_info.vertices, ","))
end
```

### spans_manager.clear_spans(context, reason)
清除 spans 信息。

**参数：**
- `context`: 上下文对象
- `reason`: 清除原因（用于日志记录）

**示例：**
```lua
spans_manager.clear_spans(context, "选词完成")
```

### spans_manager.should_clear(context, current_input)
判断是否应该清除 spans 信息。

**参数：**
- `context`: 上下文对象
- `current_input`: 当前输入内容（可选）

**返回值：**
- `boolean`: 是否应该清除
- `string`: 清除原因

### spans_manager.auto_clear_check(context, current_input)
自动检查并清除过期的 spans 信息。

**参数：**
- `context`: 上下文对象
- `current_input`: 当前输入内容（可选）

**返回值：**
- `boolean`: 是否执行了清除操作

**示例：**
```lua
-- 在每个脚本的开始处调用
spans_manager.auto_clear_check(context, input)
```

### spans_manager.extract_and_save_from_candidate(context, candidate, input, source)
从候选词中提取并保存 spans 信息的便捷方法。

**参数：**
- `context`: 上下文对象
- `candidate`: 候选词对象
- `input`: 输入内容
- `source`: 来源脚本

**返回值：**
- `boolean`: 是否成功保存

**示例：**
```lua
-- 简化的spans信息提取和保存
spans_manager.extract_and_save_from_candidate(context, cand, input, "baidu_filter")
```

### spans_manager.get_next_cursor_position(context, current_pos)
获取用于光标跳转的下一个位置。

**参数：**
- `context`: 上下文对象
- `current_pos`: 当前光标位置

**返回值：**
- `number` 或 `nil`: 下一个光标位置

### spans_manager.get_prev_cursor_position(context, current_pos)
获取用于光标跳转的上一个位置。

**参数：**
- `context`: 上下文对象
- `current_pos`: 当前光标位置

**返回值：**
- `number` 或 `nil`: 上一个光标位置

## 优先级系统

spans_manager 使用优先级系统来管理多个脚本的 spans 信息：

1. **script_rawenglish_translator** - 优先级 1（最高）
2. **baidu_filter** - 优先级 2
3. **punct_eng_chinese_filter** - 优先级 3
4. **unknown** - 优先级 99（最低）

当多个脚本尝试保存 spans 信息时，优先级高的脚本会覆盖优先级低的脚本。

## 清除策略

spans 信息会在以下情况下自动清除：

1. **输入内容变化** - 当 current_input 与保存的 input 不匹配时
2. **不再包含反引号** - 当原输入包含反引号但当前输入不包含时
3. **组合状态结束** - 当 context:is_composing() 返回 false 时
4. **信息过期** - 当 spans 信息超过 30 秒时
5. **手动清除** - 选词完成、上屏完成等事件触发时

## 集成指南

### 对于 translator 脚本

```lua
local spans_manager = require("spans_manager")

function translator.func(input, seg, env)
    local context = env.engine.context
    
    -- 自动检查并清除过期的spans信息
    spans_manager.auto_clear_check(context, context.input)
    
    -- ... 其他逻辑 ...
    
    -- 保存spans信息
    spans_manager.save_spans(context, vertices, context.input, "script_name")
end
```

### 对于 filter 脚本

```lua
local spans_manager = require("spans_manager")

function filter.func(translation, env)
    local context = env.engine.context
    
    -- 自动检查并清除过期的spans信息
    spans_manager.auto_clear_check(context, context.input)
    
    for cand in translation:iter() do
        -- 检查是否已有spans信息
        local existing_spans = spans_manager.get_spans(context)
        if not existing_spans then
            -- 尝试从候选词中提取spans信息
            spans_manager.extract_and_save_from_candidate(context, cand, context.input, "filter_name")
        end
        
        yield(cand)
    end
end
```

### 对于 processor 脚本

```lua
local spans_manager = require("spans_manager")

function processor.func(key, env)
    local context = env.engine.context
    
    if key:repr() == "Tab" then
        -- 使用spans_manager进行光标跳转
        local next_pos = spans_manager.get_next_cursor_position(context, context.caret_pos)
        if next_pos then
            context.caret_pos = next_pos
            return kAccepted
        end
    end
    
    return kNoop
end
```

## 调试功能

### spans_manager.debug_info(context)
输出当前 spans 信息的调试信息。

**示例：**
```lua
spans_manager.debug_info(context)
-- 输出：
-- === Spans Debug Info ===
-- 输入: nihao,wode
-- 来源: baidu_filter
-- 时间戳: 1642567890
-- 分割点: 0,2,4,6,10
-- 分割点数组: 0,2,4,6,10
-- ========================
```

## 迁移指南

### 从旧的属性系统迁移

**旧代码：**
```lua
-- 保存spans信息
context:set_property("my_spans_vertices", vertices_str)
context:set_property("my_spans_input", input)

-- 获取spans信息
local my_spans_input = context:get_property("my_spans_input")
local my_spans_vertices = context:get_property("my_spans_vertices")
```

**新代码：**
```lua
-- 保存spans信息
spans_manager.save_spans(context, vertices, input, "script_name")

-- 获取spans信息
local spans_info = spans_manager.get_spans(context)
if spans_info then
    local input = spans_info.input
    local vertices = spans_info.vertices
end
```



## 注意事项

1. **线程安全性** - spans_manager 是线程安全的，可以在多个脚本中同时使用
2. **性能考虑** - spans_manager 会缓存解析后的 vertices 数组，避免重复解析
3. **兼容性** - spans_manager 与现有的属性系统兼容，可以逐步迁移
4. **错误处理** - 所有 API 都包含错误处理，即使传入无效参数也不会崩溃

## 最佳实践

1. **统一使用 spans_manager** - 不要混用新旧属性系统
2. **及时清除** - 在适当的时机手动清除 spans 信息
3. **使用合适的来源名称** - 使用有意义的脚本名称作为 source 参数
4. **启用调试日志** - 在开发阶段启用日志以便调试
5. **定期检查** - 在每个脚本的入口处调用 auto_clear_check
