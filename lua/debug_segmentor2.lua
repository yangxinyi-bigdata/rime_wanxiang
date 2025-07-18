-- 调试分词器，用于打印Segmentation和Segment的详细信息

local logger_module = require("logger")
local debug_utils = require("debug_utils")

-- 创建日志记录器
local logger = logger_module.create("debug_segmentor2", {
    enabled = true
})

local segmentor = {}

function segmentor.init(env)
    logger.clear()
    logger.info("调试分词器初始化完成")
    logger.info("=" .. string.rep("=", 60))
end

function segmentor.func(segmentation, env)
    -- 使用debug_utils打印Segmentation信息
    debug_utils.print_segmentation_info(segmentation, logger)
    
    local input = segmentation.input
    
    logger.info("")
    logger.info(">>> 新的分词处理 <<<")
    logger.info("输入文本: '" .. input .. "'")
    logger.info("输入整个input长度: " .. #input)

    -- 测试,如果当前输入的末尾段当中存在特殊的内容,则把整段都标记成abc类型
    -- segmentation.input 长度是 7 , current_segment_length: 6 就说明后面有没接上的内容,那么就延长
    -- local current_segment_length = segmentation:get_current_segment_length()
    local segment =  segmentation:back()
    local current_segment_length = segment.length
    logger.info("当前分词长度: " .. current_segment_length)
    local length = #input - current_segment_length
    logger.info("两者差别长度: " .. length)
    if length > 0 then
        -- 将segmentation中的最后一个segment提取出来,延长到末尾
        logger.info("segment.start: " .. segment.start .. " #input: " .. #input)
        local new_segment = Segment(segment.start, #input)
        new_segment.tags = Set{"test"}
        if segmentation:add_segment(new_segment) then
            logger.info("成功将最后一个segment延长到末尾, 新的segment长度: " .. new_segment._end - new_segment.start)
        else
            logger.error("无法将最后一个segment延长到末尾")
        end

        
    end

    debug_utils.print_segmentation_info(segmentation, logger)

        
    logger.info("")
    logger.info("=" .. string.rep("=", 60))
    
    -- 返回true继续处理，false停止处理
    return true
end



function segmentor.fini(env)
    logger.info("调试分词器结束")
end

return segmentor