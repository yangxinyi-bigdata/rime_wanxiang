-- 调试分词器，用于打印Segmentation和Segment的详细信息

local logger_module = require("logger")

-- 创建日志记录器
local logger = logger_module.create("debug_segmentor", {
    enabled = true
})

-- 打印单个Segment的详细信息
local function print_segment_info(seg, logger)
    if not seg then
        logger:info("  segment is nil")
        return
    end
    
    -- 基本属性
    logger:info("  status: " .. tostring(seg.status))
    logger:info("  start: " .. tostring(seg.start))
    logger:info("  _start: " .. tostring(seg._start))
    logger:info("  _end: " .. tostring(seg._end))
    logger:info("  length: " .. tostring(seg.length))
    
    -- tags信息
    logger:info("  tags:")
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
            logger:info("    " .. table.concat(tag_list, ", "))
        else
            logger:info("    (无已知tags)")
        end
    else
        logger:info("    tags is nil")
    end
    
    -- 获取选中的候选项索引
    logger:info("  selected_index: " .. tostring(seg.selected_index))
    
    -- prompt信息
    local prompt = seg.prompt or ""
    if prompt ~= "" then
        logger:info("  prompt: '" .. prompt .. "'")
    else
        logger:info("  prompt: (空)")
    end
    
    -- 获取菜单信息
    if seg.menu then
        logger:info("  menu:")
        logger:info("    candidate_count: " .. tostring(seg.menu:candidate_count()))
        logger:info("    empty: " .. tostring(seg.menu:empty()))
        
        -- 打印前几个候选项
        local count = seg.menu:candidate_count()
        if count > 0 then
            logger:info("    前几个候选项:")
            for i = 0, math.min(count - 1, 4) do  -- 最多显示5个
                local cand = seg.menu:get_candidate_at(i)
                if cand then
                    logger:info(string.format("      %d. %s (%s)", i + 1, cand.text, cand.comment or ""))
                end
            end
        end
    else
        logger:info("  menu: nil")
    end
end

local segmentor = {}

function segmentor.init(env)
    logger:clear()
    logger:info("调试分词器初始化完成")
    logger:info("=" .. string.rep("=", 60))
end

function segmentor.func(segmentation, env)
    local input = segmentation.input
    
    logger:info("")
    logger:info(">>> 新的分词处理 <<<")
    logger:info("输入文本: '" .. input .. "'")
    logger:info("输入长度: " .. #input)
    
    -- 打印Segmentation对象信息
    logger:info("")
    logger:info("=== Segmentation 对象信息 ===")
    logger:info("size: " .. tostring(segmentation.size))
    logger:info("empty: " .. tostring(segmentation:empty()))
    
    -- 获取已确认位置
    local confirmed_pos = segmentation:get_confirmed_position()
    logger:info("confirmed_position: " .. tostring(confirmed_pos))
    
    -- 获取当前位置信息
    local current_start = segmentation:get_current_start_position()
    local current_end = segmentation:get_current_end_position()
    local current_length = segmentation:get_current_segment_length()
    logger:info("current_start_position: " .. tostring(current_start))
    logger:info("current_end_position: " .. tostring(current_end))
    logger:info("current_segment_length: " .. tostring(current_length))
    
    -- 检查是否完成分词
    logger:info("has_finished_segmentation: " .. tostring(segmentation:has_finished_segmentation()))
    
    -- 打印所有Segment信息
    logger:info("")
    logger:info("=== 所有 Segment 信息 ===")
    local segments = segmentation:get_segments()
    
    if segments and #segments > 0 then
        for i, seg in ipairs(segments) do
            logger:info("")
            logger:info(string.format("Segment %d:", i))
            print_segment_info(seg, logger)
        end
    else
        logger:info("没有segments")
    end
    
    -- 获取最后一个segment
    local back_seg = segmentation:back()
    if back_seg then
        logger:info("")
        logger:info("=== 最后一个 Segment (back) ===")
        print_segment_info(back_seg, logger)
    else
        logger:info("back() 返回 nil")
    end
    
    logger:info("")
    logger:info("=" .. string.rep("=", 60))
    
    -- 返回true继续处理，false停止处理
    return true
end



function segmentor.fini(env)
    logger:info("调试分词器结束")
end

return segmentor