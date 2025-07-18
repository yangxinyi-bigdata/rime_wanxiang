-- 调试分词器，用于打印Segmentation和Segment的详细信息

local logger_module = require("logger")
local debug_utils = require("debug_utils")

-- 创建日志记录器
local logger = logger_module.create("debug_segmentor", {
    enabled = true
})

local segmentor = {}

function segmentor.init(env)
    logger.clear()
    logger.info("调试分词器初始化完成")
    logger.info("=" .. string.rep("=", 60))
end

function segmentor.func(segmentation, env)
    local input = segmentation.input
    
    logger.info("")
    logger.info(">>> 新的分词处理 <<<")
    logger.info("输入文本: '" .. input .. "'")
    logger.info("输入长度: " .. #input)
    
    -- 使用debug_utils打印Segmentation信息
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