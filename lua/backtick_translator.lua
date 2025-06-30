-- 反引号内容拼接翻译器
-- 还未验证内容可行性，但看起来是比较靠谱的

local function backtick_translator(input, seg, env)
    local context = env.engine.context
    local input_text = context.input
    
    -- 检查是否包含反引号
    if not input_text:find("`") then
        return
    end
    
    -- 解析输入，提取拼音和原文
    local segments = {}
    local current_pos = 1
    
    while current_pos <= #input_text do
        local backtick_start = input_text:find("`", current_pos)
        
        if backtick_start then
            if backtick_start > current_pos then
                table.insert(segments, {
                    type = "pinyin",
                    content = input_text:sub(current_pos, backtick_start - 1),
                    start = current_pos - 1,
                    end_pos = backtick_start - 1
                })
            end
            
            local backtick_end = input_text:find("`", backtick_start + 1)
            if backtick_end then
                table.insert(segments, {
                    type = "literal",
                    content = input_text:sub(backtick_start + 1, backtick_end - 1),
                    start = backtick_start,
                    end_pos = backtick_end
                })
                current_pos = backtick_end + 1
            else
                break
            end
        else
            if current_pos <= #input_text then
                table.insert(segments, {
                    type = "pinyin",
                    content = input_text:sub(current_pos),
                    start = current_pos - 1,
                    end_pos = #input_text
                })
            end
            break
        end
    end
    
    -- 使用内存来缓存每个拼音段的候选词
    local segment_candidates = {}
    
    -- 获取每个拼音段的候选词
    for i, segment in ipairs(segments) do
        if segment.type == "pinyin" and segment.content ~= "" then
            -- 创建一个临时的 segmentation
            local temp_seg = Segment(segment.start, segment.end_pos)
            temp_seg.tags = seg.tags
            
            -- 获取这个拼音段的候选词
            local candidates = {}
            local translator = env.engine.schema.translators:find(function(t)
                return t.name_space == "script_translator"
            end)
            
            if translator then
                local temp_input = UserInput(segment.content)
                for cand in translator:query(temp_input, temp_seg) do
                    table.insert(candidates, cand.text)
                    if #candidates >= 5 then  -- 限制候选词数量
                        break
                    end
                end
            end
            
            segment_candidates[i] = candidates
        elseif segment.type == "literal" then
            segment_candidates[i] = {segment.content}
        end
    end
    
    -- 生成组合候选词
    local function generate_combinations(index, current_text)
        if index > #segments then
            if current_text ~= "" then
                local cand = Candidate("backtick", seg.start, seg._end, current_text, "〔拼音+原文〕")
                yield(cand)
            end
            return
        end
        
        local candidates = segment_candidates[index]
        if candidates and #candidates > 0 then
            for _, text in ipairs(candidates) do
                generate_combinations(index + 1, current_text .. text)
            end
        else
            generate_combinations(index + 1, current_text)
        end
    end
    
    generate_combinations(1, "")
end

return backtick_translator