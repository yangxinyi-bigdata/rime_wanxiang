# Rime 多段输入处理实现方案

## 问题分析

您希望实现 `nihao`hello`keyi` 翻译成 `"你好`hello`可以"` 的功能，这涉及到：

1. **输入分段**：将复合输入拆分为多个逻辑段
2. **分别翻译**：对每个段应用不同的翻译策略  
3. **结果合并**：将各段的翻译结果组合成最终候选词

## 技术实现方案

### 方案概述

在 Rime 输入法中，这个功能需要通过以下组件配合实现：

1. **Segmentor（分段器）**：识别并标记包含特殊模式的输入
2. **Translator（翻译器）**：处理标记的段，进行拆分翻译和合并
3. **可选的 Filter（过滤器）**：对结果进行后处理

### 核心流程

```
输入: nihao`hello`keyi
    ↓
Segmentor: 识别复合模式，创建 composite segment
    ↓
Translator: 解析 → [nihao] + [`hello`] + [keyi]
    ↓
分别翻译: [你好] + [hello] + [可以]  
    ↓
合并结果: "你好hello可以"
```

## 实现方案对比

### 方案1: 简化版 (simple_composite_translator.lua)

**特点**：
- 实现简单，代码量少
- 使用固定字典翻译
- 适合基础使用场景

**优点**：
- 易于理解和维护
- 性能较好
- 配置简单

**缺点**：
- 翻译能力有限
- 不能利用现有的复杂翻译器

### 方案2: 高级版 (advanced_composite_translator.lua)

**特点**：
- 可以调用现有翻译器
- 支持多种翻译策略
- 提供调试功能

**优点**：
- 翻译能力强
- 高度可配置
- 支持调试分析

**缺点**：
- 代码复杂度高
- 性能开销较大

### 方案3: 完整版 (composite_translator.lua)

**特点**：
- 功能最全面
- 支持多种候选词组合
- 高度可扩展

**优点**：
- 功能强大
- 灵活性最高
- 可生成多种候选词

**缺点**：
- 最复杂
- 性能要求最高

## 关键技术点

### 1. Segment 创建和标记

```lua
-- 在 Segmentor 中创建特殊标记的 segment
local seg = Segment(start_pos, end_pos)
seg.tags = seg.tags + Set{"composite"}
segmentation:add_segment(seg)
```

### 2. 输入解析

```lua
-- 解析复合输入为多个部分
function parse_input(input)
    local parts = {}
    -- 按反引号分割，区分普通段和字面量段
    -- 返回结构化的段信息
    return parts
end
```

### 3. 调用其他翻译器

```lua
-- 使用 Component.Translator 调用现有翻译器
env.script_translator = Component.Translator(env.engine, "", "script_translator")
local translation = env.script_translator:query(text, temp_seg)
```

### 4. 候选词生成

```lua
-- 生成合并后的候选词
yield(Candidate("composite", seg.start, seg._end, merged_text, comment))
```

## 配置步骤

### 1. Schema 配置

在 `xxx.schema.yaml` 中添加：

```yaml
engine:
  segmentors:
    - ascii_segmentor
    - matcher
    - lua_segmentor@composite_segmentor      # 添加分段器
    - abc_segmentor
    - punct_segmentor
    - fallback_segmentor
  translators:
    - echo_translator
    - punct_translator
    - lua_translator@composite_translator    # 添加翻译器
    - script_translator
    - table_translator

# 可选配置
translator:
  debug_mode: true  # 启用调试模式
```

### 2. Lua 脚本注册

在 `rime.lua` 中：

```lua
-- 选择一个方案引入
local composite = require("simple_composite_translator")
-- local composite = require("advanced_composite_translator")
-- local composite = require("composite_translator")

-- 注册函数
composite_segmentor = composite.segmentor
composite_translator = composite.translator
composite_init = composite.init
composite_fini = composite.fini
```

### 3. 测试使用

重新部署后，输入如下内容测试：
- `nihao`hello`keyi` → 应产生 "你好hello可以"
- `wo`world`hao` → 应产生 "我world好"

## 扩展方向

### 1. 支持更多分隔符

```lua
-- 支持多种分隔符：反引号、方括号、花括号等
if string.find(input, "`") or string.find(input, "%[") or string.find(input, "{") then
    -- 处理不同类型的分隔符
end
```

### 2. 嵌套翻译

```lua
-- 支持嵌套结构如：outer`inner{nested}text`end
-- 需要更复杂的解析逻辑
```

### 3. 条件翻译

```lua
-- 根据上下文决定翻译策略
if context_type == "english" then
    -- 使用英文翻译模式
elseif context_type == "code" then
    -- 使用代码翻译模式
end
```

### 4. 智能合并

```lua
-- 根据语法规则智能调整合并结果
-- 如自动添加标点符号、调整词序等
```

## 调试技巧

### 1. 启用调试模式

在 schema 配置中设置 `translator.debug_mode: true`

### 2. 查看日志

日志位置：
- 【中州韵】`/tmp/rime.ibus.*`
- 【小狼毫】`%TEMP%\rime.weasel.*`  
- 【鼠须管】`$TMPDIR/rime.squirrel.*`

### 3. 调试候选词

启用调试模式后会生成额外的调试候选词，显示：
- 分段信息
- 翻译来源
- 处理过程

## 性能优化

### 1. 缓存翻译结果

```lua
-- 缓存常用翻译避免重复查询
local translation_cache = {}
```

### 2. 限制候选词数量

```lua
-- 限制生成的候选词数量避免性能问题
local max_candidates = 5
```

### 3. 延迟加载

```lua
-- 按需创建翻译器实例
if not env.internal_translator then
    env.internal_translator = Component.Translator(...)
end
```

## 总结

通过 Segmentor + Translator 的组合，可以实现复杂的多段输入处理。选择合适的实现方案：

- **简单需求**：使用简化版，快速实现基本功能
- **复杂需求**：使用高级版，充分利用现有翻译能力  
- **完整功能**：使用完整版，获得最大的灵活性

关键是理解 Rime 的处理流程，合理设计分段和翻译策略，确保各个组件协调工作。
