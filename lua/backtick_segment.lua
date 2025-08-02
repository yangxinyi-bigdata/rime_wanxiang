-- 反引号分词器,判断如果当前输入的input当中存在反引号段, 将整个一段打上标签backtick
-- 然后由translator当中的lua/script_backtick_translator.lua 处理

local logger_module = require("logger")
local debug_utils = require("debug_utils")

-- 创建当前模块的日志记录器
local logger = logger_module.create("backtick_segment", {
    enabled = false, -- 启用日志以便测试
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

    local input = segmentation.input
    logger.info("")
    logger.info(">>> 新的分词处理 <<<")
    logger.info("输入文本: '" .. input .. "'")
    logger.info("输入整个input长度: " .. #input)

    -- 使用debug_utils打印Segmentation信息
    -- debug_utils.print_segmentation_info(segmentation, logger)

    -- 这个时候应该将剩余的所有内容都切出来 
    local segment_input = ""  -- 这个就是无论在每种情况下,都应该切除的是剩余的段,或者是segmentation.input? 
    local end_position = 0   -- 这个要的是一直延伸到最后
    -- 当修改了位置之后, 改到abc分词后面, 不再是刚才的规律了
    -- 这个地方有几种可能? 必须都是包含`符号的, 一种是新增一个字母, 一种是删除一个字母,一种是选词, 一种是新增一个8,四种情况,我要都判断出来,然后进行适配
    -- 所以应该是这样, 前三种都不需要动,直接添加标签就可以. 第四种需要延长, 如果区分第四种呢? 

    -- 将整个片段一直到末尾都标记成backtick类型
    local segment =  segmentation:back()
    -- 非选词的分支,和原来一样
    segment_input = input:sub(segment.start + 1, segment._end)
    -- end_position = #segmentation.input + 1
    end_position = #segmentation.input
    logger.info("segment_input: " .. segment_input)
    logger.info("segment.start: " .. segment.start .. " segment._end: " .. segment._end .. " end_position : " .. end_position)

    -- 检查是否包含反引号
    if segment_input:find("`") then
        segmentation:pop_back()
        
        local new_segment = Segment(segment.start, end_position)
        new_segment.tags = Set{"backtick", "abc"}
        segmentation:forward()
        if segmentation:add_segment(new_segment) then
            logger.info("成功将最后一个segment延长到末尾, 新的segment长度: " .. new_segment._end - new_segment.start)
        else
            logger.error("无法将最后一个segment延长到末尾")
            new_segment = Segment(segment.start, segment._end)
            new_segment.tags = Set{"backtick", "abc"}
            if segmentation:add_segment(new_segment) then
                logger.info("使用segment._end添加成功, 新的segment长度: " .. new_segment._end - new_segment.start)
            else
                logger.error("使用segment._end也无法成功添加segment")
            end

        end
        debug_utils.print_segmentation_info(segmentation, logger)
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