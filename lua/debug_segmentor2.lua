-- 调试分词器，用于打印Segmentation和Segment的详细信息
local logger_module = require("logger")
local debug_utils = require("debug_utils")

-- 创建当前模块的日志记录器
local logger = logger_module.create("debug_segmentor2", {
    enabled = true, -- 启用日志以便测试
    unique_file_log = false, -- 启用日志以便测试
    log_level = "DEBUG"
})

local segmentor = {}

function segmentor.init(env)
    logger.clear()
    logger.info("调试分词器初始化完成")
    logger.info("=" .. string.rep("=", 60))
end

function segmentor.func(segmentation, env)
    -- 使用debug_utils打印Segmentation信息

    local input = segmentation.input

    logger.info("")
    logger.info("输入文本: '" .. input .. "'")
    logger.info("输入整个input长度: " .. #input)

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
