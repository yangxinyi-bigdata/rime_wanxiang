-- 反引号分词器,判断如果当前输入的input当中存在反引号段, 将整个一段打上标签backtick
-- 然后由translator当中的lua/script_backtick_translator.lua 处理

local logger_module = require("logger")
local debug_utils = require("debug_utils")

-- 创建日志记录器
local logger = logger_module.create("backtick_segment", {
    enabled = true
})

local segmentor = {}

function segmentor.init(env)
    logger:clear()
    logger:info("backtick_segment初始化完成")
    logger:info("=" .. string.rep("=", 60))
end

function segmentor.func(segmentation, env)
    -- 使用debug_utils打印Segmentation信息
    debug_utils.print_segmentation_info(segmentation, logger)
    
    local input = segmentation.input
    
    logger:info("")
    logger:info(">>> 新的分词处理 <<<")
    logger:info("输入文本: '" .. input .. "'")
    logger:info("输入整个input长度: " .. #input)

    -- 判断当前的segmentation.input当中是否存在反引号. 
    local current_start = segmentation:get_current_start_position()
    local current_end = segmentation:get_current_end_position()
    local segment_input = input:sub(current_start + 1, current_end)
    logger:info("segment_input: " .. segment_input)
    
    -- 检查是否包含反引号
    if segment_input:find("`") then
        -- 将整个片段一直到末尾都标记成backtick类型
        local segment =  segmentation:back()
        segmentation:pop_back()
        logger:info("segment.start: " .. segment.start .. " segment._end: " .. segment._end .. "  segmente_input长度: " .. #segment_input)
        local new_segment = Segment(segment.start, #segment_input + 1)
        new_segment.tags = Set{"backtick", "abc"}
        if segmentation:add_segment(new_segment) then
            logger:info("成功将最后一个segment延长到末尾, 新的segment长度: " .. new_segment._end - new_segment.start)
        else
            logger:error("无法将最后一个segment延长到末尾")
        end
    end

    debug_utils.print_segmentation_info(segmentation, logger)

        
    logger:info("")
    logger:info("=" .. string.rep("=", 60))
    
    -- 返回true继续处理，false停止处理
    return true
end



function segmentor.fini(env)
    logger:info("调试分词器结束")
end

return segmentor