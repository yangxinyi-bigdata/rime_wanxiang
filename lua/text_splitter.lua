-- text_splitter.lua - 文本智能切分模块
-- 用于处理反引号和标点符号的智能切分

local text_splitter = {}

-- 智能切分输入并转换双拼到全拼
function text_splitter.split_and_convert_input(input)
    -- 使用默认空分隔符的版本
    return text_splitter.split_and_convert_input_with_delimiter(input, "")
end

-- 带分隔符的智能切分函数
function text_splitter.split_and_convert_input_with_delimiter(input, delimiter)
    delimiter = delimiter or ""  -- 默认无分隔符
    
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
                table.insert(segments, {type = "text", content = current_segment})
                current_segment = ""
            end
            
            -- 对于未配对的反引号，包装其内容
            local remaining_content = input:sub(i + 1)
            if delimiter ~= "" and remaining_content ~= "" then
                table.insert(segments, {type = "backtick", content = delimiter .. remaining_content .. delimiter})
            else
                table.insert(segments, {type = "backtick", content = remaining_content})
            end
            break
        elseif char == "`" then
            -- 不是最后一个未配对的反引号
            backtick_pair_index = backtick_pair_index + 1
            if not in_backtick then
                -- 开始反引号内容
                if current_segment ~= "" then  -- 遇到反引号，且之前不是在反引号当中,将之前积累的内容直接添加成片段
                    table.insert(segments, {type = "text", content = current_segment})  -- 类型=文本，内容
                    current_segment = ""
                end
                in_backtick = true
                backtick_content = ""
            else
                -- 结束反引号内容，添加分隔符
                if delimiter ~= "" and backtick_content ~= "" then
                    table.insert(segments, {type = "backtick", content = delimiter .. backtick_content .. delimiter})
                else
                    table.insert(segments, {type = "backtick", content = backtick_content})
                end
                in_backtick = false
                backtick_content = ""
            end
        elseif in_backtick then
            backtick_content = backtick_content .. char
        elseif char:match(punct_pattern) then
            -- 遇到标点符号
            if current_segment ~= "" then
                table.insert(segments, {type = "text", content = current_segment})  -- 类型=文本
                current_segment = ""
            end
            table.insert(segments, {type = "punct", content = char})  -- 类型=标点
        else
            current_segment = current_segment .. char
        end
        
        i = i + 1
    end
    
    -- 处理最后一个片段
    if in_backtick then
        -- 未闭合的反引号内容，添加分隔符
        if delimiter ~= "" and backtick_content ~= "" then
            table.insert(segments, {type = "backtick", content = delimiter .. backtick_content .. delimiter})
        else
            table.insert(segments, {type = "backtick", content = backtick_content})
        end
    elseif current_segment ~= "" then
        table.insert(segments, {type = "text", content = current_segment})
    end
    
    return segments
end

-- 带日志记录的版本
function text_splitter.split_and_convert_input_with_log(input, logger)
    if logger then
        logger:info("开始处理输入: " .. input)
    end
    
    local segments = text_splitter.split_and_convert_input(input)
    
    if logger then
        logger:info("切分结果:")
        for i, seg in ipairs(segments) do
            logger:info(string.format("  片段%d: 类型=%s, 内容='%s'", i, seg.type, seg.content))
        end
    end
    
    return segments
end

-- 带日志记录和分隔符的版本
function text_splitter.split_and_convert_input_with_log_and_delimiter(input, logger, delimiter)
    if logger then
        logger:info("开始处理输入: " .. input .. "，分隔符: '" .. (delimiter or "") .. "'")
    end
    
    local segments = text_splitter.split_and_convert_input_with_delimiter(input, delimiter)
    
    if logger then
        logger:info("切分结果:")
        for i, seg in ipairs(segments) do
            logger:info(string.format("  片段%d: 类型=%s, 内容='%s'", i, seg.type, seg.content))
        end
    end
    
    return segments
end

return text_splitter
