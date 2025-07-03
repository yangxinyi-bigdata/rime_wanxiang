-- lua/script_backtick_translator.lua
-- 使用脚本翻译器处理反引号切分输入的translator
-- 通过text_splitter.split_by_backtick函数切分输入，对abc类型片段使用script_translator翻译

local text_splitter = require("text_splitter")
local logger_module = require("logger")

-- 创建当前模块的日志记录器
local logger = logger_module.create("script_backtick_translator", {
    enabled = true  -- 启用日志以便调试
})

local script_backtick_translator = {}

local backtick_delimiter = ""  -- 反引号分隔符

function script_backtick_translator.init(env)
    logger:info("脚本反引号翻译器初始化开始")
    -- 清空日志文件
    logger:clear()
    
    local config = env.engine.schema.config
    
    -- 读取反引号分隔符配置
    backtick_delimiter = config:get_string("translator/backtick_delimiter") or ""
    logger:info("反引号分隔符设置: '" .. backtick_delimiter .. "'")
    
    -- 创建script_translator组件
    env.script_translator = Component.Translator(env.engine, "translator", "script_translator")
    if env.script_translator then
        logger:info("成功创建script_translator组件")
    else
        logger:error("创建script_translator组件失败")
    end
    
    logger:info("脚本反引号翻译器初始化完成")
end

-- 使用script_translator获取候选词的第一个结果，同时返回text和preedit
local function get_first_candidate(input, seg, env)
    if not env.script_translator then
        logger:error("script_translator未初始化")
        return {text = input, preedit = input}
    end
    
    logger:info("查询script_translator，输入: " .. input)
    
    local success, translation = pcall(function()
        return env.script_translator:query(input, seg)
    end)
    
    if not success then
        logger:error("调用script_translator失败: " .. tostring(translation))
        return {text = input, preedit = input}
    end
    
    if translation then
        -- 获取第一个候选词
        for cand in translation:iter() do
            logger:info("获取到候选词: " .. cand.text .. ", preedit: " .. (cand.preedit or input))
            return {text = cand.text, preedit = cand.preedit or input}
        end
    end
    
    logger:info("未获取到候选词，返回原输入: " .. input)
    return {text = input, preedit = input}
end

function script_backtick_translator.func(input, seg, env)
    logger:info("开始处理输入: " .. input)
    
    -- 检查输入是否包含反引号
    if not input:match("`") then
        logger:info("输入不包含反引号，不处理")
        return
    end
    
    -- 使用text_splitter.split_by_backtick切分输入
    local segments = text_splitter.split_by_backtick_with_log(input, backtick_delimiter, logger)
    
    if not segments or #segments == 0 then
        logger:error("切分失败或无结果")
        return
    end
    
    -- 处理每个片段
    local final_result = ""
    local final_preedit = ""
    
    for i, segment in ipairs(segments) do
        local segment_text = ""
        local segment_preedit = ""
        
        if segment.type == "abc" then
            -- 文本片段：使用script_translator翻译
            logger:info(string.format("处理文本片段 %d: '%s'", i, segment.content))
            local result = get_first_candidate(segment.content, seg, env)
            segment_text = result.text
            segment_preedit = result.preedit
        elseif segment.type == "backtick" then
            -- 反引号内容：text是处理后的内容（包含分隔符），preedit是原始的带反引号内容
            logger:info(string.format("处理反引号片段 %d: '%s'", i, segment.content))
            segment_text = segment.content  -- 处理后的内容（包含分隔符）
            segment_preedit = segment.original or segment.content  -- 原始带反引号的内容
        else
            -- 其他类型：保持原样
            logger:info(string.format("处理其他类型片段 %d: type=%s, content='%s'", i, segment.type, segment.content))
            segment_text = segment.content
            segment_preedit = segment.content
        end
        
        final_result = final_result .. segment_text
        final_preedit = final_preedit .. segment_preedit
        logger:info(string.format("片段 %d 处理结果: text='%s', preedit='%s'", i, segment_text, segment_preedit))
    end
    
    logger:info("最终拼接结果: text='" .. final_result .. "', preedit='" .. final_preedit .. "'")
    
    -- 如果最终结果与原输入不同，则输出候选词
    if final_result ~= input and final_result ~= "" then
        local candidate = Candidate("sentence", seg.start, seg._end, final_result, "   [脚本翻译]")
        -- 使用拼接后的preedit
        candidate.preedit = final_preedit
        yield(candidate)
        logger:info("输出候选词: text='" .. final_result .. "', preedit='" .. final_preedit .. "'")
    else
        logger:info("结果与原输入相同或为空，不输出候选词")
    end
end

function script_backtick_translator.fini(env)
    logger:info("脚本反引号翻译器结束运行")
end

return script_backtick_translator
