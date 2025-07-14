-- 智能光标移动处理器 - 在标点符号处停止
local logger_module = require("logger")
local debug_utils = require("debug_utils")
-- 引入文本切分模块
local text_splitter = require("text_splitter")
-- 引入spans管理模块
local spans_manager = require("spans_manager")

-- 创建日志记录器
local logger = logger_module.create("smart_cursor_processor", {
    enabled = true
})

local smart_cursor_processor = {}

function smart_cursor_processor.init(env)
    local engine = env.engine
    local context = engine.context
    local config = engine.schema.config
    logger:clear()
    logger:info("智能光标移动处理器初始化完成")
    env.move_next_punct = config:get_string("key_binder/move_next_punct")
    env.move_prev_punct = config:get_string("key_binder/move_prev_punct")
    env.search_move_cursor = config:get_string("key_binder/search_move_cursor")
    -- 定义标点符号集合
    env.punctuation_chars = {
        [","] = true,
        ["."] = true,
        ["!"] = true,
        ["?"] = true,
        [";"] = true,
        [":"] = true,
        ["("] = true,
        [")"] = true,
        ["["] = true,
        ["]"] = true,
        ["<"] = true,
        [">"] = true,
        ["/"] = true,
        ["_"] = true,
        ["="] = true,
        ["+"] = true,
        ["*"] = true,
        ["&"] = true,
        ["^"] = true,
        ["%"] = true,
        ["$"] = true,
        ["#"] = true,
        ["@"] = true,
        ["~"] = true,
        ["|"] = true,
        ["-"] = true,
        ["'"] = true,
        ['"'] = true
    }

    env.select_notifier = context.select_notifier:connect(function(context)
        -- 只要出发了选词通知,就关闭搜索模式
        -- 退出搜索模式
        if context:get_option("search_move") then
            logger:debug("选词通知: 退出搜索模式")
            context:set_option("search_move", false)
            context:set_property("search_move_str", "")
        end

        -- 选词完成后清除spans信息
        spans_manager.clear_spans(context, "选词完成")
    end)

    -- env.commit_notifier = context.commit_notifier:connect(function(context)
    --     -- 只要出发了上屏通知,就关闭搜索模式
    --     -- 退出搜索模式
    --     logger:debug("触发上屏通知")
    --     if context:get_option("search_move") then
    --         logger:debug("上屏通知: 退出搜索模式")
    --         context:set_option("search_move", false)
    --         -- segment.prompt = ""
    --         context:set_property("search_move_str", "")
    --     end

    -- end)

    env.update_notifier = context.update_notifier:connect(function(context)
        -- 只要出发了上屏通知,就关闭搜索模式
        -- 退出搜索模式
        -- logger:debug("触发update_notifier context更新通知")
        if not context:is_composing() then
            if context:get_option("search_move") then
                logger:debug("update_notifier通知:is_composing为false, 退出搜索模式")
                context:set_option("search_move", false)
                context:set_property("search_move_str", "")
            end
        end

        -- local input = context.input or ""
        -- local caret_pos = context.caret_pos
        -- local is_composing = context:is_composing()
        -- logger:debug(string.format("输入变化: '%s', 光标:%d, 组合:%s", 
        --                    input, caret_pos, tostring(is_composing)))

    end)
    -- env.unhandled_key_notifier = context.unhandled_key_notifier:connect(function(context)
    --     -- 只要出发了上屏通知,就关闭搜索模式
    --     -- 退出搜索模式
    --     logger:debug("触发unhandled_key_notifier更新通知")

    -- end)

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
    local caret_pos = context.caret_pos
    logger:info("当前光标位置: " .. caret_pos)
    logger:info("caret_pos: " .. caret_pos .. " #input: " .. #input)
    if caret_pos == #input then
        caret_pos = current_start_position
        -- 这里应该直接
        logger:info("光标在末尾，直接从开头位置开始计算, 但并不需要真实移动光标: " ..
                        current_start_position)
    end

    local found_punctuation = false
    for i = caret_pos + 1, #input, 1 do
        -- 提取出当前索引对应字符
        local char = input:sub(i, i)
        logger:info("检查字符 " .. i .. ": " .. char)

        if env.punctuation_chars and env.punctuation_chars[char] then
            logger:info("找到标点符号 '" .. char .. "' 在位置 " .. i)

            -- 直接设置光标位置到标点符号后面
            context.caret_pos = i
            logger:info("直接设置光标位置到: " .. i)

            found_punctuation = true
            return true
        end
    end

    -- 如果没有找到标点符号，移动到末尾
    if not found_punctuation then
        logger:info("未找到标点符号，移动到末尾")
        context.caret_pos = #input
        logger:info("直接设置光标位置到末尾: " .. #input)
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
        context.caret_pos = #input
        logger:info("光标在开头，直接设置到末尾位置: " .. #input)
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

            -- 直接设置光标位置到标点符号后面
            context.caret_pos = i
            logger:info("直接设置光标位置到: " .. i)

            found_punctuation = true
            return true
        end
    end

    -- 如果没有找到标点符号，移动到开头
    if not found_punctuation then
        logger:info("未找到标点符号，移动到开头")
        context.caret_pos = current_start_position
        logger:info("直接设置光标位置到开头: " .. current_start_position)
    end
    return true
end

-- 基于 vertices 分割点进行智能光标移动（新版本，使用spans_manager）
function smart_cursor_processor.move_by_spans_manager(env)
    local engine = env.engine
    local context = engine.context
    local caret_pos = context.caret_pos

    logger:info("开始基于spans_manager进行光标移动")

    -- 使用spans_manager获取下一个光标位置
    -- 这里传入当前光标位置
    local next_pos = spans_manager.get_next_cursor_position(context, caret_pos)

    if next_pos ~= nil then
        logger:info("移动光标从 " .. caret_pos .. " 到 " .. next_pos)
        context.caret_pos = next_pos
        return true
    else
        logger:info("spans_manager未返回有效的下一个位置")
        return false
    end
end

-- 基于 vertices 分割点进行智能光标移动（兼容旧版本）
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

    -- 如果光标在最末尾，跳转到第二个分割点（第一个是0）
    if caret_pos == #input then
        logger:info("光标在末尾，跳转到开头")
        context.caret_pos = 0
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
                if i < #vertices then -- 不是最后一个分割点
                    next_vertex_pos = vertices[i + 1]
                    current_vertex_index = i + 1
                    logger:info(
                        "光标在分割点 " .. i .. " 上，跳转到下一个分割点: vertices[" .. (i + 1) ..
                            "] = " .. next_vertex_pos)
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
        logger:info("直接设置光标位置到: " .. next_vertex_pos)
        context.caret_pos = next_vertex_pos
        return true
    end

    return false
end

function smart_cursor_processor.func(key, env)
    local kRejected = 0
    local kAccepted = 1
    local kNoop = 2
    local engine = env.engine
    local context = engine.context
    local composition = context.composition
    local search_move_prompt = " ▶ [搜索模式:] "

    if not key or not context:is_composing() then
        return kNoop
    end

    local key_repr = key:repr()

    local success, result = pcall(function()

        -- local segmentation = context.composition:toSegmentation()
        -- debug_utils.print_segmentation_info(segmentation, logger)

        ------------------------------------------------------------------------
        -- 开始进入搜索模式
        if context:get_option("search_move") then
            logger:info("key_repr: " .. key_repr)

            -- 判断是否为英文字母或标点符号
            local is_valid_char = false
            if key_repr == "Tab" then
                is_valid_char = true
            elseif key_repr:match("^[a-zA-Z]$") then
                -- 英文字母
                is_valid_char = true
            elseif key_repr:match("^[%p]$") then
                -- 标点符号（不包含空格）
                is_valid_char = true
            end

            local segment = nil
            if (not composition:empty()) then
                segment = composition:back()
            end

            -- 如果是有效字符，执行搜索模式逻辑
            if is_valid_char then

                -- 在segment后面添加prompt
                if segment then

                    -- 这里有问题, 如果说其他程序替换了 prompt 怎么办                
                    -- if segment.prompt:sub(1, #search_move_prompt) == search_move_prompt then

                    -- 2. 继续输入的字母, 被拦截,然后将这个字母添加到prompt当中去, 获取也可以不添加,反正都跳过去了.
                    -- 3. 并且将这个字母记录下来, 在当前segment_input当中,从头搜索匹配的字母,然后进行跳转.再输入一个字母则有两个字母,用这两个字母进行跳转.
                    -- 4. 如果存在多个重复的搜索匹配项,怎么办？按tab键可以在多个重复项之间跳转.
                    -- 5. 如果搜索到的位置试想要跳转到的位置, 按下回车键,或者再次按下ctrl+f键退出搜索模式. 或者直接用空格进行选词,选词之后也会自动退出搜索模式

                    local add_search_move_str = ""
                    if key_repr == "Tab" then
                        local search_move_str = context:get_property("search_move_str")
                        add_search_move_str = search_move_str
                        logger:info("搜索模式中Tab, add_search_move_str不变: " .. add_search_move_str)
                    else
                        -- search_move_str就是搜索的字符串
                        local search_move_str = context:get_property("search_move_str")
                        add_search_move_str = search_move_str .. key_repr

                        context:set_property("search_move_str", add_search_move_str)
                        logger:info("add_search_move_str: " .. add_search_move_str)
                    end

                    -- segment.prompt = string.format(" ▶ [搜索模式:%s] ", add_search_move_str)
                    -- logger:info("更新搜索模式提示: " .. segment.prompt)

                    -- 移动光标位置,只在当前segment（未确认部分）中搜索
                    local input = context.input

                    local segmentation = context.composition:toSegmentation()

                    local confirmed_pos = segmentation:get_confirmed_position()
                    local confirmed_pos_input = input:sub(confirmed_pos + 1)
                    logger:info("confirmed_pos_input: " .. confirmed_pos_input)
                    local current_caret_pos = context.caret_pos

                    local caret_relative_pos = current_caret_pos - confirmed_pos

                    logger:info("光标在剩余input内的相对位置: " .. caret_relative_pos)

                    local search_start_pos = nil
                    -- 如果是tab模式,则光标移动到当前单词后面匹配, 如果不是tab模式,则光标移动到当前单词后面进行匹配.
                    if key_repr == "Tab" then
                        -- 对于tab模式,应该从当前光标位置开始搜索下一个符合的, 所以向后移动一位开始搜索
                        -- 从当前光标位置开始向后搜索
                        search_start_pos = caret_relative_pos + 1
                        -- 当tab键, 不用移动
                    else
                        -- 对于普通模式,应该是添加了一个字符串, 如果原来是"", 则现在变成了"w"
                        -- 如果原来是"w",则变成了"wo"
                        -- 应该从头开始搜索即可,只搜索第一个
                        -- 向前移动搜索字符长度个数 - 1
                        -- ni hk wo de wo 光标位置10, 搜索wo, 
                        search_start_pos = 1
                    end

                    local found_pos = text_splitter.find_text_skip_backticks_with_wrap(confirmed_pos_input,
                        add_search_move_str, search_start_pos, logger)
                    if found_pos then
                        local move_pos = confirmed_pos + found_pos - 1 + #add_search_move_str
                        context.caret_pos = move_pos
                        logger:info("在confirmed_pos_input内找到搜索字符串 '" .. add_search_move_str ..
                                        "' 在相对位置 " .. found_pos .. "，移动光标位置 " .. move_pos)
                    else
                        -- 当没有搜索到不会触发重新分词,需要自己添加prompt
                        segment.prompt = string.format(" ▶ [搜索模式:%s] ", add_search_move_str)
                        logger:info(
                            "在当前confirmed_pos_input内未找到搜索字符串 '" .. add_search_move_str .. "'")
                    end

                    -- local found_pos = string.find(confirmed_pos_input, add_search_move_str, search_start_pos, true)

                    -- if found_pos then
                    --     local move_pos = confirmed_pos + found_pos - 1 + #add_search_move_str
                    --     context.caret_pos = move_pos
                    --     logger:info("在confirmed_pos_input内找到搜索字符串 '" .. add_search_move_str ..
                    --                     "' 在相对位置 " .. found_pos .. "，移动光标位置 " .. move_pos)
                    -- else
                    --     -- 没找到，从segment开头搜索
                    --     found_pos = string.find(confirmed_pos_input, add_search_move_str, 1, true)
                    --     if found_pos then
                    --         local move_pos = confirmed_pos + found_pos - 1 + #add_search_move_str
                    --         context.caret_pos = move_pos
                    --         logger:info("从confirmed_pos_input开头搜索找到字符串 '" .. add_search_move_str ..
                    --                         "' 在相对位置 " .. found_pos .. "，移动光标位置 " .. move_pos)
                    --     else
                    --         -- 当没有搜索到不会触发重新分词,需要自己添加prompt
                    --         segment.prompt = string.format(" ▶ [搜索模式:%s] ", add_search_move_str)
                    --         logger:info("在当前confirmed_pos_input内未找到搜索字符串 '" ..
                    --                         add_search_move_str .. "'")
                    --     end
                    -- end

                    return kAccepted
                    -- else
                    --     logger:debug("退出搜索模式")
                    --     context:set_option("search_move", false)

                end

            elseif key_repr == "Escape" then
                -- 退出搜索模式
                logger:debug("退出搜索模式")
                context:set_option("search_move", false)
                -- segment.prompt = ""
                context:set_property("search_move_str", "")
                return kAccepted
            elseif key_repr == "BackSpace" then
                logger:debug("删除一个搜索字符串")
                local search_move_str = context:get_property("search_move_str")
                local delete_search_move_str = search_move_str:sub(1, -2)
                context:set_property("search_move_str", delete_search_move_str)
                logger:info("delete_search_move_str: " .. delete_search_move_str)
                segment.prompt = string.format(" ▶ [搜索模式:%s] ", delete_search_move_str)
                return kAccepted
            elseif key_repr == "Return" then
                -- 退出搜索模式
                logger:debug("退出搜索模式")
                context:set_option("search_move", false)
                -- segment.prompt = ""
                context:set_property("search_move_str", "")
                return kAccepted
            else
                logger:info("非有效搜索字符，跳过搜索模式处理")
            end

        end

        ------------------------------------------------------------------------
        -- -- 判断只要input发生了变化, 就清空属性
        -- local my_spans_input = context:get_property("my_spans_input")
        -- -- 如果等于空,则什么都不做, 如果不等于空,但是等于context.input 说明没有变化,不用清空
        -- if my_spans_input ~= "" and context.input ~= my_spans_input then
        --     -- 输入已变化，清空spans相关属性
        --     logger:debug("输入my_spans_input已变化, 清空my_spans_vertices和my_spans_input")
        --     context:set_property("my_spans_vertices", "")
        --     context:set_property("my_spans_input", "")
        -- end

        ------------------------------------------------------------------------

        -- 检测自定义的智能移动快捷键
        if key_repr == "Tab" then
            -- 尝试使用新的spans_manager进行光标移动
            if smart_cursor_processor.move_by_spans_manager(env) then
                return kAccepted
            end

            return kNoop

        elseif key_repr == env.move_prev_punct then
            logger:debug("触发向左智能移动")
            if smart_cursor_processor.move_to_prev_punctuation(env) then
                return kAccepted
            end
        elseif key_repr == env.move_next_punct then
            logger:debug("触发向右智能移动")
            if smart_cursor_processor.move_to_next_punctuation(env) then
                return kAccepted
            end
        elseif key_repr == env.search_move_cursor then
            -- 获得队尾的 Segment 对象
            local segment = composition:back()

            if not context:get_option("search_move") then
                logger:debug("进入搜索模式")
                context:set_option("search_move", true)

                if segment then
                    if segment.prompt ~= search_move_prompt then
                        segment.prompt = search_move_prompt
                        context:set_property("search_move_str", "")
                        logger:info("设置搜索模式提示: " .. search_move_prompt)
                    end

                end
            else
                logger:debug("退出搜索模式")
                context:set_option("search_move", false)
                if segment then
                    -- segment.prompt = ""
                    context:set_property("search_move_str", "")
                end
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
    if env.update_notifier then
        env.update_notifier:disconnect()
    end

    if env.select_notifier then
        env.select_notifier:disconnect()
    end

    -- if env.commit_notifier then
    --     env.commit_notifier:disconnect()
    -- end

    -- if env.delete_notifier then
    --     env.delete_notifier:disconnect()
    -- end

end

return smart_cursor_processor
