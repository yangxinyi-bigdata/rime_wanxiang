# Chinese_pos 数据管理文档

## 概述

`chinese_pos` 是 Rime 万象输入法中用于标记中文字符位置的数据结构，主要用于在标点符号替换过程中精确控制哪些位置需要进行英文到中文标点符号的转换，而跳过反引号内的英文内容。

## 数据结构

### 格式定义
```
chinese_pos:<start1>,<end1>,<start2>,<end2>,...
```

- **前缀**: `chinese_pos:` - 标识这是一个位置信息字符串
- **位置对**: 每一对数字 `<start>,<end>` 表示一个中文字符范围
- **分隔符**: 逗号 `,` 分隔各个数字
- **字符计数**: 使用 UTF-8 字符计数（非字节计数）

### 示例
```
chinese_pos:1,4,7,10,
```
表示：
- 第1-4个字符是中文内容
- 第7-10个字符是中文内容
- 第5-6个字符和第11个字符之后是英文内容（反引号包围的部分）

## 创建过程

### 1. 数据生成位置
**文件**: `lua/script_backtick_translator.lua`

### 2. 生成逻辑
```lua
local chinese_pos = "chinese_pos:"
for _, one_cand in ipairs(combination) do
    count = count + 1
    final_text = final_text .. one_cand.text
    final_preedit = final_preedit .. one_cand.preedit

    -- 计算反引号片段的索引位置
    if one_cand.type == "abc" then
        local pos_start = text_len + 1
        text_len = text_len + utf8.len(one_cand.text)
        local pos_end = text_len
        chinese_pos = chinese_pos .. pos_start .. "," .. pos_end .. ","
    else
        text_len = text_len + #one_cand.text
    end
end
```

### 3. 生成规则
- **ABC类型候选词**: 被标记为中文内容，需要记录其UTF-8字符位置
- **非ABC类型**: 通常是反引号内容或标点符号，不记录位置
- **位置计算**: 使用 `utf8.len()` 确保正确计算多字节字符
- **累积计算**: `text_len` 变量累积记录总长度

### 4. 存储方式
生成的 `chinese_pos` 字符串被存储在候选词的 `comment` 字段中：
```lua
local new_cand = Candidate("backtick_combo", segment.start, segment._end, final_text, chinese_pos)
```

## 使用过程

### 1. 使用位置
**文件**: `lua/punct_eng_chinese_filter.lua`

### 2. 识别逻辑
```lua
if cand_comment:match("^chinese_pos:") then
    logger:info("候选词为chinese_pos, 使用反引号替换")
    local chinese_pos = cand.comment
    new_text = text_splitter.replace_punct_skip_pos(cand_text, chinese_pos, logger)
else
    logger:info("候选词不是chinese_pos ,按照原来的处理即可")
    new_text = text_splitter.replace_punct(cand_text)
end
```

### 3. 处理流程
1. **检测**: 通过 `^chinese_pos:` 正则表达式识别
2. **提取**: 从候选词的 `comment` 字段提取位置信息
3. **调用**: 传递给 `text_splitter.replace_punct_skip_pos()` 函数
4. **替换**: 只对指定位置范围内的标点符号进行中文化

### 4. 标点替换逻辑
**文件**: `lua/text_splitter.lua` 中的 `replace_punct_skip_pos` 函数

```lua
function text_splitter.replace_punct_skip_pos(text, chinese_pos_str, logger)
    -- 解析坐标范围
    local ranges = {}
    local pos_data = chinese_pos_str:gsub("^chinese_pos:", "")
    
    -- 一次性匹配两个数字作为一对
    for start_num, end_num in pos_data:gmatch("(%d+),(%d+)") do
        table.insert(ranges, {start = tonumber(start_num), end = tonumber(end_num)})
    end
    
    -- 只对指定范围内的内容进行标点符号替换
    -- ...
end
```

## 工作原理

### 1. 问题背景
在包含反引号的输入中（如：`你好`world`再见`），需要：
- 对中文部分的英文标点进行中文化：`你好,` → `你好，`
- 保持反引号内英文内容不变：`world,test` 保持原样

### 2. 解决方案
通过 `chinese_pos` 精确标记哪些字符位置是中文内容：
```
输入: 你好`world`再见
chinese_pos: chinese_pos:1,2,9,10,
```
- 位置1-2：`你好` （中文，需要标点转换）
- 位置3-8：`world` （英文，跳过）
- 位置9-10：`再见` （中文，需要标点转换）

### 3. 处理优势
- **精确控制**: 字符级别的精确位置控制
- **UTF-8安全**: 正确处理多字节字符
- **性能优化**: 避免重复解析反引号结构

## 维护指南

### 1. 数据完整性检查
- 确保位置对是偶数个（成对出现）
- 验证起始位置小于等于结束位置
- 检查位置范围不超出文本长度

### 2. 错误处理
```lua
-- 建议添加的验证逻辑
local function validate_chinese_pos(pos_str, text_len)
    if not pos_str:match("^chinese_pos:") then
        return false, "格式错误：缺少前缀"
    end
    
    local positions = {}
    for start_num, end_num in pos_str:gmatch("(%d+),(%d+)") do
        local start_pos = tonumber(start_num)
        local end_pos = tonumber(end_num)
        
        if start_pos > end_pos then
            return false, "位置错误：起始位置大于结束位置"
        end
        
        if end_pos > text_len then
            return false, "位置错误：超出文本长度"
        end
    end
    
    return true, "验证通过"
end
```

### 3. 调试建议
- 在生成阶段记录详细日志
- 在使用阶段验证位置数据
- 定期检查边界情况处理

### 4. 扩展考虑
如果需要支持更复杂的标记，可以考虑：
- 添加类型标识：`chinese_pos:type1:1,4,type2:7,10,`
- 支持嵌套结构：`chinese_pos:level1:1,4,level2:2,3,`
- 增加版本控制：`chinese_pos_v2:1,4,7,10,`

## 相关文件

- **创建**: `lua/script_backtick_translator.lua`
- **使用**: `lua/punct_eng_chinese_filter.lua`
- **工具**: `lua/text_splitter.lua`
- **日志**: `log/` 目录下的相关日志文件

## 注意事项

1. **字符计数**: 必须使用UTF-8字符计数，不能使用字节计数
2. **位置索引**: 使用1开始的索引，与Lua字符串索引保持一致
3. **内存管理**: `chinese_pos` 字符串会存储在候选词中，注意内存使用
4. **性能影响**: 位置解析会增加处理时间，考虑缓存优化

## 更新历史

- **创建时间**: 2025年7月
- **主要版本**: v1.0
- **维护状态**: 活跃开发中

---

*本文档描述了万象输入法中chinese_pos数据的完整生命周期，用于开发维护参考。*
