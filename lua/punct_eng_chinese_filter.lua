-- lua/punct_eng_chinese_filter.lua
-- 将候选项当中的英文标点符号改成中文标点符号

-- 引入日志工具模块
local logger_module = require("logger")
-- 引入文本切分模块
local text_splitter = require("text_splitter")

-- 创建当前模块的日志记录器
local logger = logger_module.create("punct_eng_chinese_filter", {
    enabled = true  -- 可以通过这里控制日志开关
})

local punct_eng_chinese_filter = {}

function punct_eng_chinese_filter.init(env)
    -- 初始化时清空日志文件
    logger:clear()
    logger:info("云输入处理器初始化完成")

end

function punct_eng_chinese_filter.func(translation, env)

    local engine = env.engine
    local context = engine.context

    -- 使用 pcall 捕获所有可能的错误
    local success, error_msg = pcall(function()
        logger:info("标点符号过滤器开始处理")
        
        local count = 0  -- 用于计数，限制最多处理6个候选词
        -- 遍历所有候选词并进行标点符号替换
        for cand in translation:iter() do
            count = count + 1
            if cand.text and text_splitter.has_punctuation_no_backtick(cand.text, logger) and count < 3 then
                local original_text = cand.text
                local new_text = text_splitter.replace_punct(original_text)
                
                logger:info("标点替换: " .. original_text .. " -> " .. new_text)
                -- 根据文档，使用Candidate构造方法创建新候选项
                -- Candidate(type, start, end, text, comment)
                local new_cand = Candidate(
                    cand.type or "punct_converted",  -- 保持原有类型或标记为标点转换
                    cand.start or 0,  -- 分词开始位置
                    cand._end or 0,     -- 分词结束位置  
                    new_text,                        -- 替换后的文本
                    cand.comment or ""               -- 保持原有注释
                )
                -- 保持其他重要属性
                if cand.preedit then
                    new_cand.preedit = cand.preedit
                end
                yield(new_cand)  -- 输出新的候选词
            else
                -- 如果没有文本或不包含标点符号，直接输出原候选词
                yield(cand)
            end
        end
        
        logger:info("标点符号过滤器处理完成")
    end)

    -- 处理错误情况
    if not success then
        local error_message = tostring(error_msg)
        logger:error("标点符号过滤器发生错误: " .. error_message)
        
        -- 记录详细的错误信息用于调试
        logger:error("错误堆栈信息: " .. debug.traceback())
        
        -- 在发生错误时,安全地输出原始候选词
        for cand in translation:iter() do
            yield(cand)
        end
    end
end

function punct_eng_chinese_filter.fini(env)
    logger:info("punct_eng_chinese_filter结束运行")
end

return punct_eng_chinese_filter