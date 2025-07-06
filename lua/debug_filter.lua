-- lua/debug_filter.lua - 调试filter，用于打印Translation和Segmentation信息
-- 可以帮助调试其他翻译器和过滤器的输出

local logger_module = require("logger")
local debug_utils = require("debug_utils")

-- 创建当前模块的日志记录器
local logger = logger_module.create("debug_filter", {
    enabled = true  -- 启用日志以便调试
})

local filter = {}

function filter.init(env)
    logger:clear()
    logger:info("调试过滤器初始化完成")
    logger:info("=" .. string.rep("=", 80))
end

function filter.func(translation, env)
    local engine = env.engine
    local context = engine.context
    local input = context.input
    
    logger:info()
    logger:info()
    logger:info(">>> 新的过滤器调试处理 <<<")
    logger:info("当前输入: '" .. input .. "'")
    logger:info("输入长度: " .. #input)
    
    -- 打印Environment信息
    debug_utils.print_env_info(env, logger)
    
    logger:info()
    
    -- 打印Segmentation信息
    local composition = context.composition
    if composition and not composition:empty() then
        local segment = composition:back()
        if segment then
            logger:info("=== 当前Segment信息 ===")
            debug_utils.print_segment_info(segment, logger)
            logger:info()
        end
    end
    
    -- 打印Translation信息并收集所有候选词
    logger:info("=== Translation输入信息 ===")
    local all_candidates = debug_utils.print_translation_detailed(translation, logger)
    
    logger:info()
    logger:info("=== 开始输出候选词 ===")
    
    -- 输出所有候选词并记录
    local count = 0
    for _, cand in ipairs(all_candidates) do
        count = count + 1
        
        -- -- 只记录前20个候选词的详细信息
        -- if count <= 20 then
        --     logger:info(string.format("输出候选词 %d: text='%s', comment='%s', type='%s'", 
        --         count, cand.text or "", cand.comment or "", cand.type or ""))
        -- end
        
        yield(cand)
    end
    
    logger:info("总共输出候选词数量: " .. count)
    logger:info("=" .. string.rep("=", 80))
end

function filter.fini(env)
    logger:info("调试过滤器结束运行")
end

return filter
