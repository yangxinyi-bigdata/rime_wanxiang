-- text_splitter.lua - 文本智能切分模块
-- 用于处理反引号和标点符号的智能切分

local text_splitter = {}

-- 英文标点符号到中文标点符号的映射表
local punct_map = {
    [","] = "，",    -- 逗号
    ["."] = "。",    -- 句号
    ["?"] = "？",    -- 问号  
    ["!"] = "！",    -- 感叹号
    [":"] = "：",    -- 冒号
    [";"] = "；",    -- 分号
    ["("] = "（",    -- 左括号
    [")"] = "）",    -- 右括号
    -- ["["] = "【",    -- 左方括号
    -- ["]"] = "】",    -- 右方括号
    ["{"] = "｛",    -- 左花括号
    ["}"] = "｝",    -- 右花括号
    ["'"] = "'",     -- 单引号（左）
    ["<"] = "《",    -- 左书名号
    [">"] = "》",    -- 右书名号
}

-- 标点符号替换函数
function text_splitter.replace_punct(text)
    if not text or text == "" then
        return text
    end
    
    local result = text
    for eng_punct, chn_punct in pairs(punct_map) do
        result = result:gsub(eng_punct:gsub("([%(%)%.%+%-%*%?%[%]%^%$%%])", "%%%1"), chn_punct)
    end
    return result
end

-- 检测是否包含标点符号
function text_splitter.has_punctuation(text, logger)
    if not text or text == "" then
        return false
    end
    
    if logger then
        logger:info("检测输入内容是否包含标点符号: " .. text)
    end

    -- 简单检查是否包含常见标点符号
    local has_punct = false
    
    -- 检查中文标点
    if string.find(text, "[，。！？；：（）【】《》、]") then
        has_punct = true
    end
    
    -- 检查英文标点 (包含反引号)
    if string.find(text, "[,.!?;:()%[%]<>/_=+*&^%%$#@~`|\\-]") then
        has_punct = true
    end

    if logger then
        logger:info("has_punct: " .. tostring(has_punct))
    end

    return has_punct
end

-- 检测是否包含标点符号（不含反引号版本）
function text_splitter.has_punctuation_no_backtick(text, logger)
    if not text or text == "" then
        return false
    end
    
    if logger then
        logger:info("检测输入内容是否包含标点符号(不含反引号): " .. text)
    end

    -- 简单检查是否包含常见标点符号
    local has_punct = false
    
    -- 检查中文标点
    if string.find(text, "[，。！？；：（）【】《》、]") then
        has_punct = true
    end
    
    -- 检查英文标点（不包含反引号）
    if string.find(text, "[,.!?;:()%[%]<>/_=+*&^%%$#@~|\\-]") then
        has_punct = true
    end

    if logger then
        logger:info("has_punct(no backtick): " .. tostring(has_punct))
    end

    return has_punct
end

-- 智能切分输入并转换双拼到全拼
function text_splitter.split_and_convert_input(input, replace_punct_enabled)
    -- 使用默认空分隔符的版本
    return text_splitter.split_and_convert_input_with_delimiter(input, "", "", replace_punct_enabled)
end

-- 带分隔符的智能切分函数
function text_splitter.split_and_convert_input_with_delimiter(input, backtick_delimiter_before, backtick_delimiter_after, replace_punct_enabled)
    backtick_delimiter_before = backtick_delimiter_before or ""  -- 默认无分隔符
    backtick_delimiter_after = backtick_delimiter_after or ""  -- 默认无分隔符
    replace_punct_enabled = replace_punct_enabled or false  -- 默认不替换标点符号
    
    -- 先处理反引号 - 支持多对反引号
    -- nihk`hello`wode`dream3`keyi 应该处理成：nihk + `hello` + wode + `dream3` + keyi
    -- nihk`hello`wode`dream3 应该处理成：nihk + `hello` + wode + `dream3（后面所有内容不处理）
    local backtick_positions = {}  -- 所有反引号位置
    
    -- 先找到所有反引号的位置
    for i = 1, #input do
        local char = input:sub(i, i)
        if char == "`" then
            table.insert(backtick_positions, i)
        end
    end
    
    -- 检查反引号数量
    local backtick_count = #backtick_positions
    local has_unpaired_backtick = (backtick_count % 2 == 1)  -- 奇数个反引号表示有未配对的
    
    -- 定义标点符号模式
    local punct_pattern = "[,.!?;:()%[%]<>/_=+*&^%%$#@~|%-`'\"']"
    
    -- 切分输入，保留标点符号位置
    local segments = {}  -- 片段列表
    local current_segment = ""  -- 当前片段
    local i = 1
    local in_backtick = false  -- 在反引号中
    local backtick_content = ""  -- 反引号内容
    local backtick_pair_index = 0  -- 当前处理到第几个反引号
    
    while i <= #input do
        local char = input:sub(i, i)  -- 当前字符
        
        -- 检查是否到达未配对的最后一个反引号
        if has_unpaired_backtick and backtick_pair_index == backtick_count - 1 and char == "`" then
            -- 最后一个未配对的反引号，从这里开始到末尾都不处理
            if current_segment ~= "" then
                local segment_start = i - #current_segment - 1  -- 转换为0基索引
                table.insert(segments, {
                    type = "abc", 
                    content = current_segment,
                    original = current_segment,
                    start = segment_start,
                    _end = i - 1,  -- 开区间，不包含当前位置
                    length = #current_segment
                })
                current_segment = ""
            end
            
            -- 对于未配对的反引号，包装其内容
            local remaining_content = input:sub(i + 1)
            local processed_content = backtick_delimiter_before .. remaining_content .. backtick_delimiter_after
            table.insert(segments, {
                type = "backtick", 
                content = processed_content,
                original = "`" .. remaining_content,
                start = i - 1,  -- 转换为0基索引，从反引号开始
                _end = #input,  -- 开区间，到字符串末尾
                length = #input - i + 1
            })
            break
        elseif char == "`" then
            -- 不是最后一个未配对的反引号
            backtick_pair_index = backtick_pair_index + 1
            if not in_backtick then
                -- 开始反引号内容
                if current_segment ~= "" then  -- 遇到反引号，且之前不是在反引号当中,将之前积累的内容直接添加成片段
                    local segment_start = i - #current_segment - 1  -- 转换为0基索引
                    table.insert(segments, {
                        type = "abc", 
                        content = current_segment,
                        original = current_segment,
                        start = segment_start,
                        _end = i - 1,  -- 开区间，不包含反引号位置
                        length = #current_segment
                    })  -- 类型=文本，内容
                    current_segment = ""
                end
                in_backtick = true
                backtick_content = ""
            else
                -- 结束反引号内容，添加分隔符
                local processed_content = backtick_delimiter_before .. backtick_content .. backtick_delimiter_after
                local backtick_start = i - #backtick_content - 2  -- 转换为0基索引，包含开始反引号
                table.insert(segments, {
                    type = "backtick", 
                    content = processed_content,
                    original = "`" .. backtick_content .. "`",
                    start = backtick_start,
                    _end = i,  -- 开区间，不包含结束反引号后的位置
                    length = #backtick_content + 2
                })
                in_backtick = false
                backtick_content = ""
            end
        elseif in_backtick then
            backtick_content = backtick_content .. char
        elseif char:match(punct_pattern) then
            -- 遇到标点符号
            if current_segment ~= "" then
                local segment_start = i - #current_segment - 1  -- 转换为0基索引
                table.insert(segments, {
                    type = "abc", 
                    content = current_segment,
                    original = current_segment,
                    start = segment_start,
                    _end = i - 1,  -- 开区间，不包含标点符号位置
                    length = #current_segment
                })  -- 类型=文本
                current_segment = ""
            end
            table.insert(segments, {
                type = "punct", 
                content = replace_punct_enabled and text_splitter.replace_punct(char) or char,
                original = char,
                start = i - 1,  -- 转换为0基索引
                _end = i,  -- 开区间，不包含下一个字符位置
                length = 1
            })  -- 类型=标点
        else
            current_segment = current_segment .. char
        end
        
        i = i + 1
    end
    
    -- 处理最后一个片段
    if in_backtick then
        -- 未闭合的反引号内容，添加分隔符
        local processed_content = backtick_delimiter_before .. backtick_content .. backtick_delimiter_after
        local backtick_start = #input - #backtick_content - 1  -- 转换为0基索引，包含反引号
        table.insert(segments, {
            type = "backtick", 
            content = processed_content,
            original = "`" .. backtick_content,
            start = backtick_start,
            _end = #input,  -- 开区间，到字符串末尾
            length = #backtick_content + 1
        })
    elseif current_segment ~= "" then
        local segment_start = #input - #current_segment  -- 转换为0基索引
        table.insert(segments, {
            type = "abc", 
            content = current_segment,
            original = current_segment,
            start = segment_start,
            _end = #input,  -- 开区间，到字符串末尾
            length = #current_segment
        })
    end
    
    return segments
end

-- 只处理反引号的切分函数
function text_splitter.split_by_backtick(input, delimiter_before, delimiter_after)
    delimiter_before = delimiter_before or ""  -- 默认无分隔符
    delimiter_after = delimiter_after or ""  -- 默认无分隔符

    -- 先找到所有反引号的位置
    local backtick_positions = {}
    for i = 1, #input do
        local char = input:sub(i, i)
        if char == "`" then
            table.insert(backtick_positions, i)
        end
    end
    
    -- 检查反引号数量
    local backtick_count = #backtick_positions
    local has_unpaired_backtick = (backtick_count % 2 == 1)  -- 奇数个反引号表示有未配对的
    
    local segments = {}  -- 片段列表
    local current_segment = ""  -- 当前片段
    local i = 1
    local in_backtick = false  -- 在反引号中
    local backtick_content = ""  -- 反引号内容
    local backtick_pair_index = 0  -- 当前处理到第几个反引号
    
    while i <= #input do
        local char = input:sub(i, i)  -- 当前字符
        
        -- 检查是否到达未配对的最后一个反引号
        if has_unpaired_backtick and backtick_pair_index == backtick_count - 1 and char == "`" then
            -- 最后一个未配对的反引号，从这里开始到末尾都不处理
            if current_segment ~= "" then
                local segment_start = i - #current_segment - 1  -- 转换为0基索引
                table.insert(segments, {
                    type = "abc", 
                    content = current_segment,
                    original = current_segment,
                    start = segment_start,
                    _end = i - 1,  -- 开区间，不包含反引号位置
                    length = #current_segment
                })
                current_segment = ""
            end
            
            -- 对于未配对的反引号，包装其内容
            local remaining_content = input:sub(i + 1)
            local processed_content = delimiter_before .. remaining_content .. delimiter_after
            -- 添加原始反引号内容字段
            table.insert(segments, {
                type = "backtick", 
                content = processed_content, 
                original = "`" .. remaining_content,
                start = i - 1,  -- 转换为0基索引，从反引号开始
                _end = #input,  -- 开区间，到字符串末尾
                length = #input - i + 1
            })
            break
        elseif char == "`" then
            -- 不是最后一个未配对的反引号
            backtick_pair_index = backtick_pair_index + 1
            if not in_backtick then
                -- 开始反引号内容
                if current_segment ~= "" then
                    local segment_start = i - #current_segment - 1  -- 转换为0基索引
                    table.insert(segments, {
                        type = "abc", 
                        content = current_segment,
                        original = current_segment,
                        start = segment_start,
                        _end = i - 1,  -- 开区间，不包含反引号位置
                        length = #current_segment
                    })
                    current_segment = ""
                end
                in_backtick = true
                backtick_content = ""
            else
                -- 结束反引号内容，添加分隔符
                local processed_content = delimiter_before .. backtick_content .. delimiter_after
                -- 添加原始反引号内容字段
                local backtick_start = i - #backtick_content - 2  -- 转换为0基索引，包含开始反引号
                table.insert(segments, {
                    type = "backtick", 
                    content = processed_content, 
                    original = "`" .. backtick_content .. "`",
                    start = backtick_start,
                    _end = i,  -- 开区间，不包含结束反引号后的位置
                    length = #backtick_content + 2
                })
                in_backtick = false
                backtick_content = ""
            end
        elseif in_backtick then
            backtick_content = backtick_content .. char
        else
            -- 其他所有字符（包括标点符号）都加入当前段落
            current_segment = current_segment .. char
        end
        
        i = i + 1
    end
    
    -- 处理最后一个片段
    if in_backtick then
        -- 未闭合的反引号内容，添加分隔符
        local processed_content = delimiter_before .. backtick_content .. delimiter_after
        -- 添加原始反引号内容字段
        local backtick_start = #input - #backtick_content - 1  -- 转换为0基索引，包含反引号
        table.insert(segments, {
            type = "backtick", 
            content = processed_content, 
            original = "`" .. backtick_content,
            start = backtick_start,
            _end = #input,  -- 开区间，到字符串末尾
            length = #backtick_content + 1
        })
    elseif current_segment ~= "" then
        local segment_start = #input - #current_segment  -- 转换为0基索引
        table.insert(segments, {
            type = "abc", 
            content = current_segment,
            original = current_segment,
            start = segment_start,
            _end = #input,  -- 开区间，到字符串末尾
            length = #current_segment
        })
    end
    
    return segments
end

-- 带日志记录的版本
function text_splitter.split_and_convert_input_with_log(input, logger, replace_punct_enabled)
    if logger then
        logger:info("开始处理输入: " .. input)
    end
    
    local segments = text_splitter.split_and_convert_input(input, replace_punct_enabled)
    
    if logger then
        logger:info("切分结果:")
        for i, seg in ipairs(segments) do
            logger:info(string.format("  片段%d: 类型=%s, 内容='%s'", i, seg.type, seg.content))
        end
    end
    
    return segments
end

-- 带日志记录和分隔符的版本
function text_splitter.split_and_convert_input_with_log_and_delimiter(input, logger, backtick_delimiter_before, backtick_delimiter_after, replace_punct_enabled)
    if logger then
        logger:info("开始处理输入: " .. input .. "，反引号分隔符: '" .. (backtick_delimiter_before or "") .. "' '" .. (backtick_delimiter_after or "") .. "'")
        logger:info("标点符号替换开关: " .. tostring(replace_punct_enabled or false))
    end
    
    local segments = text_splitter.split_and_convert_input_with_delimiter(input, backtick_delimiter_before, backtick_delimiter_after, replace_punct_enabled)
    
    if logger then
        logger:info("切分结果:")
        for i, seg in ipairs(segments) do
            logger:info(string.format("  片段%d: 类型=%s, 内容='%s'", i, seg.type, seg.content))
        end
    end
    
    return segments
end

-- 带日志记录的split_by_backtick函数
function text_splitter.split_by_backtick_with_log(input, delimiter_before, delimiter_after, logger)
    if logger then
        logger:info("开始使用split_by_backtick处理输入: " .. input .. "，分隔符: '" .. (delimiter_before or "") .. "' '" .. (delimiter_after or "") .. "'")
    end

    local segments = text_splitter.split_by_backtick(input, delimiter_before, delimiter_after)
    
    if logger then
        logger:info("split_by_backtick切分结果:")
        for i, seg in ipairs(segments) do
            logger:info(string.format("  片段%d: 类型=%s, 内容='%s'", i, seg.type, seg.content))
        end
    end
    
    return segments
end

return text_splitter
