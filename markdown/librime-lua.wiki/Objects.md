- [对象接口](#对象接口)
  - [文档约定](#文档约定)
    - [标记说明](#标记说明)
    - [Compose 机制详解](#compose-机制详解)
    - [env.name\_space 详解](#envname_space-详解)
      - [什么是 name\_space](#什么是-name_space)
      - [name\_space 的来源](#name_space-的来源)
      - [配置访问模式](#配置访问模式)
      - [完整示例](#完整示例)
      - [name\_space 的实际用途](#name_space-的实际用途)
        - [1. 组件配置隔离](#1-组件配置隔离)
        - [2. 候选词来源标识](#2-候选词来源标识)
        - [3. 日志和调试](#3-日志和调试)
        - [4. 条件逻辑](#4-条件逻辑)
        - [5. 创建其他组件实例](#5-创建其他组件实例)
      - [常见问题](#常见问题)
      - [最佳实践](#最佳实践)
  - [Engine](#engine)
  - [Context](#context)
    - [通知器触发流程分析](#通知器触发流程分析)
      - [1. commit\_notifier（上屏通知器）](#1-commit_notifier上屏通知器)
      - [2. update\_notifier（更新通知器）](#2-update_notifier更新通知器)
      - [3. select\_notifier（选择通知器）](#3-select_notifier选择通知器)
      - [流程总结](#流程总结)
  - [Preedit](#preedit)
  - [Composition](#composition)
  - [Segmentation](#segmentation)
  - [Segment](#segment)
  - [Spans](#spans)
    - [与Segment的关系](#与segment的关系)
    - [工作原理](#工作原理)
    - [使用示例](#使用示例)
    - [典型用途](#典型用途)
    - [跨对象的Spans使用](#跨对象的spans使用)
  - [Schema](#schema)
  - [Config](#config)
  - [ConfigMap](#configmap)
  - [ConfigList](#configlist)
  - [ConfigValue](#configvalue)
  - [ConfigItem](#configitem)
  - [KeyEvent](#keyevent)
  - [KeySequence](#keysequence)
  - [Candidate 候选词](#candidate-候选词)
  - [ShadowCandidate 衍生扩展词](#shadowcandidate-衍生扩展词)
  - [Phrase 词组](#phrase-词组)
    - [候选词来源翻译器识别](#候选词来源翻译器识别)
      - [解决方案](#解决方案)
        - [1. 利用候选词类型字段（推荐）](#1-利用候选词类型字段推荐)
        - [2. 在注释中添加标识信息](#2-在注释中添加标识信息)
        - [3. 候选词包装器模式](#3-候选词包装器模式)
      - [实际使用示例](#实际使用示例)
      - [最佳实践建议](#最佳实践建议)
      - [常见的候选词类型](#常见的候选词类型)
  - [UniquifiedCandidate 去重合并候选词](#uniquifiedcandidate-去重合并候选词)
  - [Set](#set)
  - [Menu](#menu)
  - [Opencc](#opencc)
  - [ReverseDb / ReverseLookup](#reversedb--reverselookup)
  - [ReverseLookup (ver #177)](#reverselookup-ver-177)
  - [CommitEntry](#commitentry)
  - [DictEntry](#dictentry)
  - [Code](#code)
  - [Memory](#memory)
  - [Projection](#projection)
  - [Component](#component)
  - [Processor](#processor)
  - [Segmentor](#segmentor)
  - [Translator](#translator)
  - [Filter](#filter)
  - [Notifier](#notifier)
  - [OptionUpdateNotifier](#optionupdatenotifier)
  - [PropertyUpdateNotifier](#propertyupdatenotifier)
  - [KeyEventNotifier](#keyeventnotifier)
  - [Connection](#connection)
  - [log](#log)
  - [rime\_api](#rime_api)
  - [CommitRecord](#commitrecord)
  - [CommitHistory](#commithistory)
  - [DbAssessor](#dbassessor)
  - [LevelDb ( 不可用於已開啓的userdb, 專用於 librime-lua key-value db)](#leveldb--不可用於已開啓的userdb-專用於-librime-lua-key-value-db)
    - [新建 leveldb](#新建-leveldb)
    - [物件方法](#物件方法)
  - [Recognizer 识别器与 Patterns 模式匹配](#recognizer-识别器与-patterns-模式匹配)
    - [概述](#概述)
    - [工作原理](#工作原理-1)
      - [1. 处理流程](#1-处理流程)
      - [2. 在引擎配置中的位置](#2-在引擎配置中的位置)
    - [Recognizer 配置语法](#recognizer-配置语法)
      - [基本格式](#基本格式)
      - [实际配置示例](#实际配置示例)
    - [标签（Tags）系统](#标签tags系统)
      - [标签的作用](#标签的作用)
      - [标签与翻译器的对应](#标签与翻译器的对应)
    - [在 Lua 中使用标签](#在-lua-中使用标签)
      - [在翻译器中检查标签](#在翻译器中检查标签)
      - [在过滤器中检查标签](#在过滤器中检查标签)
      - [访问段落的所有标签](#访问段落的所有标签)
    - [常用模式模板](#常用模式模板)
      - [1. 前缀模式](#1-前缀模式)
      - [2. 数字模式](#2-数字模式)
      - [3. 字符类模式](#3-字符类模式)
      - [4. 复杂模式](#4-复杂模式)
    - [与 Translation 和 Candidate 分析的结合](#与-translation-和-candidate-分析的结合)
      - [识别候选词来源翻译器](#识别候选词来源翻译器)
      - [在 Filter 阶段进行完整分析](#在-filter-阶段进行完整分析)
    - [调试和监控](#调试和监控)
      - [监控 recognizer 行为](#监控-recognizer-行为)
      - [标签统计](#标签统计)
    - [最佳实践](#最佳实践-1)
      - [1. 模式设计原则](#1-模式设计原则)
      - [2. 标签命名规范](#2-标签命名规范)
      - [3. 错误处理](#3-错误处理)
      - [4. 性能优化](#4-性能优化)
    - [总结](#总结)


# 对象接口
librime-lua 封装了 librime C++ 对象到 lua 中供脚本访问。需注意随着项目的开发，以下文档可能是不完整或过时的，敬请各位参与贡献文档。

## 文档约定

### 标记说明

- **`*W`** - 标记表示该操作会触发 `Compose()` 方法，即会重新进行输入合成处理，包括：
  - 重新计算候选词
  - 更新输入编辑状态
  - 触发相关的通知事件
  - 刷新用户界面显示
  
  带有 `*W` 标记的操作通常涉及对输入状态的修改，会影响到整个输入法的工作流程。

### Compose 机制详解

在Rime输入法中，`Compose()` 是一个核心方法，负责协调整个输入处理流程：

1. **分词处理（Segmentation）**: 将输入字符串按照当前输入方案的规则进行分词
2. **翻译处理（Translation）**: 调用各种翻译器将分词结果转换为候选词
3. **过滤处理（Filtering）**: 应用过滤器对候选词进行筛选和排序
4. **界面更新**: 更新候选词菜单和预编辑区域显示

当执行带有 `*W` 标记的操作时，输入法会自动调用 `Compose()` 来确保显示状态与内部数据保持同步。这是一个相对耗时的操作，因此在性能敏感的场景中需要谨慎使用。

**示例**:
```lua
local context = env.engine.context
-- 以下操作会触发 Compose()
context:push_input("ni")  -- *W 标记
context:clear()          -- *W 标记
context.input = "hao"    -- *W 标记（设置属性）
```

### env.name_space 详解

`env.name_space` 是每个 Lua 组件（Translator、Filter、Processor 等）实例的**唯一标识符**，它在 Rime 的组件系统中起着关键作用。

#### 什么是 name_space

`name_space` 是组件的**命名空间**或**实例名称**，用于：

1. **唯一标识组件实例**：在同一输入方案中区分不同的组件实例
2. **配置访问**：访问该组件在 schema 配置中的专属配置项
3. **组件间通信**：作为组件间识别和通信的标识
4. **调试和日志**：在错误信息和日志中标识问题来源

#### name_space 的来源

`name_space` 的值来自 schema 配置文件中的组件声明。格式为：

```yaml
# schema 配置中的组件声明格式：
component_type@name_space

# 实际示例：
engine:
  translators:
    - lua_translator@date_translator        # name_space = "date_translator"
    - lua_translator@*expand_translator     # name_space = "expand_translator"
    - lua_translator@my_custom_translator   # name_space = "my_custom_translator"
  filters:
    - lua_filter@charset_filter             # name_space = "charset_filter"
    - lua_filter@*my_module*my_filter       # name_space = "my_filter"
```

**重要提醒**：`env.name_space` 的值**不是**由 `.lua` 文件名决定的，而是由配置中 `@` 后面的名称决定的！

**验证示例**：
```yaml
# 假设你有一个文件 date_translator.lua
engine:
  translators:
    - lua_translator@时间处理器    # env.name_space = "时间处理器"
    - lua_translator@date_handler  # env.name_space = "date_handler" 
    - lua_translator@任意名称      # env.name_space = "任意名称"
```

无论你的 Lua 文件叫什么名字，`env.name_space` 的值都由配置决定。

#### 配置访问模式

组件可以通过 `name_space` 访问其专属的配置：

```lua
local function init(env)
    local config = env.engine.schema.config
    
    -- 访问 date_translator 组件的配置
    -- 对应配置文件中的 date_translator: 节点
    if env.name_space == "date_translator" then
        local date_format = config:get_string(env.name_space .. "/format") or "%Y-%m-%d"
        local enabled = config:get_bool(env.name_space .. "/enabled") or true
        env.date_format = date_format
        env.enabled = enabled
    end
end
```

对应的 schema 配置：

```yaml
# 在 schema.yaml 中
date_translator:
  format: "%Y年%m月%d日"
  enabled: true

expand_translator:
  wildcard: "*"
  max_results: 100
```

#### 完整示例

**Schema 配置 (test.schema.yaml)**:
```yaml
engine:
  translators:
    - lua_translator@date_translator
    - lua_translator@expand_translator
    
# 组件配置
date_translator:
  trigger_word: "date"
  format: "%Y-%m-%d"

expand_translator:
  wildcard: "*"
  dictionary: "expanded_dict"
```

**Lua 代码 (date_translator.lua)**:
```lua
local function init(env)
    local config = env.engine.schema.config
    
    -- env.name_space 的值是 "date_translator"
    log.info("初始化组件：" .. env.name_space)
    
    -- 读取该组件的配置
    env.trigger = config:get_string(env.name_space .. "/trigger_word") or "date"
    env.format = config:get_string(env.name_space .. "/format") or "%Y-%m-%d"
    
    log.info("触发词：" .. env.trigger .. "，格式：" .. env.format)
end

local function translate(input, seg, env)
    if input == env.trigger then
        local date_str = os.date(env.format)
        -- 使用 name_space 作为候选词类型标识
        yield(Candidate(env.name_space, seg.start, seg._end, date_str, "当前日期"))
    end
end

return { init = init, func = translate }
```

#### name_space 的实际用途

##### 1. 组件配置隔离
```lua
-- 每个组件只访问自己的配置空间
local my_config = config:get_string(env.name_space .. "/my_setting")
```

##### 2. 候选词来源标识
```lua
-- 创建带有来源标识的候选词
yield(Candidate(env.name_space, seg.start, seg._end, text, comment))
```

##### 3. 日志和调试
```lua
log.info("组件 " .. env.name_space .. " 处理输入：" .. input)
```

##### 4. 条件逻辑
```lua
if env.name_space == "special_translator" then
    -- 特殊处理逻辑
end
```

##### 5. 创建其他组件实例
```lua
-- 在某个组件中创建其他组件的实例
local script_trans = Component.ScriptTranslator(env.engine, env.name_space, "script_translator")
```

#### 常见问题

**Q: 为什么我的配置读取不到？**
A: 检查 schema 中的配置节点名称是否与 `env.name_space` 一致。

**Q: 多个组件可以使用相同的 name_space 吗？**
A: 不建议。虽然技术上可能，但会导致配置冲突和调试困难。

**Q: name_space 可以动态修改吗？**
A: 不可以。`name_space` 在组件创建时确定，运行时只读。

#### 最佳实践

1. **描述性命名**：使用清晰描述组件功能的名称
   ```yaml
   - lua_translator@phone_number_translator
   - lua_filter@emoji_filter
   ```

2. **避免冲突**：确保每个组件实例有独特的 name_space

3. **配置组织**：将组件配置放在与 name_space 同名的节点下

4. **一致性使用**：在候选词创建、日志等处一致使用 name_space

## Engine

可通过 `env.engine` 获得。

属性：

属性名 | 类型 | 解释
--- | --- | --- 
schema | Schema | 当前输入方案
context | Context | 输入上下文
active_engine | Engine | 当前激活的引擎

方法：

方法名 | 参数 | 返回值 | 解释
--- | --- | --- | ---
process_key(key) | key: KeyEvent | ProcessResult | 处理按键事件
compose | | | 合成输入
commit_text(text) | text: string | | 上屏 text 字符串
apply_schema(schema) | schema: Schema | | 应用输入方案

## Context

输入编码上下文。

可通过 `env.engine.context` 获得。

**注意**: 带有 `*W` 标记的属性或方法会触发 `Compose()` 方法，重新进行输入合成处理。

属性：

属性名 | 类型 | 解释
--- | --- | --- 
composition | Composition | 当前的组合编辑对象 
input | string | 正在输入的编码字符串 *W
caret_pos | number | 脱字符`‸`位置（以raw input中的ASCII字符数量标记）*W
commit_notifier | Notifier | 上屏通知器
select_notifier | Notifier | 选择通知器
update_notifier | Notifier | 更新通知器,**输入内容变化时**,**添加输入字符**,删除,**清空**,**光标位置变化**,**候选词选择状态变化时**,**组合状态重新计算时**,**重新打开之前的选择时**,<br />触发频率`update_notifier` 是最高频触发的通知器：<br /><br />1. **光标移动时触发** - 左右移动、点击等<br />2. **候选词切换时触发** 上下选择候选词<br /> 3. **每次按键几乎都触发** - 包括字母、数字、方向键等<br /> 4. **状态变化时触发** - 输入法内部状态更新 
delete_notifier | Notifier | 删除候选词通知器, 发送**"请求删除候选词时"**,删除用户自定义的错误词汇,清理不需要的候选词,个性化词汇管理,删除操作的日志记录 
option_update_notifier | OptionUpdateNotifier | 选项改变通知，使用 connect 方法接收通知
property_update_notifier | PropertyUpdateNotifier | 属性更新通知器
unhandled_key_notifier | KeyEventNotifier | 未处理按键通知器 
commit_history | CommitHistory | 上屏历史记录 

方法：

方法名 | 参数 | 返回值 | 解释
--- | --- | --- | ---
commit | | | 上屏剩余字符串 
get_commit_text | | string | 获取即将上屏的文本
get_script_text | | string | 按音节分割的脚本文本
get_preedit | | Preedit | 获取预编辑信息
is_composing | | boolean | 是否正在输入（输入字符串非空或候选词菜单非空）
has_menu | | boolean | 是否有候选词（选项菜单）
get_selected_candidate | | Candidate | 返回选中的候选词
push_input(text) | text: string | boolean | 在caret_pos位置插入指定的text编码字符串，caret_pos跟隨右移 *W
pop_input(num) | num: number | boolean | 在caret_pos位置往左删除num指定数量的编码字符串，caret_pos跟隨左移 *W
delete_input(start, end) | start: number, end: number | boolean | 删除指定位置范围的输入
clear | | | 清空正在输入的编码字符串及候选词 *W
select(index) | index: number | boolean | 选择第index个候选词（序号从0开始）
confirm_current_selection | | boolean | 确认选择当前高亮选择的候选词（默认为第0个）
delete_current_selection | | boolean | 删除当前高亮选择的候选词（自造词组从词典中删除；固有词则删除用户输入词频）（returning true doesn't mean anything is deleted for sure） <br> [https://github.com/rime/librime/.../src/context.cc#L125-L137](https://github.com/rime/librime/blob/fbe492eefccfcadf04cf72512d8548f3ff778bf4/src/context.cc#L125-L137)
confirm_previous_selection | | boolean | 确认前一个选择
reopen_previous_selection | | boolean | 重新打开前一个选择 *W
clear_previous_segment | | boolean | 清除前一个片段
reopen_previous_segment | | boolean | 重新打开前一个片段 *W
clear_non_confirmed_composition | | | 清空未确认的组合编辑
refresh_non_confirmed_composition | | | 刷新未确认的组合编辑，重新计算候选词 *W
set_option(option, value) | option: string, value: boolean | | 设置选项开关（如简繁转换等）
get_option(option) | option: string | boolean | 获取选项开关状态
set_property(key, value) | key: string, value: string | | 设置属性值，只能使用字符串类型，可以用于存储上下文信息（可配合 `property_update_notifier` 使用）
get_property(key) | key: string | string | 获取属性值
clear_transient_options | | | 清除临时选项

### 通知器触发流程分析

基于实际日志记录，在选词上屏并完成一次输入的过程中，各个通知器的触发时序和上下文变化如下：

#### 1. commit_notifier（上屏通知器）

**触发时机**：在候选词被选中并即将上屏时触发  
**触发顺序**：第一个触发  

**上下文状态**：
- `input`: 'nihk'（原始输入编码）
- `caret_pos`: 4（光标在输入末尾）
- `is_composing`: true（正在组合输入）
- `has_menu`: true（有候选词菜单）
- `get_commit_text`: '你好'（即将上屏的文本）
- `get_script_text`: '你好'（脚本文本）
- `preedit.text`: 'ni hk‸'（预编辑显示）
- `selected_candidate`: '你好'（当前选中的候选词）

**Segmentation 状态**：
- `size`: 1（有一个段落）
- `empty`: false（非空）
- `segmentation.input`: 'nihk'（分段输入）
- `confirmed_position`: 4（确认位置）
- 包含一个已确认的 Segment，状态为 kConfirmed

**关键特征**：此时所有输入状态都完整保留，可以获取到完整的输入上下文信息

#### 2. update_notifier（更新通知器）

**触发时机**：在上屏完成后，输入状态被清空时触发  
**触发顺序**：第二个触发  

**上下文状态**：
- `input`: ''（输入已清空）
- `caret_pos`: 0（光标重置）
- `is_composing`: false（不再组合输入）
- `has_menu`: false（候选词菜单已消失）
- `get_commit_text`: ''（无待上屏文本）
- `get_script_text`: ''（脚本文本已清空）
- `preedit.text`: '‸'（仅剩光标）
- `selected_candidate`: nil（无选中候选词）

**Segmentation 状态**：
- `size`: 0（无段落）
- `empty`: true（已清空）
- `segmentation.input`: ''（分段输入已清空）
- `confirmed_position`: 0（确认位置重置）

**关键特征**：输入状态完全清空，标志着一次输入周期的结束

#### 3. select_notifier（选择通知器）

**触发时机**：在选择操作完成后触发  
**触发顺序**：第三个触发  

**上下文状态**：与 update_notifier 完全相同
- 所有输入状态均已清空
- 无任何候选词信息
- 输入上下文重置为初始状态

**关键特征**：虽然名为"选择通知器"，但实际在选择完成并清空后才触发

#### 流程总结

```
用户输入 "nihk" → 选择候选词 "你好" → 触发上屏流程：

1. commit_notifier 触发
   - 保留完整的输入上下文
   - 可获取原始输入、候选词、预编辑信息
   - 适合做输入分析、日志记录等

2. update_notifier 触发  
   - 输入状态已清空
   - 组合状态结束
   - 适合做状态重置、界面更新等

3. select_notifier 触发
   - 选择操作完全结束
   - 上下文已重置
   - 适合做选择后的清理工作
```

**实践建议**：
- 如需获取完整输入信息，应在 `commit_notifier` 中处理
- 如需检测输入结束，可在 `update_notifier` 中监听 `is_composing` 从 true 变为 false
- `select_notifier` 更适合做选择操作的后续处理

## Preedit

属性：

属性名 | 类型 | 解释
--- | --- | ---
text | string | 预编辑文本
caret_pos | number | 光标位置
sel_start | number | 选择区域开始位置
sel_end | number | 选择区域结束位置

方法：

方法名 | 参数 | 返回值 | 解释
--- | --- | --- | ---

## Composition

用户编写的“作品”。（通过此对象，可间接获得“菜单menu”、“候选词candidate”、“片段segment”相关信息）

可通过 `env.engine.context.composition` 获得。

属性：

属性名 | 类型 | 解释
--- | --- | ---

方法：

| 方法名                      | 参数               | 返回值          | 解释                                                               |
| ------------------------ | ---------------- | ------------ | ---------------------------------------------------------------- |
| empty                    |                  | boolean      | 尚未开始编写（无输入字符串、无候选词）                                              |
| back                     |                  | Segment      | 获得队尾（input字符串最右侧）的 Segment 对象                                    |
| pop_back                 |                  |              | 去掉队尾的 Segment 对象                                                 |
| push_back(segment)       | segment: Segment |              | 在队尾添加一个 Segment对象                                                |
| has_finished_composition |                  | boolean      | 是否完成组合编辑                                                         |
| get_prompt               |                  | string       | 获得队尾的 Segment 的 prompt 字符串（prompt 为显示在 caret 右侧的提示，比如菜单、预览输入结果等） |
| toSegmentation           |                  | Segmentation | 转换为Segmentation对象                                                |
| spans                    |                  | Spans        | 获取整个组合的跨度信息，包含所有片段的跨度                                            |


e.g.
```lua
local composition = env.engine.context.composition

if(not composition:empty()) then
  -- 获得队尾的 Segment 对象
  local segment = composition:back()

  -- 获得选中的候选词序号
  local selected_candidate_index = segment.selected_index

  -- 获取 Menu 对象
  local menu = segment.menu

  -- 获得（已加载）候选词数量
  local loaded_candidate_count = menu:candidate_count()
end
```

## Segmentation

在分词处理流程 Segmentor 中存储 Segment 并把其传递给 Translator 进行下一步翻译处理。

作为第一个参数传入以注册的 lua_segmentor。

或通过以下方法获得：

```lua
local composition = env.engine.context.composition
local segmentation = composition:toSegmentation()
```

> librime 定义 - https://github.com/rime/librime/blob/5c36fb74ccdff8c91ac47b1c221bd7e559ae9688/src/segmentation.cc#L28

属性：

属性名 | 类型 | 解释
--- | --- | ---
input | string | 活动中的原始（未preedit）输入编码
size | number | Segment的数量

方法：

方法名 | 参数 | 返回值 | 解释
--- | --- | --- | ---
empty | | boolean | 是否包含 Segment 或 Menu
back | | Segment | 队尾（对应input最右侧的输入字符）的 Segment 
pop_back | | | 移除队列最后的 Segment
reset_length(length) | length: number | | 保留 n 個 Segment
add_segment(seg) | seg: Segment | boolean | 添加 Segment <br>（librime v1.7.3：如果已包含 Segment 且起始位置相同，会取较长的Segment 并且合并 Segment.tags）
forward | | boolean | 新增 一個 kVoid 的 Segment(start_pos = 前一個 end_pos , end_pos = start_pos)
trim | | | 摘除队列最末位的0长度 Segment （0长度 Segment 用于语句流输入法中标记已确认`kConfirmed`但未上屏的 Segment 结束，用于开启一个新的 Segment）
has_finished_segmentation | | boolean | 是否完成分词
get_current_start_position | | number | 获取当前开始位置
get_current_end_position | | number | 获取当前结束位置
get_current_segment_length | | number | 获取当前片段长度
get_confirmed_position | | number | 属性 input 中已经确认（处理完）的长度 <br> （通过判断 status 为 `kSelected` 或 `kConfirmed` 的 Segment 的 _end 来判断 confirmed_position） <br> [https://github.com/rime/librime/.../src/segmentation.cc#L127](https://github.com/rime/librime/blob/cea389e6eb5e90f5cd5b9ca1c6aae7a035756405/src/segmentation.cc#L127)
get_segments | | table | 获取所有Segment对象的列表
get_at(index) | index: number | Segment | 根据索引获取Segment，支持负数索引

e.g.
```txt
                         | 你hao‸a
env.engine.context.input | "nihaoa"
Segmentation.input       | "nihao"
get_confirmed_position   | 2
```

## Segment

分词片段。触发 translator 时作为第二个参数传递给注册好的 lua_translator。

或者以下方法获得: （在 filter 以外的场景使用）

```lua
local composition = env.engine.context.composition
if(not composition:empty()) then
  local segment = composition:back()
end
```

segment.tags 是一個Set 支援 "* + -" 運算，可用 "*" 檢查 has_tag

```lua
-- Set集合运算示例：
--  +: Set{'a', 'b'} + Set{'b', 'c'} return Set{'a', 'b', 'c'}  （并集）
--  -: Set{'a', 'b'} - Set{'b', 'c'} return Set{'a'}           （差集）
--  *: Set{'a', 'b'} * Set{'b', 'c'} return Set{'b'}           （交集）

local tags = Set{'pinyin', 'reverse'}
local has_tag = not (seg.tags * tags):empty() -- 检查交集是否为空

-- 实际标签检查示例
if seg:has_tag("pinyin") then
   -- 处理拼音相关逻辑
elseif seg:has_tag("reverse") then
   -- 处理反查相关逻辑
end

-- 组合标签检查
local required_tags = Set{'pinyin', 'abc'}
if not (seg.tags * required_tags):empty() then
   -- segment包含pinyin或abc标签之一
end
```

构造方法：`Segment(start_pos, end_pos)`
1. start_pos: 首码在输入字符串中的位置
2. end_pos: 尾码在输入字符串中的位置

属性：

属性名 | 类型 | 解释
--- | --- | ---
status | string | 片段状态（可读写）：<br> 1. `kVoid` - （默认）空状态 <br> 2. `kGuess` - 猜测状态 <br> 3. `kSelected` - 已选中状态（大于此状态才会被视为选中） <br> 4. `kConfirmed` - 已确认状态
start | number | 片段在输入字符串中的开始位置（可读写）
_start | number | 片段在输入字符串中的开始位置，同start（可读写）
_end | number | 片段在输入字符串中的结束位置，end是Lua关键字所以用_end（可读写）
length | number | 片段长度（_end - start）（可读写）
tags | Set | 标签集合，支持集合运算（可读写）
menu | Menu | 候选词菜单对象（可读写） 
selected_index | number | 当前选中的候选词索引，从0开始（可读写）
prompt | string | 输入编码以右的提示字符串（可读写） <br> ![image](https://user-images.githubusercontent.com/18041500/190980054-7e944f5f-a381-4c73-ad6a-254a00c09e44.png)

方法：

方法名 | 参数 | 返回值 | 解释
--- | --- | --- | ---
clear | | | 清空片段的候选词菜单
close | | | 关闭片段，停止进一步的翻译
reopen | | | 重新打开片段，恢复翻译处理
has_tag(tag) | tag: string | boolean | 检查片段是否包含指定标签
get_candidate_at(index) | index: number | Candidate | 获取指定索引处的候选词（序号从0开始）
get_selected_candidate | | Candidate | 获取当前选中的候选词
active_text(input) | input: string | string | 根据片段位置从输入字符串中提取对应的文本
spans | | Spans | 获取片段的跨度信息，包含选中候选词的跨度

**使用示例**:

```lua
-- 在translator中使用segment
function translator(input, seg, env)
   -- 获取segment的基本信息
   local start_pos = seg.start    -- 片段开始位置
   local end_pos = seg._end       -- 片段结束位置  
   local length = seg.length      -- 片段长度
   local status = seg.status      -- 片段状态
   
   -- 检查标签
   if seg:has_tag("pinyin") then
      -- 处理拼音输入
   end
   
   -- 获取当前选中的候选词
   local selected = seg:get_selected_candidate()
   if selected then
      log.info("Selected: " .. selected.text)
   end
   
   -- 创建候选词时使用segment的位置信息
   yield(Candidate("test", seg.start, seg._end, "测试", "注释"))
end

-- 在filter中使用segment
function filter(input, env)
   for cand in input:iter() do
      local seg = env.engine.context.composition:back()
      if seg and seg:has_tag("special") then
         -- 对特殊标签的segment进行特殊处理
         yield(cand)
      end
   end
end
```

## Spans

跨度对象，用于表示文本中的分割点和区间信息。主要用于词语切分和语言处理。

### 与Segment的关系

`Spans` 和 `Segment` 有密切的关系：

1. **Segment的spans()方法**: 每个Segment都可以通过`spans()`方法获取其跨度信息
2. **词语边界信息**: Spans记录了词语的内部分割点，用于显示词语的组成结构
3. **多级切分**: 对于复合词或短语，Spans可以表示多层级的分割结构

### 工作原理

- 当Segment包含一个Phrase（词组）候选词时，`seg:spans()`会返回该词组的内部分割信息
- Spans记录了词语中每个字符或音节的边界位置
- 这些信息主要用于高亮显示、字符定位和输入法的视觉反馈

构造方法：`Spans()`

属性：

属性名 | 类型 | 解释
--- | --- | ---
_start | number | 跨度开始位置
_end | number | 跨度结束位置
count | number | 跨度数量
vertices | table | 分割点列表（顶点列表），表示文本中的分割位置

方法：

方法名 | 参数 | 返回值 | 解释
--- | --- | --- | ---
add_span(start, end) | start: number, end: number | | 添加一个跨度区间
add_spans(spans) | spans: Spans | | 合并另一个Spans对象的跨度
add_vertex(pos) | pos: number | | 在指定位置添加分割点
previous_stop(pos) | pos: number | number | 获取指定位置之前的停止点
next_stop(pos) | pos: number | number | 获取指定位置之后的停止点
has_vertex(pos) | pos: number | boolean | 检查指定位置是否存在分割点
count_between(start, end) | start: number, end: number | number | 计算指定区间内的跨度数量
clear | | | 清空所有跨度信息

### 使用示例

```lua
-- 1. 从Segment获取Spans
function translator(input, seg, env)
   local spans = seg:spans()
   log.info("Segment spans count: " .. spans.count)
   log.info("Start: " .. spans._start .. ", End: " .. spans._end)
   
   -- 获取所有分割点
   local vertices = spans.vertices
   for i, vertex in ipairs(vertices) do
      log.info("Vertex " .. i .. ": " .. vertex)
   end
end

-- 2. 从Candidate获取Spans
function filter(input, env)
   for cand in input:iter() do
      local spans = cand:spans()
      
      -- 检查特定位置是否有分割点
      if spans:has_vertex(2) then
         log.info("Candidate has vertex at position 2")
      end
      
      -- 计算区间内的跨度数量
      local count = spans:count_between(0, 5)
      log.info("Spans between 0-5: " .. count)
      
      yield(cand)
   end
end

-- 3. 手动创建和操作Spans
function custom_spans_example()
   local spans = Spans()
   
   -- 添加分割点
   spans:add_vertex(0)  -- 开始位置
   spans:add_vertex(2)  -- 第一个分割点
   spans:add_vertex(4)  -- 第二个分割点
   spans:add_vertex(6)  -- 结束位置
   
   -- 添加跨度区间
   spans:add_span(0, 2)  -- 第一个词
   spans:add_span(2, 4)  -- 第二个词
   spans:add_span(4, 6)  -- 第三个词
   
   -- 导航分割点
   local next_pos = spans:next_stop(2)      -- 从位置2开始的下一个停止点
   local prev_pos = spans:previous_stop(4)  -- 位置4之前的停止点
   
   return spans
end

-- 4. 实际应用：词语分割显示
function segmentation_filter(input, env)
   for cand in input:iter() do
      if cand.type == "phrase" then
         local spans = cand:spans()
         local text = cand.text
         
         -- 根据spans信息添加分割标记
         local marked_text = ""
         local last_pos = 0
         
         for i, vertex in ipairs(spans.vertices) do
            if vertex > last_pos then
               marked_text = marked_text .. text:sub(last_pos + 1, vertex)
               if i < #spans.vertices then
                  marked_text = marked_text .. "|"  -- 添加分割符
               end
               last_pos = vertex
            end
         end
         
         -- 创建带分割标记的新候选词
         local new_cand = Candidate(cand.type, cand.start, cand._end, 
                                   marked_text, cand.comment)
         yield(new_cand)
      else
         yield(cand)
      end
   end
end
```

### 典型用途

1. **词语分割显示**: 在候选词中显示词语的内部结构
2. **输入高亮**: 根据分割点高亮显示不同的音节或字符
3. **编辑定位**: 确定光标在复合词中的准确位置
4. **语言分析**: 分析词语的构成和边界信息

### 跨对象的Spans使用

Spans在多个对象中都有相应的方法：

```lua
-- 1. 从不同对象获取Spans的层次关系
function spans_hierarchy_example(env)
   local context = env.engine.context
   local composition = context.composition
   
   if not composition:empty() then
      -- 获取整个组合的spans（最高层）
      local comp_spans = composition:spans()
      log.info("Composition spans count: " .. comp_spans.count)
      
      -- 获取当前segment的spans（中间层）
      local segment = composition:back()
      local seg_spans = segment:spans()
      log.info("Segment spans count: " .. seg_spans.count)
      
      -- 获取当前候选词的spans（最底层）
      local candidate = segment:get_selected_candidate()
      if candidate then
         local cand_spans = candidate:spans()
         log.info("Candidate spans count: " .. cand_spans.count)
      end
   end
end

-- 2. Spans的组合使用
function combine_spans_example()
   local total_spans = Spans()
   
   -- 模拟从多个片段收集spans
   local seg1_spans = Spans()
   seg1_spans:add_span(0, 3)  -- 第一个词："北京"
   seg1_spans:add_vertex(0)
   seg1_spans:add_vertex(3)
   
   local seg2_spans = Spans()
   seg2_spans:add_span(3, 5)  -- 第二个词："大学"  
   seg2_spans:add_vertex(3)
   seg2_spans:add_vertex(5)
   
   -- 合并spans
   total_spans:add_spans(seg1_spans)
   total_spans:add_spans(seg2_spans)
   
   return total_spans
end
```

## Schema

方案。可以通过 `env.engine.schema` 获得。

构造方法：`Schema(schema_id)`
1. schema_id: string

属性：

属性名 | 类型 | 解释
--- | --- | --- 
schema_id | string | 方案编号
schema_name | string | 方案名称
config | Config | 方案配置
page_size | number | 每页最大候选词数
select_keys | string | 选词按键（不一定是数字键，视输入方案而定）

方法：

方法名 | 参数 | 返回值 | 解释
--- | --- | --- | ---

## Config

（方案的）配置。可以通过 `env.engine.schema.config` 获得

属性：

属性名 | 类型 | 解释
--- | --- | --- 

方法：

方法名 | 参数 | 返回值 | 解释
--- | --- | --- | ---
load_from_file(file_path) | file_path: string | boolean | 从文件加载配置
save_to_file(file_path) | file_path: string | boolean | 保存配置到文件
is_null(conf_path) | conf_path: string | boolean | 检查指定路径的配置项是否为null
is_value(conf_path) | conf_path: string | boolean | 检查指定路径是否为值类型
is_list(conf_path) | conf_path: string | boolean | 1. 存在且为 ConfigList 返回 true <br> 2. 存在且不为 ConfigList 返回 false <br> 3. 不存在返回 true ⚠️
is_map(conf_path) | conf_path: string | boolean | 检查指定路径是否为映射类型
get_bool(conf_path) | conf_path: string | boolean | 获取布尔值
get_int(conf_path) | conf_path: string | number | 获取整数值
get_double(conf_path) | conf_path: string | number | 获取浮点数值
get_string(conf_path) | conf_path: string | string | 根据配置路径 conf_path 获取配置的字符串值
set_bool(path, value) | path: string, value: boolean | | 设置布尔值
set_int(path, value) | path: string, value: number | | 设置整数值
set_double(path, value) | path: string, value: number | | 设置浮点数值
set_string(path, str) | path: string, str: string | | 设置字符串值
get_item(path) | path: string | ConfigItem | 获取配置项
set_item(path, item) | path: string, item: ConfigItem | | 设置配置项
get_value(path) | path: string | ConfigValue | 获取配置值
get_list(conf_path) | conf_path: string | ConfigList | 不存在或不为 ConfigList 时返回 nil
get_map(conf_path) | conf_path: string | ConfigMap | 不存在或不为 ConfigMap 时返回 nil
set_value(path, value) | path: string, value: ConfigValue | | 设置配置值
set_list(path, list) | path: string, list: ConfigList | | 设置列表配置
set_map(path, map) | path: string, map: ConfigMap | | 设置映射配置
get_list_size(conf_path) | conf_path: string | number | 获取列表大小

## ConfigMap

属性：

属性名 | 类型 | 解释
--- | --- | --- 
size | number | 
type | string | 如：“kMap”
element |  | 轉換成ConfigItem

方法：

方法名 | 参数 | 返回值 | 解释
--- | --- | --- | ---
set
get(key) | key: string | ConfigItem |
get_value(key) | key: string | ConfigValue | 
has_key | | boolean | 
clear
empty | | boolean | 
keys | | table | 

## ConfigList

属性：

属性名 | 类型 | 解释
--- | --- | --- 
size | number |
type | string | 如：“kList”
element |  |轉換成ConfigItem

方法：

方法名 | 参数 | 返回值 | 解释
--- | --- | --- | ---
get_at(index) | index: number <br> （下标从0开始）| ConfigItem |
get_value_at(index) | index: number <br> （下标从0开始）| ConfigValue | 
set_at
append
insert
clear
empty
resize

## ConfigValue

继承 ConfigItem

构造方法：`ConfigValue(str)`
1. str: 值（可通过 get_string 获得）

属性：

属性名 | 类型 | 解释
--- | --- | --- 
value | string | 
type | string | 如：“kScalar”
element| |轉換成ConfigItem

方法：

方法名 | 参数 | 返回值 | 解释
--- | --- | --- | ---
get_bool | | | `bool`是`int`子集，所以也可以用`get_int`来取得`bool`值
get_int
get_double
set_bool
set_int
set_double
get_string
set_string

## ConfigItem

属性：

属性名 | 类型 | 解释
--- | --- | --- 
type | string | 1. "kNull" <br> 2. "kScalar" <br> 3. "kList" <br> 4. "kMap"
empty

方法：

方法名 | 参数 | 返回值 | 解释
--- | --- | --- | ---
get_value | | | 当 type == "kScalar" 时使用
get_list | | | 当 type == "kList" 时使用
get_map | | | 当 type == "kMap" 时使用

## KeyEvent

按键事件对象。

> 当一般按键被按下、修饰键被按下或释放时均会产生按键事件（KeyEvent），触发 processor，此时 KeyEvent 会被作为第一个参数传递给已注册的 lua_processor。
* 一般按键按下时：生成该按键的keycode，此时保持按下状态的所有修饰键（Ctrl、Alt、Shift等）以bitwise OR形式储存于modifier中
* 修饰键被按下时：生成该修饰键的keycode，此时保持按下状态的所有修饰键（包括新近按下的这个修饰键）以bitwise OR形式储存于modifier中
* 修饰键被释放时：生成该修饰符的keycode，此时仍保持按下状态的所有修饰键外加一个通用的 `kRelease` 以bitwise OR形式储存于modifier中。

属性：

属性名 | 类型 | 解释
--- | --- | ---
keycode | number | 按键值，除ASCII字符外按键值与字符codepoint并不相等
modifier | | 当前处于按下状态的修饰键或提示有修饰键刚刚被抬起的`kRelease`

方法：

方法名 | 参数 | 返回值 | 解释
--- | --- | --- | ---
shift | | boolean | 触发事件时，shift是否被按下
ctrl | | boolean | 触发事件时，ctrl是否被按下
alt | | boolean | 触发事件时，alt/option是否被按下
caps <br> （CapsLk） | | boolean |
super | | boolean | 触发事件时，win/command是否被按下
release | | boolean | 是否因为修饰键被抬起`release`而触发事件
repr <br> （representation） | | string | 修饰键（含release）＋按键名（若没有按键名，则显示4位或6位十六进制X11按键码位 ≠ Unicode）
eq(key) <br> （equal） | key: KeyEvent | boolean | 两个 KeyEvent 是否“相等”
lt(key) <br> （less than） | key: KeyEvent | boolean | 对象小于参数时为 true

## KeySequence
> 形如`{按键1}{修饰键2+按键2}`的一串按键、组合键序列。一对花括号内的为一组组合键；序列有先后顺序

属性：

属性名 | 类型 | 解释
--- | --- | ---

方法：

方法名 | 参数 | 返回值 | 解释
--- | --- | --- | ---
parse
repr
toKeyEvent

## Candidate 候选词

`Candidate` 缺省为 `SimpleCandidate`（选中后不会更新用户字典）

构造方法：`Candidate(type, start, end, text, comment)`
1. type: 来源和类别标记
1. start: 分词开始
1. end: 分词结束
1. text: 候选词内容
1. comment: 注释

属性：

属性名 | 类型 | 解释
--- | --- | ---
type | string | 候选词来源和类别标记，根据源代码分析包含以下类型： <br> 1. **"completion"**: 编码未完整，需要继续输入的候选词（remaining_code_length != 0） <br> 2. **"user_table"**: 用户字典中的候选词，会随用户输入更新权重 <br> 3. **"table"**: 静态字典中的候选词，来自固定词典，不会更新权重 <br> 4. **"sentence"**: 由造句功能生成的句子候选词 <br> 5. **"user_phrase"**: 用户字典中的短语 <br> 6. **"phrase"**: 一般短语或词组 <br> 7. **"punct"**: 标点符号，来源有两种：<br>&nbsp;&nbsp;&nbsp;&nbsp;a) "engine/segmentors/punct_segmentor" <br>&nbsp;&nbsp;&nbsp;&nbsp;b) "symbols:/patch/recognizer/patterns/punct" <br> 8. **"simplified"**: 简化字候选词（可能由繁简转换产生） <br> 9. **"uniquified"**: 经过去重合并处理的候选词 <br> 10. **"thru"**: 直通字符（如ASCII字符直接输出，在commit_history中出现） 
start | number |
_start | number | 编码开始位置，如：“好” 在 “ni hao” 中的 _start=2
_end | number | 编码结束位置，如：“好” 在 “ni hao” 中的 _end=5
quality | number | 结果展示排名权重
text | string | 候选词内容
comment | string | 註解(name_space/comment_format) <br> ![image](https://user-images.githubusercontent.com/18041500/191151929-6d45e410-ccf8-4676-8146-c64bb3f4393e.png)
preedit | string | 得到当前候选词预处理后的输入编码（如形码映射字根、音码分音节加变音符，如："ni hao"）(name_space/preedit_format)

方法：

方法名 | 参数 | 返回值 | 解释
--- | --- | --- | ---
get_dynamic_type | | string | 1. "Phrase": Phrase <br> 2. "Simple": SimpleCandidate <br> 3. "Shadow": ShadowCandidate <br> 4. "Uniquified": UniquifiedCandidate <br> 5. "Other"
get_genuine | | Candidate | 获取真实的候选词对象
get_genuines | | table | 获取真实候选词的列表
spans | | Spans | 获取候选词的跨度信息，用于词语分割显示
to_shadow_candidate | | ShadowCandidate | 转换为衍生候选词
to_uniquified_candidate | | UniquifiedCandidate | 转换为去重候选词
append(candidate) | candidate: Candidate | boolean | 追加候选词
to_phrase | | Phrase | 转换为词组对象，可能返回 nil

## ShadowCandidate 衍生扩展词

<https://github.com/hchunhui/librime-lua/pull/162>

`ShadowCandidate`（典型地，simplifier 繁简转换产生的新候选词皆为`ShadowCandidate`）

构造方法：`ShadowCandidate(cand, type, text, comment, inherit_comment)`
1. cand
1. type
1. text
1. comment
1. inherit_comment: （可选）

## Phrase 词组

`Phrase`（选择后会更新相应的用户字典）

构造方法：`Phrase(memory, type, start, end, entry)`
1. memory: Memory
1. type: string
1. start: number
1. end: number
1. entry: DictEntry

属性：

属性名 | 类型 | 解释
--- | --- | ---
language
type
start
_start
_end
quality
text
comment
preedit
weight
code
entry

方法：

方法名 | 参数 | 返回值 | 解释
--- | --- | --- | ---
toCandidate | | Candidate | 转换为Candidate对象
spans | | Spans | 获取词组的跨度信息，显示词组内部的分割结构

### 候选词来源翻译器识别

**问题背景**：在多翻译器环境中，开发者常常需要知道某个候选词是由哪个翻译器生成的，以便进行调试、过滤或者差异化处理。

**核心结论**：Rime和librime-lua默认**不提供**候选词与源翻译器的直接关联信息。候选词对象本身不携带生成它的翻译器标识。

#### 解决方案

##### 1. 利用候选词类型字段（推荐）

最实用的方法是在创建候选词时，将翻译器标识信息编码到 `type` 或 `comment` 字段中：

**Translator阶段标识**：
```lua
-- 在翻译器中创建候选词时标识来源
local function translate(input, seg, env)
    -- 创建 Phrase 时，第二个参数是 type，可以用来标识翻译器
    local phrase = Phrase(env.mem, env.name_space, seg.start, seg._end, dict_entry)
    yield(phrase:toCandidate())
    
    -- 或者创建 SimpleCandidate 时指定 type
    yield(Candidate(env.name_space, seg.start, seg._end, text, comment))
end
```

**Filter阶段识别**：
```lua
local function filter(input, env)
    for cand in input:iter() do
        -- 根据 type 字段识别来源翻译器
        if cand.type == "my_translator" then
            -- 处理来自 my_translator 的候选词
            log.info("候选词来自 my_translator: " .. cand.text)
        elseif cand.type == "script_translator" then
            -- 处理来自 script_translator 的候选词
            log.info("候选词来自 script_translator: " .. cand.text)
        end
        yield(cand)
    end
end
```

##### 2. 在注释中添加标识信息

将翻译器信息附加到候选词的注释中：

```lua
-- Translator 中添加标识
local function translate(input, seg, env)
    local phrase = Phrase(env.mem, "table", seg.start, seg._end, dict_entry)
    -- 在注释中添加翻译器标识
    phrase.comment = phrase.comment .. " [" .. env.name_space .. "]"
    yield(phrase:toCandidate())
end

-- Filter 中识别
local function filter(input, env)
    for cand in input:iter() do
        if cand.comment:find("%[my_translator%]") then
            -- 处理来自 my_translator 的候选词
        end
        yield(cand)
    end
end
```

##### 3. 候选词包装器模式

创建一个包装候选词的方法，自动添加翻译器标识：

```lua
-- 在翻译器初始化中定义包装函数
local function init(env)
    env.make_candidate = function(type, start, _end, text, comment)
        return Candidate(env.name_space .. ":" .. type, start, _end, text, comment)
    end
end

local function translate(input, seg, env)
    -- 使用包装函数创建带标识的候选词
    yield(env.make_candidate("table", seg.start, seg._end, text, comment))
end
```

#### 实际使用示例

**场景**：区分来自不同词典的候选词

```lua
-- expand_translator.lua (展开翻译器)
local function translate(inp, seg, env)
    if string.match(inp, env.wildcard) then
        -- ... 处理逻辑 ...
        -- 注意这里第二个参数"expand_translator"就是翻译器标识
        local ph = Phrase(env.mem, "expand_translator", seg.start, seg._end, dictentry)
        ph.comment = codeComment
        yield(ph:toCandidate())
    end
end

-- filter.lua (过滤器)
local function filter(input, env)
    for cand in input:iter() do
        if cand.type == "expand_translator" then
            -- 这是来自展开翻译器的候选词
            cand.comment = cand.comment .. " 🔍"
        elseif cand.type == "table" then
            -- 这是来自主词典的候选词  
            cand.comment = cand.comment .. " 📖"
        end
        yield(cand)
    end
end
```

#### 最佳实践建议

1. **一致性命名**：使用翻译器的 `name_space` 作为标识符，保持命名一致性
2. **避免污染显示**：如果标识信息不需要显示给用户，建议放在 `type` 字段而不是 `comment` 字段
3. **文档记录**：在代码中记录使用的标识约定，便于团队协作
4. **性能考虑**：标识检查应该尽量简单快速，避免使用复杂的正则表达式

#### 常见的候选词类型

根据源代码分析，以下是Rime中常见的内置候选词类型：

- `"table"`: 主词典候选词
- `"user_table"`: 用户词典候选词  
- `"completion"`: 待完成的候选词
- `"sentence"`: 句子候选词
- `"user_phrase"`: 用户短语
- `"punct"`: 标点符号
- `"simplified"`: 简化字候选词

建议自定义翻译器使用与这些内置类型不同的命名，以避免混淆。

## UniquifiedCandidate 去重合并候选词

<https://github.com/hchunhui/librime-lua/pull/162>

`UniqifiedCandidate(cand, type, text, comment)` （典型地，uniqifier 合并重复候选词之后形成的唯一候选词即为`UniqifiedCandidate`）

## Set

集合数据结构，支持集合运算。Set将列表中的元素作为键存储，值为true，自动去重。主要用于标签管理和集合运算。

构造方法：`Set(table)`
1. table: 列表，元素将被作为集合的成员

**示例**：
```lua
local set_tab = Set({'a','b','c','c'}) 
-- 结果: set_tab = {a=true, b=true, c=true}
-- 注意：重复的'c'被自动去重
```

属性：

属性名 | 类型 | 解释
--- | --- | ---
无公开属性 | | Set使用table结构存储，键为集合元素，值为true

方法：

方法名 | 参数 | 返回值 | 解释
--- | --- | --- | ---
empty | | boolean | 检查集合是否为空（不包含任何元素）
__index | | function | 元方法，用于属性和方法访问
__add | other_set: Set | Set | 元方法，集合并集运算（+操作符）。返回包含两个集合所有元素的新集合
__sub | other_set: Set | Set | 元方法，集合差集运算（-操作符）。返回在第一个集合中但不在第二个集合中的元素
__mul | other_set: Set | Set | 元方法，集合交集运算（*操作符）。返回两个集合共同包含的元素
__set | | function | 内部元方法，用于Set类型标识

**集合运算详解**：

```lua
-- 创建集合
local set1 = Set{'a', 'b', 'c'}
local set2 = Set{'b', 'c', 'd'}

-- 并集运算 (+)
local union_set = set1 + set2
-- 结果: {'a', 'b', 'c', 'd'}

-- 差集运算 (-)  
local diff_set = set1 - set2
-- 结果: {'a'}

-- 交集运算 (*)
local inter_set = set1 * set2  
-- 结果: {'b', 'c'}

-- 检查集合是否为空
if inter_set:empty() then
   print("没有共同元素")
else
   print("有共同元素")
end
```

**实际应用示例**：

```lua
-- 在Segment标签检查中的应用
local seg = composition:back()
local pinyin_tags = Set{'pinyin', 'abc'}
local reverse_tags = Set{'reverse', 'stroke'}

-- 检查segment是否包含拼音相关标签
if not (seg.tags * pinyin_tags):empty() then
   -- segment包含pinyin或abc标签之一
   print("这是拼音输入")
end

-- 检查segment是否包含反查标签  
if not (seg.tags * reverse_tags):empty() then
   -- segment包含reverse或stroke标签之一
   print("这是反查输入")
end

-- 组合多个条件
local input_tags = Set{'pinyin', 'abc', 'reverse'}
local current_tags = seg.tags * input_tags
if not current_tags:empty() then
   print("识别到支持的输入类型")
end
```

**注意事项**：
1. Set中的元素顺序不保证，它是基于哈希表实现的
2. Set自动去除重复元素
3. 集合运算返回的都是新的Set对象，不会修改原始集合
4. 空集合的empty()方法返回true

## Menu

候选词菜单对象，管理和组织候选词列表。可以添加翻译结果、应用过滤器，并提供候选词的访问接口。

构造方法：`Menu()`

属性：

属性名 | 类型 | 解释
--- | --- | ---
无公开属性 | | Menu对象不暴露任何可直接访问的属性

方法：

方法名 | 参数 | 返回值 | 解释
--- | --- | --- | ---
add_translation | translation: Translation | | 添加翻译结果到菜单中。将Translation对象合并到内部的MergedTranslation中
prepare | candidate_count: number | number | 准备指定数量的候选词。返回实际准备的候选词数量（可能少于请求数量，如果翻译结果已用尽）
get_candidate_at | index: number | Candidate | 获取指定索引位置的候选词。如果索引超出当前候选词范围，会尝试从翻译结果中获取更多候选词。索引从0开始
candidate_count | | number | 获取当前已获得的候选词数量（注意：这是当前已加载的候选词数量，而不是总的可用候选词数量）
empty | | boolean | 检查菜单是否为空（没有候选词且翻译结果已用尽）

## Opencc

构造方法：`Opencc(filename)`
1. filename: string

属性：

属性名 | 类型 | 解释
--- | --- | ---

方法：

方法名 | 参数 | 返回值 | 解释
--- | --- | --- | ---
convert

## ReverseDb / ReverseLookup

反查

构造方法：`ReverseDb(file_name)` 
1. file_name: 反查字典文件路径。 如: `build/terra_pinyin.reverse.bin`

e.g.
```lua
local pyrdb = ReverseDb("build/terra_pinyin.reverse.bin")
```

属性：

属性名 | 类型 | 解释
--- | --- | ---

方法：

方法名 | 参数 | 返回值 | 解释
--- | --- | --- | ---
lookup | 

## ReverseLookup (ver #177)

构造方法：`ReverseLookup(dict_name)`
1. dict_name: 字典名。 如: `luna_pinyin`

属性：

属性名 | 类型 | 解释
--- | --- | ---

方法：

方法名 | 参数 | 返回值 | 解释
--- | --- | --- | ---
lookup(key) | key: string | string | 如：`ReverseLookup("luna_pinyin"):lookup("百") == "bai bo"`
lookup_stems | 

## CommitEntry

继承 DictEntry

属性：

属性名 | 类型 | 解释
--- | --- | ---

方法：

方法名 | 参数 | 返回值 | 解释
--- | --- | --- | ---
get

## DictEntry

构造方法：`DictEntry()`

>librime 定义：https://github.com/rime/librime/blob/ae848c47adbe0411d4b7b9538e4a1aae45352c31/include/rime/impl/vocabulary.h#L33

属性：

属性名 | 类型 | 解释
--- | --- | ---
text | string | 词，如：“好”
comment | string | 剩下的编码，如：preedit "h", text "好", comment "~ao"
preedit | string | 如：“h”
weight | number | 如：“-13.998352335763”
commit_count | number | 如：“2”
custom_code | string | 词编码（根据特定规则拆分，以" "（空格）连接，如：拼音中以音节拆分），如：“hao”、“ni hao”
remaining_code_length | number | （预测的结果中）未输入的编码，如：preedit "h", text "好", comment "~ao"， remaining_code_length “2”
code | Code

方法：

方法名 | 参数 | 返回值 | 解释
--- | --- | --- | ---

## Code

构造方法：`Code()`

属性：

属性名 | 类型 | 解释
--- | --- | ---

方法：

方法名 | 参数 | 返回值 | 解释
--- | --- | --- | ---
push(inputCode) | rime::SyllableId <br> （librime中定义的类型） | 
print | | string | 

## Memory

提供来操作 dict（字典、固态字典、静态字典）和 user_dict（用户字典、动态字典）的接口


构造方法：`Memory(engine, schema, name_space)`
1. engine: Engine
2. schema: Schema
3. name_space: string （可选，默认为空）

* **Memory 字典中有userdb 須要在function fini(env) 中執行 env.mem:disconnect() 關閉 userdb 避免記憶泄露和同步(sync)報錯**

e.g.

```lua
env.mem = Memory(env.engine, env.engine.schema)  --  ns = "translator"
-- env.mem = Memory(env.engine, env.engine.schema, env.name_space)  
-- env.mem = Memory(env.engine, Schema("cangjie5")) --  ns = "translator-
-- env.mem = Memory(env.engine, Schema("cangjie5"), "translator") 
```

构造流程：https://github.com/rime/librime/blob/3451fd1eb0129c1c44a08c6620b7956922144850/src/gear/memory.cc#L51
1. 加载 schema 中指定的字典（dictionary）<br>
（包括："`{name_space}/dictionary`"、"`{name_space}/prism`"、"`{name_space}/packs`"）
2. 加在 schema 中指定的用户字典（user_dict）<br>
（前提：`{name_space}/enable_user_dict` 为 true）<br>
（包括："`{name_space}/user_dict`" 或 "`{name_space}/dictionary`"）<br>
（后缀："`*.userdb.txt`"）
3. 添加通知事件监听（commit_notifier、delete_notifier、unhandled_key_notifier）

属性：

属性名 | 类型 | 解释
--- | --- | ---

方法：

方法名 | 参数 | 返回值 | 解释
--- | --- | --- | ---
dict_lookup(input, predictive, limit) | input: string, predictive: boolean, limit: number | boolean | 在字典中查找，返回是否有结果
user_lookup(input, predictive) | input: string, predictive: boolean | boolean | 在用户字典中查找
memorize(callback) | callback: function | | 当用户字典候选词被选中时触发回调（回调参数：CommitEntry）
decode(code) | code: Code | table | 解码，返回字符串列表
iter_dict | | iterator | 配合 `for ... end` 获得 DictEntry，遍历字典
iter_user | | iterator | 配合 `for ... end` 获得 DictEntry，遍历用户字典
update_userdict(entry, commits, prefix) | entry: DictEntry, commits: number, prefix: string | boolean | 更新用户字典条目
disconnect | | | 断开内存对象连接，释放资源（必须在fini中调用以避免内存泄漏） 

使用案例：https://github.com/hchunhui/librime-lua/blob/67ef681a9fd03262c49cc7f850cc92fc791b1e85/sample/lua/expand_translator.lua#L32

e.g. 
```lua
-- 遍历

local input = "hello"
local mem = Memory(env.engine, env.engine.schema) 
mem:dict_lookup(input, true, 100)
-- 遍历字典
for entry in mem:iter_dict() do
 print(entry.text)
end

mem:user_lookup(input, true)
-- 遍历用户字典
for entry in mem:iter_user() do
 print(entry.text)
end

-- 监听 & 更新

env.mem = Memory(env.engine, env.engine.schema) 
env.mem:memorize(function(commit) 
  for i,dictentry in ipairs(commit:get()) do
    log.info(dictentry.text .. " " .. dictentry.weight .. " " .. dictentry.comment .. "")
    -- memory:update_userdict(dictentry, 0, "") -- do nothing to userdict
    -- memory:update_userdict(dictentry, 1, "") -- update entry to userdict
    -- memory:update_userdict(dictentry, -1, "") -- delete entry to userdict
    --[[
      用户字典形式如：

      # Rime user dictionary
      #@/db_name	luna_pinyin.userdb
      #@/db_type	userdb
      #@/rime_version	1.5.3
      #@/tick	693
      #@/user_id	aaaaaaaa-bbbb-4c62-b0b0-ccccccccccc
      wang shang 	网上	c=1 d=0.442639 t=693
      wang shi zhi duo shao 	往事知多少	c=1 d=0.913931 t=693
      wang xia 	往下	c=1 d=0.794534 t=693
      wei 	未	c=1 d=0.955997 t=693
  end
end
```

## Projection

可以用于处理 candidate 的 comment 的转换

构造：`Projection()`

属性：

属性名 | 类型 | 解释
--- | --- | ---
Projection([ConfigList| string of table])
方法：

方法名 | 参数 | 返回值 | 解释
--- | --- | --- | ---
load(rules) | rules: ConfigList | - | 加载转换规则
apply(str,[ret_org_str]) | str: string, ret_org_str: bool  | string | 转换字符串: 預設轉換失敗返回 空字串， ret_org_str: true 返回原字串 

使用参考： <https://github.com/hchunhui/librime-lua/pull/102>

```lua
local config = env.engine.schema.config
-- load ConfigList form path
local proedit_fmt_list = conifg:get_list("translator/preedit_format")
-- create Projection obj
local p1 = Projection()
-- load convert rules
p1:load(proedit_fmt_list)
-- convert string
local str_raw = "abcdefg"
local str_preedit = p1:apply(str)

-- new example
  local p2 = Projection(config:get_list('translator/preedit_format'))
  local p3 = Projection({'xlit/abc/ABC/', 'xlit/ABC/xyz/'})
   p3:apply(str,[true]) 

```

## Component

調用 processor, segmentor, translator, filter 組件，可在lua script中再重組。
參考範例: [librime-lua/sample/lua/component_test.lua](https://github.com/hchunhui/librime-lua/tree/master/sample/lua/component_test.lua)

构造方法（静态方法）：

方法名 | 参数 | 返回值 | 解释
--- | --- | --- | ---
Processor(engine, [schema,] name_space, class_name) | engine: Engine, schema: Schema (可选), name_space: string, class_name: string | Processor | 创建处理器组件。如：`Component.Processor(env.engine, "", "ascii_composer")`, `Component.Processor(env.engine, Schema('cangjie5'), "", 'ascii_composer)`(使用Schema: cangjie5 config)
Segmentor(engine, [schema,] name_space, class_name) | 同上 | Segmentor | 创建分段器组件
Translator(engine, [schema,] name_space, class_name) | 同上 | Translator | 创建翻译器组件。如：`Component.Translator(env.engine, '', 'table_translator')`
Filter(engine, [schema,] name_space, class_name) | 同上 | Filter | 创建过滤器组件。如：`Component.Filter(env.engine, '', 'uniquifier')`

## Processor

处理器组件，用于处理按键事件。

属性：

属性名 | 类型 | 解释
--- | --- | ---
name_space | string | 组件实例的命名空间

方法：

方法名 | 参数 | 返回值 | 解释
--- | --- | --- | ---
process_key_event(key) | key: KeyEvent | number | 处理按键事件。返回值：0=kRejected（拒绝）, 1=kAccepted（接受）, 2=kNoop（无操作）。[參考engine.cc](https://github.com/rime/librime/blob/9086de3dd802d20f1366b3080c16e2eedede0584/src/rime/engine.cc#L107-L111)

## Segmentor

分段器组件，用于对输入进行分段。

属性：

属性名 | 类型 | 解释
--- | --- | ---
name_space | string | 组件实例的命名空间

方法：

方法名 | 参数 | 返回值 | 解释
--- | --- | --- | ---
proceed(segmentation) | segmentation: Segmentation | boolean | 对输入进行分段处理。[參考engine.cc](https://github.com/rime/librime/blob/9086de3dd802d20f1366b3080c16e2eedede0584/src/rime/engine.cc#L168)

## Translator

翻译器组件，用于将输入转换为候选词。

属性：

属性名 | 类型 | 解释
--- | --- | ---
name_space | string | 组件实例的命名空间

方法：

方法名 | 参数 | 返回值 | 解释
--- | --- | --- | ---
query(input, segment) | input: string, segment: Segment | Translation | 查询翻译结果。[參考engine.cc](https://github.com/rime/librime/blob/9086de3dd802d20f1366b3080c16e2eedede0584/src/rime/engine.cc#L189-L218)

## Filter

过滤器组件，用于过滤和修改候选词。

属性：

属性名 | 类型 | 解释
--- | --- | ---
name_space | string | 组件实例的命名空间

方法：

方法名 | 参数 | 返回值 | 解释
--- | --- | --- | ---
apply(translation, candidates) | translation: Translation, candidates: table | Translation | 应用过滤器处理。[參考engine.cc](https://github.com/rime/librime/blob/9086de3dd802d20f1366b3080c16e2eedede0584/src/rime/engine.cc#L189-L218)
applies_to_segment(segment) | segment: Segment | boolean | 检查过滤器是否适用于指定片段

## Notifier

接收通知

通知类型：
1. commit_notifier
2. select_notifier
3. update_notifier
4. delete_notifier

属性：

属性名 | 类型 | 解释
--- | --- | ---

方法： 

方法名 | 参数 | 返回值 | 解释
--- | --- | --- | ---
connect(func, group) | func: function, group: number (可选) | Connection | 连接通知回调函数。group参数可指定优先级（0,1,...），connect(func)排在最后。**使用notifier时必须在解构时disconnect()** 


e.g.
```lua
-- ctx: Context
function init(env)
  env.notifier = env.engine.context.commit_notifier:connect(function(ctx)
  -- your code ...
end)
end
function fini(env)
   env.notifier:disconnect()
end
```

## OptionUpdateNotifier

同 Notifier

e.g.
```lua
-- ctx: Context
-- name: string
env.engine.context.option_update_notifier:connect(function(ctx, name)
  -- your code ...
end)
```

## PropertyUpdateNotifier

同 Notifier

e.g.
```lua
-- ctx: Context
-- name: string
env.engine.context.property_update_notifier:connect(function(ctx, name)
  -- your code ...
end)
```

## KeyEventNotifier

同 Notifier

e.g.
```lua
-- ctx: Context
-- key: KeyEvent
env.engine.context.unhandled_key_notifier:connect(function(ctx, key)
  -- your code ...
end)
```

## Connection

连接对象，用于管理通知器的连接。

属性：

属性名 | 类型 | 解释
--- | --- | ---

方法：

方法名 | 参数 | 返回值 | 解释
--- | --- | --- | ---
disconnect | | | 断开通知器连接，释放资源

## log

记录日志到日志文件

日志位置：<https://github.com/rime/home/wiki/RimeWithSchemata#%E9%97%9C%E6%96%BC%E8%AA%BF%E8%A9%A6>
+ 【中州韻】 `/tmp/rime.ibus.*`
+ 【小狼毫】 `%TEMP%\rime.weasel.*`
+ 【鼠鬚管】 `$TMPDIR/rime.squirrel.*`
+ 各發行版的早期版本 `用戶資料夾/rime.log`

属性：

属性名 | 类型 | 解释
--- | --- | ---

方法：

方法名 | 参数 | 返回值 | 解释
--- | --- | --- | ---
info(message) | message: string | | 记录信息级别日志
warning(message) | message: string | | 记录警告级别日志
error(message) | message: string | | 记录错误级别日志

## rime_api

属性：

属性名 | 类型 | 解释
--- | --- | ---

方法：

方法名 | 参数 | 返回值 | 解释
--- | --- | --- | ---
get_rime_version | | string | 获取librime版本信息
get_shared_data_dir | | string | 获取程序共享数据目录路径
get_user_data_dir | | string | 获取用户数据目录路径
get_sync_dir | | string | 获取用户资料同步目录路径
get_distribution_name | | string | 如：“小狼毫”
get_distribution_code_name | | string | 如：“Weasel”
get_distribution_version | | string | 发布版本号
get_user_id | | string | 获取用户ID
regex_match | input: string, pattern: string | boolean | 使用正则表达式匹配字符串，返回是否匹配
regex_search | input: string, pattern: string | string[] \| nil | 使用正则表达式搜索字符串，返回匹配的字符串数组或nil
regex_replace | input: string, pattern: string, fmt: string | string | 使用正则表达式替换字符串中的匹配部分

## CommitRecord

CommitRecord : 參考 librime/src/rime/ engine.cc commit_history.h 
* commit_text => `{type: 'raw', text: string}`
* commit => `{type: cand.type, text: cand.text}`
* reject => `{type: 'thru', text: ascii code}`

属性：

属性名 | 类型 | 解释
--- | --- | ---
type| string |
text| string |

## CommitHistory

engine 在 commit commit_text 會將 資料存入 commit_history, reject且屬於ascii範圍時存入ascii
此api 除了可以取出 CommitRecord 還可以在lua中推入commit_record
參考: librime/src/rime/gear/history_translator

属性：

属性名 | 类型 | 解释
--- | --- | ---
size| number| max_size <=20

方法：

方法名 | 参数 | 返回值 | 解释
--- | --- | --- | ---
push|(KeyEvent), (composition, ctx.input) (cand.type, cand.text)| |推入 CommitRecord
back| | CommitRecord|取出最後一個 CommitRecord
to_table| | lua table of CommitRecord|轉出 lua table of CommitRecord
iter| | | reverse_iter
repr| | string| 格式 [type]text[type]text....
latest_text| | string | 取出最後一個CommitRecord.text
empty| | bool
clear| | | size=0
pop_back| | | 移除最後一個CommitRecord

```lua
-- 將comit cand.type == "table" 加入 translation
local T={}
function T.func(inp, seg, env)
  if not seg.has_tag('histroy') then return end

  for r_iter, commit_record in context.commit_history:iter() do
    if commit_record.type == "table" then
       yield(Candidate(commit_record.type, seg.start, seg._end, commit_record.text, "commit_history"))
    end
  end
end
return T
```

## DbAssessor 
支援 leveldb:query(prefix_key) 

methods: obj of LevelDb
 方法名 | 参数 | 返回值 | 解释
--- | --- | --- | ---
reset| none | bool| jump to begin
jump | prefix of key:string|bool| jump to first of prefix_key 
iter | none | iter_func,self| 範例: for k, v in da:iter() do print(k, v) end

请注意， **`DbAccessor` 必须先于其引用的 `LevelDb` 对象释放，否则会导致输入法崩溃** ！ 由于目前 `DbAccessor` 没有封装析构接口，常规做法是将引用 `DbAccessor` 的变量置空，然后调用 `collectgarbage()` 来释放掉 `DbAccessor` 。

```lua
local da = db:query(code)
da = nil
collectgarbage() -- 确保 da 所引用的 DbAccessor 被释放
db:close()       -- 此时关闭 db 才是安全的，否则可能造成输入法崩溃
```

## LevelDb ( 不可用於已開啓的userdb, 專用於 librime-lua key-value db)

便於調用大型資料庫且不佔用 lua 動態記憶

### 新建 leveldb
 方法名 | 参数 | 返回值 | 解释
--- | --- | --- | ---
LevelDb| dbname:string| obj of LevelDb| local db = LevelDb('ecdict') -- opendb :user_data_dir/ecdict 

### 物件方法
 方法名 | 参数 | 返回值 | 解释
--- | --- | --- | ---
open| none| bool| 
open_read_only| none| bool| 禁用 earse ,update
close| none| bool|
loaded| none| bool| 
query| prefix of key:string|obj of DbAccessor| 查找 prefix key 
fetch| key:string| value:string or nil| 查找 value
update| key:string,value:string|bool|
erase| key:string|bool|

範例：
```lua
 -- 建議加入 db_pool 可避免無法開啓已開啓DB
 _db_pool= _db_pool or {}
 local function wrapLevelDb(dbname, mode)
   _db_pool[dbname] = _db_pool[dbname] or LevelDb(dbname)
   local db = _db_pool[dbname]
   if db and not db:loaded() then
      if mode then
        db:open()
      else 
        db:open_read_only()
      end
      return db
   end
 end
 
 local db = wrapLevelDb('ecdict') -- open_read_only
 -- local db = wrapLevelDb('ecdictu', true) -- open
 local da = db:query('the') -- return obj of DbAccessor
 for k, v in da:iter() do print(k, v) end
```

请注意， **`DbAccessor` 必须先于其引用的 `LevelDb` 对象释放，否则会导致输入法崩溃** ！详见 `DbAccessor` 的说明。

## Recognizer 识别器与 Patterns 模式匹配

### 概述

`recognizer` 是 Rime 输入引擎中的一个关键处理器（Processor），负责识别用户输入中符合特定模式的内容，并与 `matcher` 分段器配合为输入段落添加标签（tag）。这种机制使得 Rime 能够支持多种输入模式，如符号输入、反查、计算器、Unicode 字符输入等。

### 工作原理

#### 1. 处理流程

```
用户输入 → recognizer 模式匹配 → matcher 添加标签 → 路由到对应翻译器
```

#### 2. 在引擎配置中的位置

```yaml
engine:
  processors:
    - ascii_composer
    - recognizer          # ← 识别特殊模式
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

### Recognizer 配置语法

#### 基本格式

```yaml
recognizer:
  import_preset: default  # 继承默认配置
  patterns:               # 自定义模式
    pattern_name: "^regex_pattern$"
    another_pattern: "^another_regex$"
```

#### 实际配置示例

```yaml
recognizer:
  import_preset: default
  patterns:
    # 符号输入：/1 /abc /10
    punct: "^/([0-9]|10|[A-Za-z]+)$"
    
    # 部件拆字反查：&abc &木
    radical_lookup: "^&[A-Za-z]*$"
    
    # 自造词：&&abc
    add_user_dict: "^&&[A-Za-z/&&']*$"
    
    # Unicode 字符：U4e00 Uabcd
    unicode: "^U[a-f0-9]+"
    
    # 数字金额大写：R123 R12.34
    number: "^R[0-9]+[.]?[0-9]*"
    
    # 公历转农历：N20240115
    gregorian_to_lunar: "^N[0-9]{1,8}"
    
    # 计算器功能：V1+2 V100*0.8
    calculator: "^V.*$"
    
    # 快速符号：;q ;hello
    quick_symbol: "^;.*$"
```

### 标签（Tags）系统

#### 标签的作用

当 `recognizer` 识别到匹配的模式时，`matcher` 会为输入段落添加相应的标签：

1. **路由控制**：决定哪个翻译器处理该段落
2. **过滤控制**：决定哪个过滤器应用于该段落  
3. **格式控制**：决定如何显示和处理该段落

#### 标签与翻译器的对应

```yaml
engine:
  translators:
    - script_translator                          # tag: abc (默认)
    - reverse_lookup_translator@radical_lookup   # tag: radical_lookup
    - lua_translator@unicode                     # tag: unicode
    - lua_translator@number_translator           # tag: number
    - lua_translator@calculator                  # tag: calculator
```

### 在 Lua 中使用标签

#### 在翻译器中检查标签

```lua
function translator(input, seg, env)
  -- 检查当前段落是否有特定标签
  if seg:has_tag("unicode") then
    -- 处理 Unicode 输入
    local code = input:sub(2) -- 去掉前缀 U
    local char = utf8.char(tonumber(code, 16))
    yield(Candidate("unicode", seg.start, seg._end, char, "Unicode字符"))
    
  elseif seg:has_tag("number") then
    -- 处理数字转大写
    local number = input:sub(2) -- 去掉前缀 R
    local chinese_number = convert_to_chinese(number)
    yield(Candidate("number", seg.start, seg._end, chinese_number, "大写数字"))
    
  elseif seg:has_tag("calculator") then
    -- 处理计算器输入
    local expression = input:sub(2) -- 去掉前缀 V
    local result = calculate(expression)
    yield(Candidate("calculator", seg.start, seg._end, tostring(result), "计算结果"))
  end
end
```

#### 在过滤器中检查标签

```lua
function filter(input, env)
  local context = env.engine.context
  local composition = context.composition
  
  for cand in input:iter() do
    -- 获取当前段落
    local seg = composition:back()
    
    if seg and seg:has_tag("special_processing") then
      -- 对特殊标签的候选词进行特殊处理
      cand.comment = "【特殊】" .. cand.comment
    end
    
    yield(cand)
  end
end
```

#### 访问段落的所有标签

```lua
function debug_segment_tags(seg)
  local tags = seg.tags
  if tags then
    log.info("段落标签: " .. tags)
    
    -- 检查特定标签
    if seg:has_tag("unicode") then
      log.info("这是一个 Unicode 输入段落")
    end
    
    if seg:has_tag("reverse_lookup") then
      log.info("这是一个反查段落")
    end
  end
end
```

### 常用模式模板

#### 1. 前缀模式

```yaml
# 以特定字符开头的输入
prefix_pattern: "^prefix.*$"

# 实例：快速符号
quick_symbol: "^;.*$"
```

#### 2. 数字模式

```yaml
# 纯数字
pure_number: "^[0-9]+$"

# 数字加小数点
decimal_number: "^[0-9]+([.][0-9]*)?$"

# 带前缀的数字
prefixed_number: "^R[0-9]+[.]?[0-9]*$"
```

#### 3. 字符类模式

```yaml
# 字母数字混合
alphanumeric: "^[A-Za-z0-9]+$"

# 十六进制
hexadecimal: "^[0-9A-Fa-f]+$"

# Unicode 编码
unicode: "^U[a-f0-9]+"
```

#### 4. 复杂模式

```yaml
# 邮箱格式（简化）
email: "^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$"

# URL 格式（简化）  
url: "^https?://.*$"

# 固定长度
fixed_length: "^.{4,8}$"
```

### 与 Translation 和 Candidate 分析的结合

#### 识别候选词来源翻译器

结合 recognizer 标签，可以更好地识别候选词的来源：

```lua
function identify_candidate_source(cand, seg, env)
  local source = "unknown"
  
  -- 通过段落标签识别
  if seg:has_tag("unicode") then
    source = "unicode_translator"
  elseif seg:has_tag("calculator") then
    source = "calculator_translator" 
  elseif seg:has_tag("reverse_lookup") then
    source = "reverse_lookup_translator"
  else
    -- 通过候选词类型识别
    if cand.type == "sentence" then
      source = "script_translator"
    elseif cand.type == "word" then
      source = "table_translator"
    end
  end
  
  return source
end
```

#### 在 Filter 阶段进行完整分析

```lua
function analysis_filter(input, env)
  local context = env.engine.context
  local composition = context.composition
  local seg = composition:back()
  
  local candidates = {}
  
  -- 收集所有候选词
  for cand in input:iter() do
    local source = identify_candidate_source(cand, seg, env)
    
    -- 添加来源信息到注释
    if env.engine.context:get_option("show_source") then
      cand.comment = cand.comment .. " 〔" .. source .. "〕"
    end
    
    table.insert(candidates, {
      text = cand.text,
      type = cand.type,
      source = source,
      quality = cand.quality
    })
    
    yield(cand)
  end
  
  -- 记录分析结果
  log.info("段落分析完成，共 " .. #candidates .. " 个候选词")
  for i, info in ipairs(candidates) do
    log.info(string.format("候选词 %d: %s [%s] <%s> (%.3f)", 
      i, info.text, info.type, info.source, info.quality))
  end
end
```

### 调试和监控

#### 监控 recognizer 行为

```lua
function monitor_recognizer(key, env)
  local context = env.engine.context
  local input = context.input
  
  if input and #input > 0 then
    log.info("当前输入: " .. input)
    
    local composition = context.composition
    if not composition:empty() then
      local seg = composition:back()
      if seg then
        log.info("段落标签: " .. (seg.tags or "无标签"))
        log.info("段落范围: " .. seg.start .. "-" .. seg._end)
      end
    end
  end
  
  return kNoop -- 不处理按键，仅监控
end
```

#### 标签统计

```lua
local tag_stats = {}

function collect_tag_stats(input, env)
  local context = env.engine.context
  local composition = context.composition
  local seg = composition:back()
  
  if seg and seg.tags then
    -- 统计标签使用频率
    local tags = seg.tags
    tag_stats[tags] = (tag_stats[tags] or 0) + 1
    
    -- 每100次输入输出一次统计
    local total = 0
    for _, count in pairs(tag_stats) do
      total = total + count
    end
    
    if total % 100 == 0 then
      log.info("标签使用统计:")
      for tag, count in pairs(tag_stats) do
        log.info(string.format("  %s: %d次 (%.1f%%)", 
          tag, count, count/total*100))
      end
    end
  end
  
  for cand in input:iter() do
    yield(cand)
  end
end
```

### 最佳实践

#### 1. 模式设计原则

- **精确匹配**：使用 `^` 和 `$` 确保完整匹配
- **避免冲突**：确保不同模式不会互相干扰
- **性能优先**：简单模式优先，复杂正则表达式谨慎使用

#### 2. 标签命名规范

- 使用有意义的名称：`unicode` 而不是 `u`
- 保持一致性：`reverse_lookup` 而不是混用 `reverselookup`
- 避免冲突：确保标签名称唯一

#### 3. 错误处理

```lua
function safe_pattern_match(input, pattern)
  local success, result = pcall(function()
    return string.match(input, pattern)
  end)
  
  if success then
    return result
  else
    log.error("正则表达式错误: " .. pattern)
    return nil
  end
end
```

#### 4. 性能优化

```lua
-- 缓存编译后的正则表达式
local compiled_patterns = {}

function get_compiled_pattern(pattern)
  if not compiled_patterns[pattern] then
    compiled_patterns[pattern] = compile_regex(pattern)
  end
  return compiled_patterns[pattern]
end
```

### 总结

Rime 的 `recognizer` 系统通过正则表达式模式匹配和标签机制，为输入法提供了强大的多模态输入支持。理解其工作原理和配置方法，对于开发复杂的输入法功能至关重要。

关键要点：
1. **模式匹配**：基于正则表达式识别特定输入格式
2. **标签系统**：为不同类型输入分配标签，实现路由控制
3. **模块协作**：与 matcher、translator、filter 紧密配合
4. **可扩展性**：支持自定义模式和 Lua 扩展逻辑
5. **调试支持**：提供丰富的调试和监控机制

通过合理配置和使用 recognizer，可以实现符号输入、计算器、Unicode 输入、反查等各种高级功能。







