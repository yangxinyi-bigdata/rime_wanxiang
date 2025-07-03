-- debug_translator.lua - 调试翻译器，用于打印Translation和Candidate的详细信息

local logger_module = require("logger")

-- 创建日志记录器
local logger = logger_module.create("debug_translator", {
    enabled = true
})

-- 打印Candidate的详细信息
local function print_candidate_info(cand, index)
    if not cand then
        logger:info("  candidate is nil")
        return
    end
    
    logger:info(string.format("  候选项 %d:", index))
    logger:info("    type: " .. tostring(cand.type))
    logger:info("    start: " .. tostring(cand.start))
    logger:info("    _end: " .. tostring(cand._end))
    logger:info("    text: '" .. (cand.text or "") .. "'")
    logger:info("    comment: '" .. (cand.comment or "") .. "'")
    logger:info("    preedit: '" .. (cand.preedit or "") .. "'")
    logger:info("    quality: " .. tostring(cand.quality))

end

-- 打印Segment的详细信息（针对翻译器）
local function print_segment_info_for_translator(seg)
    if not seg then
        logger:info("  segment is nil")
        return
    end
    
    logger:info("=== Segment 信息 ===")
    logger:info("  status: " .. tostring(seg.status))
    logger:info("  start: " .. tostring(seg.start))
    logger:info("  _start: " .. tostring(seg._start))
    logger:info("  _end: " .. tostring(seg._end))
    logger:info("  length: " .. tostring(seg.length))
    
    -- tags信息
    logger:info("  tags:")
    if seg.tags then
        local tag_list = {}
        for tag in pairs(seg.tags) do
            table.insert(tag_list, tag)
        end
        
        if #tag_list > 0 then
            logger:info("    " .. table.concat(tag_list, ", "))
        else
            logger:info("    (无tags)")
        end
    else
        logger:info("    tags is nil")
    end
    
    logger:info("  selected_index: " .. tostring(seg.selected_index))
    
    local prompt = seg.prompt or ""
    if prompt ~= "" then
        logger:info("  prompt: '" .. prompt .. "'")
    else
        logger:info("  prompt: (空)")
    end
end

-- 打印Translation的详细信息
local function print_translation_info(translation)
    if not translation then
        logger:info("Translation is nil")
        return
    end
    
    logger:info("=== Translation 对象信息 ===")
    logger:info("exhausted: " .. tostring(translation.exhausted))
    
    -- 统计候选项数量
    local count = 0
    local candidates = {}
    
    -- 收集候选项信息
    for cand in translation:iter() do
        count = count + 1
        table.insert(candidates, cand)
        
        -- 限制收集数量避免日志过长
        if count >= 10 then
            break
        end
    end
    
    logger:info("候选项数量: " .. count .. (count >= 10 and " (显示前10个)" or ""))
    
    -- 打印候选项详细信息
    if #candidates > 0 then
        logger:info("")
        logger:info("=== 候选项详细信息 ===")
        for i, cand in ipairs(candidates) do
            print_candidate_info(cand, i)
            logger:info("")
        end
    end
end

-- 打印Environment信息
local function print_env_info(env)
    if not env then
        logger:info("Environment is nil")
        return
    end
    
    logger:info("=== Environment 信息 ===")
    
    -- Engine信息
    if env.engine then
        logger:info("Engine:")
        logger:info("  schema_id: " .. (env.engine.schema and env.engine.schema.schema_id or "nil"))
        logger:info("  active_engine: " .. tostring(env.engine.active_engine))
        
        -- Context信息
        if env.engine.context then
            local ctx = env.engine.context
            logger:info("  Context:")
            logger:info("    input: '" .. (ctx.input or "") .. "'")
            logger:info("    caret_pos: " .. tostring(ctx.caret_pos))
            logger:info("    commit_history: " .. tostring(ctx.commit_history))
            
            -- 获取选项状态
            local options = {"ascii_mode", "ascii_punct", "full_shape", "simplification"}
            logger:info("    options:")
            for _, opt in ipairs(options) do
                local status = ctx:get_option(opt)
                logger:info("      " .. opt .. ": " .. tostring(status))
            end
            
            -- Composition信息
            if ctx.composition then
                local comp = ctx.composition
                logger:info("    Composition:")
                logger:info("      empty: " .. tostring(comp:empty()))
                if not comp:empty() then
                    logger:info("      length: " .. tostring(comp.length))
                    
                    -- 获取最后一个segment
                    local back_seg = comp:back()
                    if back_seg then
                        logger:info("      back segment info:")
                        print_segment_info_for_translator(back_seg, logger)
                    end
                end
            end
        end
    end
    
    -- 检查名字空间中的变量
    logger:info("Name space variables:")
    if env.name_space then
        for k, v in pairs(env.name_space) do
            logger:info("  " .. tostring(k) .. ": " .. tostring(type(v)))
        end
    else
        logger:info("  name_space is nil")
    end
end

local translator = {}

function translator.init(env)
    logger:clear()
    logger:info("调试翻译器初始化完成")
    logger:info("=" .. string.rep("=", 80))
end

function translator.func(input, seg, env)
    -- 首先思考我想打印的是什么信息？ 
    
    -- 输入信息
    logger:info("")
    logger:info("=== 输入信息 ===")
    logger:info("时间戳: " .. os.date("%Y-%m-%d %H:%M:%S"))
    logger:info("input: '" .. (input or "") .. "'")
    logger:info("input length: " .. #(input or ""))

    -- 输出Segmentation当中的全部信息:
    local composition = env.engine.context.composition
    local segmentation = composition:toSegmentation()
    if not segmentation then
        logger:info("Segmentation is nil")
        return
    end
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
        for i, seg_in in ipairs(segments) do
            logger:info("")
            logger:info(string.format("Segment %d:", i))
            print_segment_info_for_translator(seg_in)
        end
    else
        logger:info("没有segments")
    end
    
    -- Segment信息
    logger:info("")
    print_segment_info_for_translator(seg)
    
    -- Environment信息（简化版）
    logger:info("")
    logger:info("=== 当前 Environment 状态 ===")
    if env.engine and env.engine.context then
        local ctx = env.engine.context
        logger:info("context.input: '" .. (ctx.input or "") .. "'")
        logger:info("context.caret_pos: " .. tostring(ctx.caret_pos))
        
        -- 获取当前composition状态
        if ctx.composition and not ctx.composition:empty() then
            logger:info("composition.length: " .. tostring(ctx.composition.length))
        end
    end
    
    logger:info("")
    logger:info("翻译处理完成")
    logger:info("=" .. string.rep("=", 80))
end

function translator.fini(env)
    logger:info("")
    logger:info("调试翻译器结束运行")
    logger:info("结束时间: " .. os.date("%Y-%m-%d %H:%M:%S"))
    logger:info("=" .. string.rep("=", 80))
end

return translator
