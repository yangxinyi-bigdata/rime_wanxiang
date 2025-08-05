# Rime Recognizer 技术分析：patterns 配置与工作原理

## 概述

Rime 的 `recognizer` 是一个输入处理器（Processor），负责识别符合特定模式的输入，并为匹配的输入段落打上相应的标签（tag）。它与 `matcher` 分段器（Segmentor）密切配合，实现对不同类型输入的识别和路由。

## 基本工作流程

### 1. 处理器链中的位置

在 Rime 的处理器链中，`recognizer` 通常位于以下位置：

```yaml
engine:
  processors:
    - ascii_composer
    - recognizer          # ← 识别特殊模式的输入
    - key_binder
    - speller
    - punctuator
    - selector
    - navigator
    - express_editor

  segmentors:
    - ascii_segmentor
    - matcher             # ← 与 recognizer 配合，标记段落
    - abc_segmentor
```

### 2. 工作机制

1. **输入识别**：用户输入字符后，`recognizer` 根据配置的 `patterns` 检查输入是否匹配某个模式
2. **标签分配**：如果匹配，`matcher` 分段器会为该输入段落添加对应的标签（tag）
3. **路由处理**：带有特定标签的段落会被路由到相应的翻译器或过滤器处理

## patterns 配置详解

### 配置语法

```yaml
recognizer:
  import_preset: default  # 继承默认配置
  patterns:
    pattern_name: "^regex_pattern$"
    another_pattern: "^another_regex$"
```

### 实际配置示例

基于 wanxiang_pro.schema.yaml 的配置：

```yaml
recognizer:
  import_preset: default
  patterns:
    punct: "^/([0-9]|10|[A-Za-z]+)$"          # 符号输入
    radical_lookup: "^&[A-Za-z]*$"             # 部件拆字反查
    add_user_dict: "^&&[A-Za-z/&&']*$"         # 自造词
    unicode: "^U[a-f0-9]+"                     # Unicode 字符
    number: "^R[0-9]+[.]?[0-9]*"               # 数字金额大写
    gregorian_to_lunar: "^N[0-9]{1,8}"         # 公历转农历
    calculator: "^V.*$"                        # 计算器功能
    quick_symbol: "^;.*$"                      # 快符引导
```

### pattern 详细说明

| Pattern名称 | 正则表达式 | 匹配示例 | 功能描述 |
|------------|-----------|---------|----------|
| `punct` | `^/([0-9]\|10\|[A-Za-z]+)$` | `/1`, `/abc`, `/10` | 符号输入，响应 symbols.yaml |
| `radical_lookup` | `^&[A-Za-z]*$` | `&abc`, `&木` | 部件拆字反查 |
| `unicode` | `^U[a-f0-9]+` | `U4e00`, `Uabcd` | Unicode 字符输入 |
| `number` | `^R[0-9]+[.]?[0-9]*` | `R123`, `R12.34` | 数字转大写汉字 |
| `calculator` | `^V.*$` | `V1+2`, `V100*0.8` | 计算器功能 |
| `quick_symbol` | `^;.*$` | `;q`, `;hello` | 快速符号输入 |

## 标签（Tags）系统

### 标签的作用

当 `recognizer` 识别到匹配的模式时，`matcher` 会为输入段落添加相应的标签。这些标签用于：

1. **路由控制**：决定哪个翻译器处理该段落
2. **过滤控制**：决定哪个过滤器应用于该段落
3. **格式控制**：决定如何显示和处理该段落

### 标签与翻译器的对应关系

```yaml
engine:
  translators:
    - script_translator      # 默认，tag: abc
    - reverse_lookup_translator@radical_lookup  # tag: radical_lookup
    - lua_translator@unicode                     # tag: unicode
    - lua_translator@number_translator           # tag: number
    - lua_translator@calculator                  # tag: calculator
```

### 在 Lua 中访问标签

```lua
-- 在 translator 中
function translator(input, seg, env)
  if seg:has_tag("unicode") then
    -- 处理 Unicode 输入
  elseif seg:has_tag("number") then
    -- 处理数字输入
  end
end

-- 在 filter 中检查段落标签
function filter(input, env)
  for cand in input:iter() do
    local seg = env.engine.context.composition:back()
    if seg and seg:has_tag("special_tag") then
      -- 特殊处理
    end
    yield(cand)
  end
end
```

## C++ 实现层面

### 关键类和文件

虽然在提供的源码中没有直接找到 recognizer 的实现，但根据 Rime 的架构，关键组件包括：

1. **Processor 基类**：所有处理器的基类
2. **Recognizer 类**：继承自 Processor，实现模式识别
3. **Matcher 类**：继承自 Segmentor，负责标签分配
4. **正则表达式引擎**：使用 boost::regex 进行模式匹配

### 数据流

```
用户输入 → recognizer.ProcessKeyEvent() 
         → 正则匹配检查
         → matcher.Proceed() 
         → 添加标签到 Segment
         → 路由到对应 Translator
```

## 配置最佳实践

### 1. 模式设计原则

- **精确匹配**：使用 `^` 和 `$` 确保完整匹配
- **避免冲突**：确保不同模式不会互相干扰
- **性能考虑**：简单的模式优先，复杂的正则表达式要谨慎使用

### 2. 常用模式模板

```yaml
# 前缀模式：以特定字符开头
prefix_pattern: "^prefix.*$"

# 数字模式：纯数字或数字+小数点
number_pattern: "^[0-9]+([.][0-9]*)?$"

# 字母数字混合
alphanumeric: "^[A-Za-z0-9]+$"

# 特定长度
fixed_length: "^.{4,8}$"

# 邮箱格式（简化）
email: "^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$"

# URL 格式（简化）
url: "^https?://.*$"
```

### 3. 调试技巧

```lua
-- 在 Lua 中调试标签
function debug_tags(seg)
  local tags = seg.tags
  if tags then
    log.info("Segment tags: " .. tags)
    if seg:has_tag("your_pattern") then
      log.info("Pattern matched!")
    end
  end
end
```

## 与其他模块的集成

### 1. 与翻译器集成

```yaml
# 配置特定翻译器处理特定标签
your_translator:
  tag: your_pattern
  # 其他翻译器配置...
```

### 2. 与过滤器集成

```yaml
# 过滤器可以检查标签决定是否处理
your_filter:
  tags: [your_pattern, another_pattern]
  # 其他过滤器配置...
```

### 3. 与格式化器集成

```yaml
# 特定标签的显示格式
speller:
  tag_format:
    your_pattern: "〔{input}〕"
```

## 高级用法

### 1. 条件模式

```lua
-- 在 Lua processor 中实现更复杂的条件判断
function conditional_recognizer(key, env)
  local context = env.engine.context
  local input = context.input
  
  -- 自定义条件逻辑
  if some_condition(input) then
    -- 手动添加标签
    local seg = context.composition:back()
    if seg then
      seg.tags = seg.tags .. " custom_tag"
    end
  end
end
```

### 2. 动态模式

```lua
-- 根据上下文动态调整识别模式
function dynamic_patterns(env)
  local config = env.engine.schema.config
  local current_mode = config:get_string("current_mode")
  
  if current_mode == "math" then
    -- 启用数学模式的模式
  elseif current_mode == "code" then
    -- 启用编程模式的模式
  end
end
```

## 总结

Rime 的 `recognizer` 系统提供了强大而灵活的输入模式识别能力：

1. **核心机制**：基于正则表达式的模式匹配
2. **标签系统**：为匹配的输入段落添加标签，实现路由控制
3. **模块协作**：与 matcher、translator、filter 等组件紧密配合
4. **可扩展性**：支持自定义模式和 Lua 扩展

通过合理配置 `recognizer` patterns，可以实现各种专门的输入处理需求，如符号输入、计算器、Unicode 字符输入、反查功能等。这使得 Rime 能够支持复杂的多模态输入场景。
