-- 智能光标移动处理器 - 在标点符号处停止
local logger_module = require("logger")
local debug_utils = require("debug_utils")

-- 创建日志记录器
local logger = logger_module.create("smart_cursor_processor", {
    enabled = true
})

local smart_cursor_processor = {}

function smart_cursor_processor.init(env)
    local config = env.engine.schema.config
    logger:clear()
    logger:info("智能光标移动处理器初始化完成")
    
    -- 定义标点符号集合
    env.punctuation_chars = {
        [","] = true, ["."] = true, ["!"] = true, ["?"] = true,
        [";"] = true, [":"] = true, ["("] = true, [")"] = true,
        ["["] = true, ["]"] = true, ["<"] = true, [">"] = true,
        ["/"] = true, ["_"] = true, ["="] = true, ["+"] = true,
        ["*"] = true, ["&"] = true, ["^"] = true, ["%"] = true,
        ["$"] = true, ["#"] = true, ["@"] = true, ["~"] = true,
        ["|"] = true, ["-"] = true, ["'"] = true, ['"'] = true,
    }

end

-- 向右移动光标直到遇到标点符号
function smart_cursor_processor.move_to_next_punctuation(env)
    local engine = env.engine
    local context = engine.context
    -- 应该是剩余的segment_input吧? 
    local input = context.input
    local segmentation = context.composition:toSegmentation()
    -- debug_utils.print_segmentation_info(segmentation, logger)
    
    if not segmentation then
        return false
    end
    
    local current_start_position = segmentation:get_current_start_position()
    local current_end_position = segmentation:get_current_end_position()
    local current_segment_length = segmentation:get_current_segment_length()
    -- local segment_input = input:sub(current_start_position + 1, current_end_position)
    local caret_pos = context.caret_pos
    logger:info("当前光标位置: " .. caret_pos)
    
    logger:info("当前片段开始位置current_start_position: " .. current_start_position)
    logger:info("当前片段结束位置current_end_position: " .. current_end_position)
    logger:info("当前输入: " .. input)
    
    -- 从当前位置开始向右查找标点符号
    -- 1. 如果当前光标处于末端, 则应该移动到从前向后的第一个标点符号结束
    -- 2. 如果光标当前处于最前端,则应该移动到从前向后的第一个标点符号结束
    -- 3. 如果光标处于其他位置,则应该移动到当前向后第一个标点符号结束
    -- 分几种情况吧：如果是在末尾, 循环判断标点符号在位置5,则移动5+1
    -- 如果是在最前端, 在移动5
    -- 如果是在第一个句子中, 例如 ni | hk wo de,mg xd jq ui ni, 这是current_end_position为2?
    -- 需要移动6位, 循环从current_end_position开始, #input结束
    -- 接下来考虑特殊情况,在最后一句当中, 向后移动发现没有标点符号了,怎么办? 移动到最后吧
    
    -- 如果本来就在末尾,则移动到第一句标点符号结束, 先移动到第一个,再执行后续移动
    logger:info("caret_pos: " .. caret_pos .. " #input: " .. #input)
    if caret_pos == #input then
        caret_pos = current_start_position
        engine:process_key(KeyEvent("Home"))
    end

    local found_punctuation = false
    for i = caret_pos + 1, #input, 1 do
        -- 提取出当前索引对应字符
        local char = input:sub(i, i)
        logger:info("检查字符 " .. i .. ": " .. char)

        if env.punctuation_chars and env.punctuation_chars[char] then
            logger:info("找到标点符号 '" .. char .. "' 在位置 " .. i)
            
            -- 计算需要移动的步数
            local steps = i - caret_pos
            logger:info("需要移动 " .. steps .. " 步")
            
            -- 发送相应数量的右移命令（按字符移动）
            for j = 1, steps do
                engine:process_key(KeyEvent("KP_Right"))
            end
            
            found_punctuation = true
            return true
        end
    end
    
    -- 如果没有找到标点符号，移动到末尾
    if not found_punctuation then
        logger:info("未找到标点符号，移动到末尾")
        engine:process_key(KeyEvent("End"))
    end
    return true
end

-- 向左移动光标直到遇到标点符号
function smart_cursor_processor.move_to_prev_punctuation(env)
    local engine = env.engine
    local context = engine.context
    -- 应该是剩余的segment_input吧? 
    local input = context.input
    local segmentation = context.composition:toSegmentation()
    -- debug_utils.print_segmentation_info(segmentation, logger)
    
    if not segmentation then
        return false
    end
    
    local current_start_position = segmentation:get_current_start_position()
    local current_end_position = segmentation:get_current_end_position()
    local current_segment_length = segmentation:get_current_segment_length()
    local caret_pos = context.caret_pos
    logger:info("当前光标位置: " .. caret_pos)
    
    logger:info("当前片段开始位置current_start_position: " .. current_start_position)
    logger:info("当前片段结束位置current_end_position: " .. current_end_position)
    logger:info("当前输入: " .. input)
    
    -- 从当前位置开始向左查找标点符号
    -- 1. 如果当前光标处于末端, 则应该移动到前一个标点符号结束
    -- 2. 如果光标当前处于最前端,则应该移动到最后
    -- 3. 如果光标处于第一句话中间, 则应该移动到开头
    -- 如果光标处于第二句话中间,则应该移动到前一个标点符号结束
    -- 
    -- 
    -- 如果是在第一个句子中, 例如 ni | hk wo de,mg xd jq ui ni
    -- ni | hk wo de,mg xd jq, ui ni 移动后应该是:  | ni hk wo de,mg xd jq, ui ni
    -- ni hk wo de,mg | xd jq, ui ni 移动后应该是:  ni hk wo de,| mg xd jq, ui ni
    -- ni hk wo de,mg xd jq, ui ni |  移动后应该是:  ni hk wo de, mg xd jq,| ui ni
    -- | ni hk wo de,mg xd jq, ui ni   移动后应该是:  ni hk wo de, mg xd jq,ui ni | 
    
    -- 如果本来就在末尾,则移动到第一句标点符号结束, 先移动到第一个,再执行后续移动
    logger:info("caret_pos: " .. caret_pos .. " #input: " .. #input)
    if caret_pos == current_start_position then
        engine:process_key(KeyEvent("End"))
        return true
    end

    local found_punctuation = false
    -- 从当前光标位置向前移动, 每次移动一格, 然后判断当前光标是否标点符号
    for i = caret_pos - 1, current_start_position, -1 do
        -- 提取出当前索引对应字符
        local char = input:sub(i, i)
        logger:info("检查字符 " .. i .. ": " .. char)

        if env.punctuation_chars and env.punctuation_chars[char] then
            logger:info("找到标点符号 '" .. char .. "' 在位置 " .. i)
            
            -- 计算需要移动的步数
            local steps = caret_pos - i
            logger:info("需要移动 " .. steps .. " 步")
            
            -- 发送相应数量的左移命令（按字符移动）
            for j = 1, steps do
                engine:process_key(KeyEvent("KP_Left"))
            end
            
            found_punctuation = true
            return true
        end
    end
    
    -- 如果没有找到标点符号，移动到末尾
    if not found_punctuation then
        logger:info("未找到标点符号，移动到开头")
        engine:process_key(KeyEvent("Home"))
    end
    return true
end

-- 基于 vertices 分割点进行智能光标移动
function smart_cursor_processor.move_by_vertices(env, vertices_str)
    local engine = env.engine
    local context = engine.context
    
    logger:info("开始手动移动tab光标位置, vertices_str: " .. vertices_str)
    
    -- 读取 vertices 信息
    local vertices = {}
    for vertex_str in vertices_str:gmatch("[^,]+") do
        table.insert(vertices, tonumber(vertex_str))
    end

    for i, vertex in ipairs(vertices) do
        logger:info("spans Vertex " .. i .. ": " .. vertex)
    end

    -- 获取当前光标位置
    local caret_pos = context.caret_pos
    local input = context.input
    logger:info("当前光标位置: " .. caret_pos .. ", 输入长度: " .. #input)
    
    -- 找到当前光标位置在 vertices 中的位置
    local current_vertex_index = nil
    local next_vertex_pos = nil
    
    -- 如果光标在最末尾，跳转到第一个分割点
    if caret_pos == #input then
        logger:info("光标在末尾，跳转到开头")
        engine:process_key(KeyEvent("Home"))
        next_vertex_pos = vertices[2] 
        caret_pos = 0
    else
        -- 查找当前光标所在的区间
        for i = 1, #vertices do
            if caret_pos < vertices[i] then
                next_vertex_pos = vertices[i]
                current_vertex_index = i
                logger:info("找到下一个分割点: vertices[" .. i .. "] = " .. next_vertex_pos)
                break
            elseif caret_pos == vertices[i] then
                -- 光标正好在分割点上，跳转到下一个分割点
                if i < #vertices then  -- 不是最后一个分割点
                    next_vertex_pos = vertices[i + 1]
                    current_vertex_index = i + 1
                    logger:info("光标在分割点 " .. i .. " 上，跳转到下一个分割点: vertices[" .. (i + 1) .. "] = " .. next_vertex_pos)
                else
                    -- 已经是最后一个分割点，跳转到末尾
                    next_vertex_pos = #input
                    logger:info("已在最后分割点，跳转到末尾: " .. next_vertex_pos)
                end
                break
            end
        end
        
        -- 如果没有找到下一个分割点，说明已经在最后一个区间，跳转到末尾
        if not next_vertex_pos then
            next_vertex_pos = #input
            logger:info("在最后区间，跳转到末尾: " .. next_vertex_pos)
        end
    end
    
    -- 执行光标移动
    if next_vertex_pos then
        -- 当光标在末尾, caret_pos = 16 next_vertex_pos = 2  -14
        local steps = next_vertex_pos - caret_pos
        logger:info("需要移动 " .. steps .. " 步，从位置 " .. caret_pos .. " 到 " .. next_vertex_pos)
        
        if steps > 0 then
            -- 向右移动
            for j = 1, steps do
                engine:process_key(KeyEvent("KP_Right"))
            end
        elseif steps < 0 then
            -- 向左移动
            for j = 1, -steps do
                engine:process_key(KeyEvent("KP_Left"))
            end
        end
        
        return true
    end
    
    return false
end

function smart_cursor_processor.func(key, env)
    local kRejected = 0
    local kAccepted = 1
    local kNoop = 2
    
    local success, result = pcall(function()
        local engine = env.engine
        local context = engine.context
        
        if not key or not context:is_composing() then
            return kNoop
        end
        
        local key_repr = key:repr()

        -- local segmentation = context.composition:toSegmentation()
        -- debug_utils.print_segmentation_info(segmentation, logger)
        
        -- 检测自定义的智能移动快捷键
        if key_repr == "Tab" then
 
            -- 判断当前input的值是否等于spans_input, 如果等于说明需要继续手动移动光标
            -- 如果不等于, 说明重新计算过了, 不需要处理tab. context.input

            if context:get_property("spans_input") == "" then
                logger:info("spans_input属性不存在")
                return kNoop
            else
                -- logger:info("spans_input属性存在, spans_input: " .. tostring(context:get_property("spans_input"))  .. " context.input:" .. context.input)
                if context.input ~= context:get_property("spans_input") then
                    context:set_property("out_spans_vertices", "")
                    context:set_property("spans_input","")
                    return kNoop
                end
            end

            -- tab键,判断context:set_property("out_spans_vertices", vertices_str) 是否存在内容
            -- 如果不为空,则进入tab移动功能
            local vertices_str = context:get_property("out_spans_vertices")
            if vertices_str and vertices_str ~= "" then
                if smart_cursor_processor.move_by_vertices(env, vertices_str) then
                    return kAccepted
                end
            else 
                return kNoop
            end

        elseif key_repr == "Super+d" then
            logger:info("触发向左智能移动")
            if smart_cursor_processor.move_to_prev_punctuation(env) then
                return kAccepted
            end
        elseif key_repr == "Super+f" then
            logger:info("触发向右智能移动")
            if smart_cursor_processor.move_to_next_punctuation(env) then
                return kAccepted
            end
        end
        
        return kNoop
    end)
    
    if not success then
        logger:error("智能光标移动处理器错误: " .. tostring(result))
        return kNoop
    end
    
    return result or kNoop
end

function smart_cursor_processor.fini(env)
    logger:info("智能光标移动处理器结束运行")
end

return smart_cursor_processor
