-- 整个这段是非常简单的,就是判断如果说last_segment中含有反引号, 就将整个segmentation延伸到最后,全部标记上backtick标签
-- 然后由translator当中的lua/script_backtick_translator.lua 处理
local logger_module = require("logger")
local debug_utils = require("debug_utils")

-- 创建当前模块的日志记录器
local logger = logger_module.create("backtick_segment", {
    enabled = true, -- 启用日志以便测试
    unique_file_log = false, -- 启用日志以便测试
    log_level = "DEBUG"
})

local segmentor = {}

function segmentor.init(env)
    logger.clear()
    logger.info("backtick_segment初始化完成")
    logger.info("=" .. string.rep("=", 60))
end

function segmentor.func(segmentation, env)
    local context = env.engine.context
    local input = segmentation.input
    local config = env.engine.schema.config
    local english_mode_symbol = config:get_string("translator/english_mode_symbol")
    logger.info("")
    logger.info(">>> 新的分词处理 <<<")
    logger.info("输入文本: '" .. input .. "'")
    logger.info("输入整个input长度: " .. #input)

    local current_start = segmentation:get_current_start_position()
    local current_end = segmentation:get_current_end_position()
    local current_start_input = input:sub(current_start + 1, current_end)
    logger.info("current_start_input: " .. current_start_input)

    -- 检测以反引号片段开头的情况
    if current_start_input:sub(1, 1) == english_mode_symbol then
        -- 查找第一个反引号片段的结束位置
        local backtick_end = current_start_input:find(english_mode_symbol, 2)
        local backtick_length, backtick_content
        
        if backtick_end then
            -- 找到配对的结束反引号
            backtick_length = backtick_end
            backtick_content = current_start_input:sub(1, backtick_length)
            logger.info("检测到完整的反引号片段:")
        else
            -- 没有找到配对的结束反引号，将整个输入作为反引号片段
            backtick_length = #current_start_input
            backtick_content = current_start_input
            logger.info("检测到未闭合的反引号片段:")
        end

        logger.info("  反引号片段: '" .. backtick_content .. "' (长度: " .. backtick_length .. ")")

        -- 删除当前的segment
        local last_segment = segmentation:back()
        segmentation:pop_back()

        -- 添加反引号片段的segment
        local backtick_segment = Segment(current_start, current_start + backtick_length)
        backtick_segment.tags = Set {"single_backtick"}

        segmentation:forward()
        if segmentation:add_segment(backtick_segment) then
            logger.info("成功添加反引号片段segment (start: " .. current_start .. ", end: " ..
                            (current_start + backtick_length) .. ")")

            -- 完成分割后直接返回，不继续后续处理
            logger.info("反引号片段分割完成，跳过后续处理")
            return false
        else
            logger.error("无法添加反引号片段segment")
        end
    end

    -- 使用debug_utils打印Segmentation信息
    -- debug_utils.print_segmentation_info(segmentation, logger)

    -- 判断内容正处于英文输入模式当中: 也就是处于一个未闭合的反引号当中.
    local _, backtick_count = current_start_input:gsub(english_mode_symbol, "")
    if backtick_count % 2 == 1 then
        logger.debug("检测到奇数个反引号,存在未闭合情况: " .. current_start_input ..
                         " (反引号数量: " .. backtick_count .. ")")
        -- 只在值真正需要改变时才设置
        -- 先获取当前选项的值，避免不必要的更新
        logger.debug("当前英文模式backtick_prompt: " .. context:get_property("backtick_prompt"))
        if context:get_property("backtick_prompt") == "0" then
            logger.debug("backtick_prompt提示标志为 0, 设置为 1")
            context:set_property("backtick_prompt", "1")
            logger.debug("backtick_prompt 已设置为 1")
        end

    else
        logger.debug("检测到偶数个反引号: " .. current_start_input ..
                         " (反引号数量: " .. backtick_count .. ")")
        -- 如果不在组词状态或没有达到触发条件,则重置提示选项
        logger.debug("当前不在反引号当中backtick提示已重置")
        if context:get_property("backtick_prompt") == "1" then
            context:set_property("backtick_prompt", "0")
            logger.debug("backtick_prompt 已设置为 0")
        end
    end

    -- 将整个片段一直到末尾都标记成backtick类型, 第一段反引号片段必然已经处理完了, 所以这里只能是abc开始的.
    local last_segment = segmentation:back()
    -- 非选词的分支,和原来一样
    local last_segment_input = input:sub(last_segment.start + 1, last_segment._end)
    -- end_position = #segmentation.input + 1
    local end_position = #segmentation.input
    logger.info("last_segment_input: " .. last_segment_input)
    logger.info("last_segment.start: " .. last_segment.start .. " last_segment._end: " .. last_segment._end ..
                    " end_position : " .. end_position)

    -- 检查是否包含反引号, nihk`haha`woqu 这类的内容
    if last_segment_input:find(english_mode_symbol) then
        segmentation:pop_back()

        local new_segment = Segment(last_segment.start, last_segment._end)
        new_segment.tags = Set {"backtick_combo", "abc"}
        segmentation:forward()
        if segmentation:add_segment(new_segment) then
            logger.info("成功将最后一个segment延长到末尾, 新的segment长度: " .. new_segment._end -
                            new_segment.start)
        else
            logger.error("无法将最后一个segment延长到末尾")
            new_segment = Segment(last_segment.start, end_position)
            new_segment.tags = Set {"backtick_combo", "abc"}
            if segmentation:add_segment(new_segment) then
                logger.info("使用segment._end添加成功, 新的segment长度: " .. new_segment._end -
                                new_segment.start)
            else
                logger.error("使用segment._end也无法成功添加segment")
            end

        end
        -- debug_utils.print_segmentation_info(segmentation, logger)
    end

    logger.info("")
    logger.info("=" .. string.rep("=", 60))

    -- 返回true继续处理，false停止处理
    return true
end

function segmentor.fini(env)
    logger.info("调试分词器结束")
end

return segmentor
