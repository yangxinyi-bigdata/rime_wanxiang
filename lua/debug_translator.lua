-- debug_translator.lua - 调试翻译器，用于打印Translation和Candidate的详细信息

local logger_module = require("logger")
local debug_utils = require("debug_utils")

-- 创建日志记录器
local logger = logger_module.create("debug_translator", {
    enabled = true
})

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
    
    -- 使用debug_utils打印Segmentation信息
    debug_utils.print_segmentation_info(segmentation, logger)
    
    -- Segment信息
    logger:info("")
    debug_utils.print_segment_info(seg, logger)
    
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
