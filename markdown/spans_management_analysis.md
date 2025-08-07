# Rime 输入法 Candidate Spans 管理专题分析

## 1. 问题概述

### 1.1 核心问题
在 Rime 输入法的自定义 Lua 脚本中，当我们生成自定义的 Candidate 候选词时，无法直接为其添加 spans 信息。spans 信息对于词语分割显示和光标跳转功能至关重要。

### 1.2 解决方案
通过创建专门的 `spans_manager.lua` 模块来统一管理 spans 信息，提供标准化的接口和生命周期管理，解决了原有系统中存在的命名不一致、管理分散、清除时机不明确等问题。

## 2. 新架构设计

### 2.1 spans_manager 模块

创建了专门的 `lua/spans_manager.lua` 模块，提供以下核心功能：

1. **统一的保存接口** - `save_spans(context, vertices, input, source)`
2. **统一的获取接口** - `get_spans(context)`
3. **统一的清除接口** - `clear_spans(context, reason)`
4. **自动清除检查** - `auto_clear_check(context, current_input)`
5. **光标跳转支持** - `get_next_cursor_position()` / `get_prev_cursor_position()`

### 2.2 优先级管理系统

建立了基于来源的优先级系统：
- `script_rawenglish_translator` - 优先级 1（最高）
- `baidu_filter` - 优先级 2  
- `punct_eng_chinese_filter` - 优先级 3
- `unknown` - 优先级 99（最低）

### 2.3 统一的属性命名

使用标准化的属性名：
- `spans_vertices` - 存储分割点信息
- `spans_input` - 存储对应的输入内容
- `spans_source` - 记录 spans 来源脚本
- `spans_timestamp` - 记录创建时间戳

## 3. 实施的改进

### 3.1 已完成的脚本修改

1. **lua/spans_manager.lua** - 新创建的核心管理模块
2. **lua/baidu_filter.lua** - 集成 spans_manager
3. **lua/punct_eng_chinese_filter.lua** - 集成 spans_manager  
4. **lua/script_rawenglish_translator.lua** - 集成 spans_manager
5. **lua/smart_cursor_processor.lua** - 使用 spans_manager 进行光标跳转

### 3.2 关键改进点

#### 3.2.1 自动清除机制
实现了智能的自动清除策略：
- 输入内容变化时清除
- 组合状态结束时清除
- 选词完成后清除
- spans信息过期时清除（30秒）

#### 3.2.2 冲突检测和解决
- 基于优先级的覆盖策略
- 防止重复保存相同信息
- 来源追踪和日志记录

#### 3.2.3 错误处理和调试
- 完善的错误处理机制
- 详细的日志记录
- 调试信息输出功能

## 4. 新的数据流向

```
输入 → script_rawenglish_translator → baidu_filter → punct_eng_chinese_filter → 候选词输出
          ↓                              ↓                    ↓
     spans_manager.save_spans()    spans_manager.get_spans()  spans_manager.get_spans()
          ↓                              ↓                    ↓
                            spans_manager (统一管理)
                                      ↓
                        smart_cursor_processor
                     (spans_manager.get_next_cursor_position)
                                      ↓
                              Tab键光标跳转
```

## 5. 使用方式对比

### 5.1 旧的使用方式

```lua
-- 保存spans信息
local vertices_str = ""
for i, vertex in ipairs(vertices) do
    vertices_str = vertices_str .. tostring(vertex)
    if i < #vertices then
        vertices_str = vertices_str .. ","
    end
end
context:set_property("my_spans_vertices", vertices_str)
context:set_property("my_spans_input", input)

-- 获取spans信息
local my_spans_input = context:get_property("my_spans_input")
local my_spans_vertices = context:get_property("my_spans_vertices")
```

### 5.2 新的使用方式

```lua
local spans_manager = require("spans_manager")

-- 保存spans信息
spans_manager.save_spans(context, vertices, input, "script_name")

-- 获取spans信息  
local spans_info = spans_manager.get_spans(context)

-- 自动清除检查
spans_manager.auto_clear_check(context, input)

-- 光标跳转
local next_pos = spans_manager.get_next_cursor_position(context, current_pos)
```

## 6. 解决的核心问题

### 6.1 命名不一致问题 ✅
- 统一使用 `spans_*` 前缀
- 消除了 `my_spans_*` vs `out_spans_*` 的混乱

### 6.2 管理分散问题 ✅  
- 集中在 spans_manager 模块中管理
- 统一的接口和行为

### 6.3 清除时机不明确问题 ✅
- 明确的清除策略和条件
- 自动检查和手动清除相结合

### 6.4 优先级冲突问题 ✅
- 基于来源的优先级系统
- 自动解决冲突

### 6.5 调试困难问题 ✅
- 详细的日志记录
- 调试信息输出功能
- 来源追踪

## 7. 性能和稳定性提升

### 7.1 性能优化
- 缓存解析后的 vertices 数组
- 减少重复的字符串操作
- 智能的更新检测

### 7.2 稳定性提升
- 完善的错误处理
- 防止内存泄漏
- 线程安全设计

### 7.3 可维护性提升
- 模块化设计
- 清晰的接口定义
- 完整的文档

## 8. 迁移和兼容性

### 8.1 向后兼容
- 保留对旧属性的读取支持
- 渐进式迁移策略
- 不破坏现有功能

### 8.2 迁移建议
1. 首先集成 spans_manager 模块
2. 逐个脚本替换旧的保存方式
3. 验证功能正常后移除旧属性
4. 启用日志进行测试和调试

## 9. 测试验证

### 9.1 功能测试
- spans 信息的正确保存和获取
- 优先级系统的正确工作
- 光标跳转功能的准确性

### 9.2 边界测试  
- 异常输入的处理
- 并发场景的稳定性
- 内存使用的合理性

### 9.3 性能测试
- 响应时间的改善
- 内存占用的控制
- 长期运行的稳定性

## 10. 总结

通过创建专门的 spans_manager 模块，我们成功解决了原有系统中的所有核心问题：

✅ **统一管理** - 集中式的 spans 信息管理  
✅ **优先级控制** - 智能的冲突解决机制  
✅ **生命周期管理** - 明确的创建和清除策略  
✅ **性能优化** - 减少重复操作和内存占用  
✅ **调试支持** - 完善的日志和调试功能  
✅ **向后兼容** - 不破坏现有功能的迁移方案  

新的 spans 管理系统不仅解决了当前的问题，还为未来的扩展和维护奠定了良好的基础。

### 2.1 涉及的脚本文件

1. **lua/script_rawenglish_translator.lua** - 反引号翻译器
2. **lua/baidu_filter.lua** - 百度云输入过滤器
3. **lua/punct_eng_chinese_filter.lua** - 标点符号转换过滤器
4. **lua/smart_cursor_processor.lua** - 智能光标处理器

### 2.2 数据流向

```
输入 → script_rawenglish_translator → baidu_filter → punct_eng_chinese_filter → 候选词输出
                     ↓                    ↓                    ↓
              保存spans信息         检查并保存spans      检查并保存spans
                     ↓                    ↓                    ↓
                            smart_cursor_processor
                                   ↓
                            Tab键光标跳转
```

### 2.3 当前 spans 保存机制

每个脚本都会检查是否已有 spans 信息，如果没有则保存：

```lua
-- 保存 spans 相关信息到属性（字符串格式）
context:set_property("my_spans_vertices", vertices_str)
context:set_property("my_spans_input", input)
```

## 3. Context 属性管理

### 3.1 当前使用的属性

| 属性名 | 用途 | 设置位置 | 清除时机 |
|--------|------|----------|----------|
| `my_spans_vertices` | 存储分割点信息 | 多个脚本 | 输入变化时 |
| `my_spans_input` | 存储对应的输入内容 | 多个脚本 | 输入变化时 |

## 4. Spans 生命周期管理

### 4.1 创建时机

1. **首次获取原始候选词的 spans**
   - 在第一个处理脚本中获取原始候选词的 spans 信息
   - 将 vertices 转换为字符串保存

2. **检查机制**
   - 后续脚本检查是否已有 spans 信息
   - 如果已存在，则不重复保存

### 4.2 清除时机（当前问题点）

#### 4.2.1 应该清除的情况

1. **输入内容变化**
   ```lua
   -- 检测输入变化
   if my_spans_input ~= "" and context.input ~= my_spans_input then
       context:set_property("my_spans_vertices", "")
       context:set_property("my_spans_input", "")
   end
   ```

2. **不包含反引号时**
   ```lua
   if context_input:find("`") == nil then
       context:set_property("my_spans_input", "")
       context:set_property("my_spans_vertices", "")
   end
   ```

3. **组合状态结束**
   ```lua
   if not context:is_composing() then
       -- 清除 spans 信息
   end
   ```

4. **选词完成**
   ```lua
   -- 在 select_notifier 中清除
   ```

5. **上屏完成**
   ```lua
   -- 在 commit_notifier 中清除
   ```

#### 4.2.2 不应该清除的情况

1. **仅光标移动**
   - 使用 Tab 键移动光标时
   - 输入内容未变化时

2. **候选词切换**
   - 上下箭头选择不同候选词时

## 5. 建议的改进方案

### 5.1 统一命名规范

建议使用统一的属性名：
- `spans_vertices` - 存储分割点信息
- `spans_input` - 存储对应的输入内容
- `spans_source` - 记录 spans 来源脚本

### 5.2 集中管理模块

创建一个专门的 spans 管理模块：

```lua
-- lua/spans_manager.lua
local spans_manager = {}

function spans_manager.save_spans(context, vertices, input, source)
    -- 统一保存逻辑
end

function spans_manager.get_spans(context)
    -- 统一获取逻辑
end

function spans_manager.clear_spans(context, reason)
    -- 统一清除逻辑，记录清除原因
end

function spans_manager.should_clear(context, current_input)
    -- 判断是否应该清除
end

return spans_manager
```

### 5.3 生命周期管理策略

#### 5.3.1 保存策略

1. **优先级机制**
   - script_rawenglish_translator 优先级最高
   - baidu_filter 次之
   - punct_eng_chinese_filter 最低

2. **检查机制**
   ```lua
   local existing_spans = spans_manager.get_spans(context)
   if not existing_spans then
       spans_manager.save_spans(context, vertices, input, "baidu_filter")
   end
   ```

#### 5.3.2 清除策略

1. **立即清除**
   - 输入内容发生变化
   - 组合状态结束
   - 不再包含特殊字符（如反引号）

2. **延迟清除**
   - 选词完成后
   - 上屏完成后

3. **条件清除**
   ```lua
   function spans_manager.should_clear(context, current_input)
       local spans_input = context:get_property("spans_input")
       if spans_input == "" then
           return false
       end
       
       -- 输入变化
       if current_input ~= spans_input then
           return true
       end
       
       -- 不再包含反引号
       if not current_input:find("`") then
           return true
       end
       
       -- 组合状态结束
       if not context:is_composing() then
           return true
       end
       
       return false
   end
   ```

### 5.4 调试和监控

1. **日志记录**
   - 记录 spans 的创建、更新、清除操作
   - 记录操作的触发原因和源脚本

2. **状态检查**
   - 定期检查 spans 信息的一致性
   - 检测内存泄漏和无效数据

## 6. 实施建议

### 6.1 短期改进

1. **统一属性命名**
   - 将所有脚本中的属性名统一为 `spans_vertices` 和 `spans_input`

2. **完善清除机制**
   - 在所有可能的清除时机添加清除逻辑

3. **增强日志记录**
   - 记录 spans 的完整生命周期

### 6.2 长期优化

1. **创建专用管理模块**
   - 实现 `spans_manager.lua`

2. **重构现有脚本**
   - 使用统一的管理接口

3. **性能优化**
   - 减少不必要的属性设置操作
   - 优化字符串转换逻辑

## 7. 风险和注意事项

### 7.1 潜在风险

1. **内存泄漏**
   - 如果 spans 信息未及时清除，可能导致内存累积

2. **状态不一致**
   - 多个脚本同时操作可能导致状态不一致

3. **性能影响**
   - 频繁的属性设置可能影响性能

### 7.2 注意事项

1. **线程安全**
   - 确保在多线程环境下的安全性

2. **兼容性**
   - 保持与现有功能的兼容性

3. **测试覆盖**
   - 全面测试各种输入场景

## 8. 测试场景

### 8.1 基本场景

1. **纯英文输入**
   - `nihao` → 检查 spans 创建和光标跳转

2. **包含标点符号**
   - `ni,hao` → 检查智能切分和 spans 管理

3. **包含反引号**
   - `ni`hello`hao` → 检查反引号处理和 spans 保存

### 8.2 边界场景

1. **快速输入变化**
   - 测试 spans 清除的及时性

2. **光标频繁移动**
   - 测试 spans 保持的稳定性

3. **多候选词切换**
   - 测试 spans 信息的一致性

## 9. 总结

spans 管理是一个复杂的问题，需要在多个脚本之间协调。建议采用统一的管理策略，明确的生命周期管理，以及完善的调试和监控机制。通过逐步改进，可以建立一个稳定、高效的 spans 管理体系。
