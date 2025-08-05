# Rime翻译器API真实调用方式分析

## 问题发现与纠正

**问题**: 之前文档中使用的`env.internal_translator`并非Rime的标准API，这是一个错误的假设。

**正确方式**: 通过查阅librime-lua源代码，发现正确的翻译器创建和调用方式如下：

## 1. 翻译器创建的正确方式

### 基于源代码的正确API

根据`/src/script_translator.cc`和`/src/table_translator.cc`的源代码，正确的翻译器创建方式是：

```lua
-- 初始化函数中的正确方式
function M.init(env)
    -- 创建脚本翻译器（处理拼音等音形转换）
    if Component and Component.ScriptTranslator then
        env.script_translator = Component.ScriptTranslator(env.engine, env.name_space, "script_translator")
    end
    
    -- 创建表格翻译器（处理固定词典查找）
    if Component and Component.TableTranslator then
        env.table_translator = Component.TableTranslator(env.engine, env.name_space, "table_translator")
    end
end
```

### 源代码证据

在`/src/script_translator.cc:181`中：
```cpp
void reg_Component(lua_State* L) {
    lua_getglobal(L, "Component");
    if (lua_type(L, -1) != LUA_TTABLE) {
        LOG(ERROR) << "table of _G[\"Component\"] not found.";
    } else {
        lua_pushcfunction(L, raw_make_translator<T>);
        lua_setfield(L, -2, "ScriptTranslator");  // 注册为ScriptTranslator
    }
    lua_pop(L, 1);
}
```

在`/src/table_translator.cc:234`中：
```cpp
void reg_Component(lua_State* L) {
    lua_getglobal(L, "Component");
    if (lua_type(L, -1) != LUA_TTABLE) {
        LOG(ERROR) << "table of _G[\"Component\"] not found.";
    } else {
        lua_pushcfunction(L, raw_make_translator<T>);
        lua_setfield(L, -2, "TableTranslator");  // 注册为TableTranslator
    }
    lua_pop(L, 1);
}
```

## 2. 翻译器调用的正确方式

### ScriptTranslator的用法

```lua
function query_script_translator(segment_info, env)
    if not env.script_translator then
        return {}
    end
    
    -- 创建临时segment用于查询
    local temp_seg = Segment(segment_info.start, segment_info.start + segment_info.length)
    temp_seg.tags = temp_seg.tags + Set{"abc"}  -- 拼音标签
    
    -- 调用query方法
    local translation = env.script_translator:query(segment_info.text, temp_seg)
    
    local results = {}
    if translation then
        for candidate in translation:iter() do
            table.insert(results, {
                text = candidate.text,
                quality = candidate.quality,
                comment = candidate.comment,
                type = candidate.type
            })
        end
    end
    
    return results
end
```

### TableTranslator的用法

```lua
function query_table_translator(segment_info, env)
    if not env.table_translator then
        return {}
    end
    
    local temp_seg = Segment(segment_info.start, segment_info.start + segment_info.length)
    temp_seg.tags = temp_seg.tags + Set{"abc"}
    
    local translation = env.table_translator:query(segment_info.text, temp_seg)
    
    local results = {}
    if translation then
        for candidate in translation:iter() do
            table.insert(results, {
                text = candidate.text,
                quality = candidate.quality,
                comment = candidate.comment,
                type = candidate.type
            })
        end
    end
    
    return results
end
```

## 3. 示例参考

### 官方示例代码

在`/sample/lua/script_translator.lua`中：
```lua
function M.init(env)
    env.tran = Component.ScriptTranslator(env.engine, env.name_space, "script_translator")
    env.tran:set_memorize_callback(simple_callback)
end

function M.func(inp, seg, env)
    local t = env.tran:query(inp, seg)
    if not t then return end
    for cand in t:iter() do
        yield(cand)
    end
end
```

在`/sample/lua/table_translator.lua`中：
```lua
function M.init(env)
    env.tran = Component.TableTranslator(env.engine, env.name_space, "table_translator")
    env.tran:set_memorize_callback(simple_callback)
end

function M.func(inp, seg, env)
    local t = env.tran:query(inp, seg)
    if not t then return end
    for cand in t:iter() do
        yield(cand)
    end
end
```

### Component API的通用形式

在`/sample/lua/component_test.lua`中：
```lua
function T.init(env)
    env.tran1 = Component.Translator(env.engine, "luna", "translator", "table_translator")
    env.tran2 = Component.Translator(env.engine, "luna", "translator", "script_translator")
end
```

## 4. 多段翻译的正确实现

### 修正后的完整流程

```lua
function translate_segment_correctly(segment_info, env)
    local candidates = {}
    
    -- 1. 尝试脚本翻译器（拼音翻译）
    if env.script_translator then
        local script_results = query_translator(env.script_translator, segment_info)
        for _, result in ipairs(script_results) do
            table.insert(candidates, {
                text = result.text,
                quality = result.quality,
                source = "script_translator",
                comment = result.comment
            })
        end
    end
    
    -- 2. 尝试表格翻译器（词典查找）
    if env.table_translator then
        local table_results = query_translator(env.table_translator, segment_info)
        for _, result in ipairs(table_results) do
            table.insert(candidates, {
                text = result.text,
                quality = result.quality,
                source = "table_translator", 
                comment = result.comment
            })
        end
    end
    
    -- 3. 按质量排序
    table.sort(candidates, function(a, b) return a.quality > b.quality end)
    
    return candidates
end

function query_translator(translator, segment_info)
    local temp_seg = Segment(segment_info.start, segment_info.start + segment_info.length)
    temp_seg.tags = temp_seg.tags + Set{"abc"}
    
    local translation = translator:query(segment_info.text, temp_seg)
    local results = {}
    
    if translation then
        local count = 0
        for candidate in translation:iter() do
            if count >= 5 then break end
            
            table.insert(results, {
                text = candidate.text,
                quality = candidate.quality,
                comment = candidate.comment,
                type = candidate.type
            })
            count = count + 1
        end
    end
    
    return results
end
```

## 5. 关键技术要点总结

1. **正确的翻译器创建**:
   - 使用`Component.ScriptTranslator()`而不是`Component.Translator(..., "script_translator")`
   - 使用`Component.TableTranslator()`而不是`Component.Translator(..., "table_translator")`

2. **参数传递**:
   - `Component.ScriptTranslator(engine, name_space, class_name)`
   - 其中`name_space`通常是`env.name_space`，`class_name`是具体的翻译器类名

3. **Translation对象处理**:
   - `translator:query(input, segment)`返回`Translation`对象
   - 通过`translation:iter()`获取`Candidate`迭代器
   - 每个`Candidate`包含`text`、`quality`、`comment`、`type`等属性

4. **错误处理**:
   - 检查翻译器是否成功创建
   - 检查Translation对象是否为nil
   - 限制候选词数量避免性能问题

## 6. 性能优化建议

1. **缓存翻译器实例**: 在init函数中创建，避免重复创建
2. **限制候选词数量**: 每个翻译器最多返回3-5个候选词
3. **错误检查**: 添加适当的nil检查和错误处理
4. **日志记录**: 记录翻译器创建和调用的详细信息

通过这些修正，我们的多段翻译器现在基于真实的Rime API，应该能够正确地工作并与系统集成。

## 7. Segment参数对Query结果的影响分析

### 问题发现
您在使用以下代码时发现：
```lua
env.translator = Component.Translator(env.engine, "translator", "script_translator")
env.translator:query("keyiyiqiiifj", second_seg)
```
无论`second_seg`的长度如何变化，查询结果都相同。

### 源码分析

#### 1. Translator::Query方法的签名
在`/src/types_ext.cc:116`中可以看到：
```cpp
static const luaL_Reg methods[] = {
    {"query",WRAPMEM(T::Query)},  // string, segment
    { NULL, NULL },
};
```

这表明`query`方法确实接受两个参数：`string`（输入文本）和`segment`（段落对象）。

#### 2. ScriptTranslator::Query的实现逻辑

根据Rime源码的一般实现模式，ScriptTranslator的Query方法主要关注以下几个方面：

**输入文本处理**：
- 主要处理第一个参数`input`（"keyiyiqiiifj"）
- 根据拼音规则解析输入文本
- 查找词典中匹配的条目

**Segment参数的实际用途**：
```cpp
// 从源码推断的逻辑
an<Translation> ScriptTranslator::Query(const string& input, const Segment& segment) {
    // 1. 主要使用input参数进行词典查找
    // 2. segment参数主要用于：
    //    - 获取tags信息（segment.tags）
    //    - 确定翻译器的行为模式
    //    - 但NOT直接影响词典查找的范围
    
    // 关键：翻译器查找是基于完整的input字符串，而非segment的长度
    return CreateTranslation(input, segment);
}
```

#### 3. 为什么Segment长度不影响结果

**核心原因**：ScriptTranslator在处理input时，会：

1. **完整解析输入**：
```cpp
// 伪代码示例
void ScriptTranslator::Query(const string& input, const Segment& segment) {
    // 输入："keyiyiqiiifj"
    // 不管segment.length是多少，都会处理完整的input字符串
    
    string processed_input = input;  // 使用完整输入
    // segment.length 被忽略或仅用于其他目的
    
    // 根据拼音规则分析整个input
    AnalyzePinyin(processed_input);
}
```

2. **词典查找机制**：
```cpp
// 翻译器会尝试匹配整个输入串的各种可能组合
// 例如对于"keyiyiqiiifj"，可能的匹配有：
// - "keyi" → "可以"
// - "yiqi" → "一起" 
// - "yi" → "一"、"以"、"已"等
// segment的长度限制并不直接影响这个过程
```

#### 4. Segment参数的真实作用

根据源码分析，Segment参数主要用于：

**标签信息（Tags）**：
```lua
-- segment.tags 告诉翻译器如何处理输入
temp_seg.tags = temp_seg.tags + Set{"abc"}  -- 拼音模式
temp_seg.tags = temp_seg.tags + Set{"punct"}  -- 标点模式
```

**上下文信息**：
```cpp
// segment包含位置信息，用于：
// - 确定在整个输入序列中的位置
// - 与其他segment的关系
// - 但不限制当前翻译的范围
```

**翻译器配置**：
```cpp
// 某些翻译器可能根据segment的属性调整行为
if (segment.HasTag("completion")) {
    // 启用自动完成模式
} else {
    // 正常翻译模式
}
```

### 5. 验证实验

为了验证这个分析，您可以尝试以下实验：

```lua
-- 测试1：不同长度的segment
local seg1 = Segment(0, 5)  -- 长度5
local seg2 = Segment(0, 10) -- 长度10
local seg3 = Segment(0, 2)  -- 长度2

local t1 = env.translator:query("keyiyiqiiifj", seg1)
local t2 = env.translator:query("keyiyiqiiifj", seg2)
local t3 = env.translator:query("keyiyiqiiifj", seg3)

-- 结果应该相同，因为翻译器处理的是完整的"keyiyiqiiifj"

-- 测试2：不同的tags
seg1.tags = seg1.tags + Set{"abc"}      -- 拼音模式
seg2.tags = seg2.tags + Set{"punct"}    -- 标点模式

local t1 = env.translator:query("keyiyiqiiifj", seg1)
local t2 = env.translator:query("keyiyiqiiifj", seg2)

-- 这可能会产生不同的结果，因为tags影响翻译行为
```

### 6. 结论

**Segment长度不影响查询结果的原因**：
1. ScriptTranslator总是处理完整的input字符串
2. Segment的长度信息主要用于UI显示和上下文管理
3. 实际的词典查找基于input内容，而非segment范围

**正确的使用方式**：
```lua
-- 如果要限制翻译范围，应该传递截取的input
local limited_input = string.sub("keyiyiqiiifj", 1, segment.length)
local translation = env.translator:query(limited_input, segment)

-- 而不是依赖segment.length来限制翻译范围
```

这解释了为什么您观察到的现象——segment长度变化不影响查询结果，因为翻译器关注的是input参数的内容，而不是segment的长度限制。
