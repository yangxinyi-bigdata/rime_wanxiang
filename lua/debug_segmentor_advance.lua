-- 调试分词器，用于打印Segmentation和Segment的详细信息
-- 接下来进一步尝试修改segment中的数据,将一个segment切割成两个,然后尝试看看效果

local logger_module = require("logger")

-- 创建日志记录器
local logger = logger_module.create("debug_segmentor_advance", {
    enabled = true
})

-- 打印单个Segment的详细信息
local function print_segment_info(seg, logger)
    if not seg then
        logger.info("  segment is nil")
        return
    end
    
    -- 基本属性
    logger.info("  status: " .. tostring(seg.status))
    logger.info("  start: " .. tostring(seg.start))
    logger.info("  _start: " .. tostring(seg._start))
    logger.info("  _end: " .. tostring(seg._end))
    logger.info("  length: " .. tostring(seg.length))
    
    -- tags信息
    logger.info("  tags:")
    if seg.tags then
        -- tags是一个Set对象，需要遍历
        local tag_list = {}
        -- 尝试获取常见的tags
        local common_tags = {"abc", "punct", "reverse_stroke", "radical_lookup", 
                           "unicode", "number", "gregorian_to_lunar", 
                           "calculator", "quick_symbol", "add_user_dict"}
        for _, tag in ipairs(common_tags) do
            if seg:has_tag(tag) then
                table.insert(tag_list, tag)
            end
        end
        
        if #tag_list > 0 then
            logger.info("    " .. table.concat(tag_list, ", "))
        else
            logger.info("    (无已知tags)")
        end
    else
        logger.info("    tags is nil")
    end
    
    -- 获取选中的候选项索引
    logger.info("  selected_index: " .. tostring(seg.selected_index))
    
    -- prompt信息
    local prompt = seg.prompt or ""
    if prompt ~= "" then
        logger.info("  prompt: '" .. prompt .. "'")
    else
        logger.info("  prompt: (空)")
    end
    
    -- 获取菜单信息
    if seg.menu then
        logger.info("  menu:")
        logger.info("    candidate_count: " .. tostring(seg.menu:candidate_count()))
        logger.info("    empty: " .. tostring(seg.menu:empty()))
        
        -- 打印前几个候选项
        local count = seg.menu:candidate_count()
        if count > 0 then
            logger.info("    前几个候选项:")
            for i = 0, math.min(count - 1, 4) do  -- 最多显示5个
                local cand = seg.menu:get_candidate_at(i)
                if cand then
                    logger.info(string.format("      %d. %s (%s)", i + 1, cand.text, cand.comment or ""))
                end
            end
        end
    else
        logger.info("  menu: nil")
    end
end

local debug_segmentor_advance = {}

function debug_segmentor_advance.init(env)
    -- logger.clear()
    logger.info("debug_segmentor_advance调试分词器初始化完成")
    logger.info("=" .. string.rep("=", 60))
    
    -- 创建脚本翻译器（处理拼音等音形转换）
    -- 根据示例代码，参数应该是：engine, schema, namespace
    local success, translator_or_error = pcall(function()
        local wanxiang_pro = Schema("wanxiang_pro")
        env.translator = Component.Translator(env.engine, "translator", "script_translator")

    end)
    
    if success then
        logger.info("ScriptTranslator初始化成功")
    else
        logger.info("ScriptTranslator初始化失败，错误: " .. tostring(translator_or_error))
    end
    
end

function debug_segmentor_advance.func(segmentation, env)
    local input = segmentation.input
    
    logger.info("")
    logger.info(">>> 新的分词处理 <<<")
    logger.info("输入文本: '" .. input .. "'")
    logger.info("输入长度: " .. #input)
    
    -- 打印Segmentation对象信息
    logger.info("")
    logger.info("=== Segmentation 对象信息 ===")
    logger.info("size: " .. tostring(segmentation.size))
    logger.info("empty: " .. tostring(segmentation:empty()))
    
    -- 获取已确认位置
    local confirmed_pos = segmentation:get_confirmed_position()
    logger.info("confirmed_position: " .. tostring(confirmed_pos))
    
    -- 获取当前位置信息
    local current_start = segmentation:get_current_start_position()
    local current_end = segmentation:get_current_end_position()
    local current_length = segmentation:get_current_segment_length()
    logger.info("current_start_position: " .. tostring(current_start))
    logger.info("current_end_position: " .. tostring(current_end))
    logger.info("current_segment_length: " .. tostring(current_length))
    
    -- 检查是否完成分词
    logger.info("has_finished_segmentation: " .. tostring(segmentation:has_finished_segmentation()))
    
    -- 打印所有Segment信息
    logger.info("")
    logger.info("=== 所有 Segment 信息 ===")
    local segments = segmentation:get_segments()
    
    if segments and #segments > 0 then
        for i, seg in ipairs(segments) do
            logger.info("")
            logger.info(string.format("Segment %d:", i))
            print_segment_info(seg, logger)
        end
    else
        logger.info("没有segments")
    end
    
    -- 获取最后一个segment
    local back_seg = segmentation:back()
    if back_seg then
        logger.info("")
        logger.info("=== 最后一个 Segment (back) ===")
        print_segment_info(back_seg, logger)
        
        -- 检查是否需要切分segment
        if back_seg.length == 6 and back_seg:has_tag("abc") then
            logger.info("")
            logger.info("=== 检测到长度为6的abc segment，开始切分 ===")

            -- 记录原始segment信息
            local original_start = back_seg.start
            local original_end = back_seg._end
            
            logger.info("原始segment: start=" .. original_start .. ", end=" .. original_end)
            
            -- 尝试方法2: 直接修改原始segment的长度，然后添加第二个segment
            -- logger.info("=== 方法2: 修改原始segment长度，然后添加第二个segment ===")
            
            -- 修改原始segment的长度为4（前4个字符）
            -- back_seg._end = original_start + 4
            -- back_seg.length = 4
            -- logger.info("修改原始segment长度为4: start=" .. back_seg.start .. ", end=" .. back_seg._end .. ", length=" .. back_seg.length)

            -- 打印修改后的segment信息
            -- logger.info("修改后的原始segment:")
            -- print_segment_info(back_seg, logger)
            
            -- 推进到下一轮，让current_start_position变为2
            -- logger.info("调用segmentation:forward()推进位置...")
            -- segmentation:forward()
            
            -- 创建第二个segment (后4个字符，punct tag)
            local second_seg = Segment(original_start, original_start + 4)
            logger.info("构建第二个segment完成: start=" .. original_start .. ", end=" .. (original_start + 4))

            -- 添加tag到第二个segment
            second_seg.tags = second_seg.tags + Set{"ascii"}
            logger.info("添加tag 'ascii' 到第二个segment")

            -- 立即添加第二个segment
            local add_success2, add_err2 = pcall(function()
                return segmentation:add_segment(second_seg)
            end)
            
            if add_success2 then
                local add_result2 = add_err2
                logger.info("第二个segment添加结果: " .. tostring(add_result2))
                if add_result2 then
                    print_segment_info(second_seg, logger)
                else
                    logger.info("第二个segment添加失败 - 可能是Segmentation内部逻辑限制")
                end
            else
                logger.info("第二个segment添加失败，错误: " .. tostring(add_err2))
            end
            
            logger.info("切分完成，总共尝试添加2个segments")
            logger.info("add_segment返回值说明：true=成功添加，false=添加失败或被合并")

            
            -- 步骤2：调用翻译器查询

            logger.info("成功获取env.translator，开始调用翻译器查询")  

            -- 尝试调用翻译器查询，并捕获错误
            -- 注意：segment的位置是0-based，需要转换为1-based用于Lua字符串切片
            logger.info("=== 字符串切片调试信息 ===")
            logger.info("原始input: '" .. input .. "'")
            logger.info("back_seg.start: " .. tostring(back_seg.start))
            logger.info("back_seg._end: " .. tostring(back_seg._end))
            logger.info("Lua切片参数: start=" .. tostring(back_seg.start + 1) .. ", end=" .. tostring(back_seg._end))
            
            local query_success, t1_or_error = pcall(function()
                local limited_input = string.sub(input, 1, 4) 
                return env.translator:query(limited_input, back_seg)
            end)
            
            if query_success then
                local t1 = t1_or_error
                logger.info("调用env.translator:query()成功，返回Translation对象")
                logger.info("t1的类型: " .. type(t1))
                logger.info("t1的值: " .. tostring(t1))
                
                -- 尝试遍历候选项，也添加错误捕获
                local iter_success, iter_error = pcall(function()
                    for cand in t1:iter() do
                        logger.info("候选项类型: " .. tostring(cand.type))
                        logger.info("候选项文本: " .. tostring(cand.text))
                        if cand.type == "completion" then
                            logger.info("找到completion候选项: " .. cand.text)
                        end
                    end
                end)
                
                if not iter_success then
                    logger.info("遍历候选项失败，错误: " .. tostring(iter_error))
                end
            else
                logger.info("调用env.script_translator:query()失败，错误: " .. tostring(t1_or_error))
            end
            
            -- 步骤3：从Translation中提取Candidate（如果查询成功）
            local candidates = {}
            if query_success and t1_or_error then
                local t1 = t1_or_error
                local extract_success, extract_error = pcall(function()
                    for candidate in t1:iter() do
                        table.insert(candidates, candidate)  -- 这是真实的Candidate对象
                        logger.info("提取到候选项: " .. tostring(candidate.text))
                    end
                end)
                
                if not extract_success then
                    logger.info("提取候选项失败，错误: " .. tostring(extract_error))
                end
                
                logger.info("总共提取到 " .. #candidates .. " 个候选项")
            else
                logger.info("跳过候选项提取，因为翻译器查询失败")
            end

            -- 重新打印所有segments
            logger.info("")
            logger.info("=== 切分后的所有 Segment 信息 ===")
            local new_segments = segmentation:get_segments()
            if new_segments and #new_segments > 0 then
                for i, seg in ipairs(new_segments) do
                    logger.info("")
                    logger.info(string.format("Segment %d:", i))
                    print_segment_info(seg, logger)
                end
            end
        end
    else
        logger.info("back() 返回 nil")
    end
    
    logger.info("")
    logger.info("=" .. string.rep("=", 60))
    
    return true
end



function debug_segmentor_advance.fini(env)
    logger.info("调试分词器结束")
end

return debug_segmentor_advance