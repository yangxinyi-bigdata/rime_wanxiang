-- lua/punct_eng_chinese_filter.lua
-- 将候选项当中的英文标点符号改成中文标点符号

-- 日志文件路径
local log_file_path = "/Users/yangxinyi/Library/Rime/ai_test.log"

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
    ["["] = "【",    -- 左方括号
    ["]"] = "】",    -- 右方括号
    ["{"] = "｛",    -- 左花括号
    ["}"] = "｝",    -- 右花括号
    ["'"] = "'",     -- 单引号（左）
    ["<"] = "《",    -- 左书名号
    [">"] = "》",    -- 右书名号
}

-- 日志函数
local function log(message)
    local timestamp = os.date("%Y-%m-%d %H:%M:%S")
    local log_message = string.format("[%s] [punct_eng_chinese.lua] %s\n", timestamp, message)
    
    local file = io.open(log_file_path, "a")
    if file then
        file:write(log_message)
        file:close()
    end
end

-- 标点符号替换函数
local function replace_punct(text)
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
local function has_punctuation(text)
    if not text or text == "" then
        return false
    end
    log("检测输入内容是否包含标点符号: " .. text)

    -- 简单检查是否包含常见标点符号
    local has_punct = false
    
    -- -- 检查中文标点
    -- if string.find(text, "[，。！？；：（）【】《》、]") then
    --     has_punct = true
    -- end
    
    -- 检查英文标点
    if string.find(text, "[,.!?;:()%[%]<>/_=+*&^%%$#@~`|\\-]") then
        has_punct = true
    end

    log("has_punct: " .. tostring(has_punct))

    return has_punct

end

local function punct_eng_chinese_filter(translation)
    
    local count = 0  -- 用于计数，限制最多处理6个候选词
    -- 遍历所有候选词并进行标点符号替换
    for cand in translation:iter() do
        count = count + 1
        if cand.text and has_punctuation(cand.text) and count < 3 then
            local original_text = cand.text
            local new_text = replace_punct(original_text)
            
            -- cand.text = new_text  -- 更新候选词文本
            log("标点替换: " .. original_text .. " -> " .. new_text)
            -- 根据文档，使用Candidate构造方法创建新候选项
            -- Candidate(type, start, end, text, comment)
            local new_cand = Candidate(
                cand.type or "punct_converted",  -- 保持原有类型或标记为标点转换
                cand.start or 0,  -- 分词开始位置
                cand._end or 0,     -- 分词结束位置  
                new_text,                        -- 替换后的文本
                cand.comment or ""               -- 保持原有注释
            )
            -- 保持其他重要属性
            -- if cand.quality then
            --     new_cand.quality = cand.quality
            -- end
            if cand.preedit then
                new_cand.preedit = cand.preedit
            end
            yield(new_cand)  -- 输出新的候选词
        else
            -- 如果没有文本或不包含标点符号，直接输出原候选词
            yield(cand)  -- 如果没有文本或不包含标点符号，直接
        end
        
        
        
    end
    
    

end

return punct_eng_chinese_filter