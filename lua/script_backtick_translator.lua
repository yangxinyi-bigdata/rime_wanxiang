-- lua/script_backtick_translator.lua
-- 使用脚本翻译器处理反引号切分输入的translator
-- 通过text_splitter.split_by_backtick函数切分输入，对abc类型片段使用script_translator翻译

local text_splitter = require("text_splitter")
local logger_module = require("logger")
local debug_utils = require("debug_utils")

-- 创建当前模块的日志记录器
local logger = logger_module.create("script_backtick_translator", {
    enabled = true  -- 启用日志以便调试
})

local script_backtick_translator = {}

local backtick_delimiter_before = ""  -- 反引号分隔符
local backtick_delimiter_after = ""
local replace_punct_enabled = false

-- 只在选词完成后回调, 判断当前输入内容当中, 第一个字符是否反引号,
-- 如果是反引号片段,则再次发送一次确认，确认当前第一个候选项.
local function backtick_before(context)
    -- logger:info("选择通知器: 处理反引号片段自动上屏开始")
    -- 防止递归
    if context:get_option("_bt_auto") then
        return 
    end
    context:set_option("_bt_auto", true)

    -- 连续确认后续带有 backtick 标记的片段
    logger:info("选择通知器: 开始处理反引号片段自动上屏")
    logger:info("context:is_composing(): " .. tostring(context:is_composing()))
    if context:is_composing() then
        local composition = context.composition
        local segment  = composition:back()       -- 当前光标所在段
        -- debug_utils.print_segment_info(segment, logger)

        local input = context.input
        -- 对input进行切片
        local segment_input = input:sub(segment.start + 1, segment._end)  -- 获取当前段的输入内容
        logger:info("当前段的输入内容: " .. segment_input)

        -- 检查当前seg对应的input, 是否以反引号开头,如果是以反引号开头,则提取出反引号包裹的范围, 直接确认选择.
        if segment and segment_input:match("^`") then
            logger:info("当前段是反引号片段，选择第一个候选项")
            -- context:commit()
            if context:confirm_current_selection() then
                logger:info("确认当前选择成功")
            else
                logger:error("确认当前选择失败")
            end
        end     
    end

  context:set_option("_bt_auto", false)
end

function script_backtick_translator.init(env)
    logger:info("脚本反引号翻译器初始化开始")
    -- 清空日志文件
    logger:clear()

    local engine = env.engine
    local config = engine.schema.config

    -- 读取反引号分隔符配置
    backtick_delimiter_before = config:get_string("translator/backtick_delimiter_before") or ""
    backtick_delimiter_after = config:get_string("translator/backtick_delimiter_after") or ""
    replace_punct_enabled = config:get_string("translator/replace_punct_enabled") or false
    -- logger:info("反引号分隔符设置: '" .. backtick_delimiter_before .. "' '" .. backtick_delimiter_after .. "'")

    -- 创建script_translator组件
    env.script_translator = Component.Translator(engine, "translator", "script_translator")
    if env.script_translator then
        logger:info("成功创建script_translator组件")
    else
        logger:error("创建script_translator组件失败")
    end
    
    logger:info("脚本反引号翻译器初始化完成")

    -- 监听选词事件
    engine.context.select_notifier:connect(backtick_before)

end



-- 使用script_translator获取多个候选词，返回完整的Candidate列表
local function get_candidates(input, seg, env, max_count)
    if not env.script_translator then
        logger:error("script_translator未初始化")
        return {}
    end
    
    logger:info("查询script_translator，输入: " .. input .. ", 最大候选词数: " .. max_count)
    
    local success, translation = pcall(function()
        -- 将seg标签改成abc
        return env.script_translator:query(input, seg)
    end)
    
    if not success then
        logger:error("调用script_translator失败: " .. tostring(translation))
        return {}
    end
    
    local candidates = {}
    if translation then
        local count = 0
        -- 获取指定数量的候选词
        for cand in translation:iter() do
            if count >= max_count then
                break
            end
            table.insert(candidates, cand)
            logger:info("candidates中插入一个cand")
            count = count + 1
        end
    end
    
    if #candidates == 0 then
        logger:info("未获取到候选词，返回空列表")
    else
        logger:info("共获取到 " .. #candidates .. " 个候选词")
    end
    
    return candidates
end

function script_backtick_translator.func(input, seg, env)
    local context = env.engine.context

    logger:info("")
    logger:info("")
    logger:info("开始处理输入: " .. input)

    -- 检查输入如果长度是1,则不处理
    if #input == 1 then
        logger:info("输入长度为1，不处理")
        return
    end

    -- 检查输入是否包含反引号标签
    if not seg:has_tag("backtick") then
        return
    end
    logger:info("含有backtick标签, 进入反引号translator")
    -- if not input:match("`") then
    --     logger:info("输入不包含反引号，不处理")
    --     return
    -- end
    
    -- 使用text_splitter.split_by_backtick切分输入
    -- 这里输入的input应该不是完整的input,而是剩余的seg当中的input,所以返回的也是这个结果,但是我需要确认前边已经有多少内容被确认了. 
    local segments = text_splitter.split_by_backtick_with_log(input, backtick_delimiter_before, backtick_delimiter_after, logger)
    
    if not segments or #segments == 0 then
        logger:error("切分失败或无结果")
        return
    end
    
    -- 检查第一个片段是否为backtick类型，若是则直接commit_text并返回
    if segments[1].type == "backtick" then
        -- 还要考虑新的可能性: 如果是只有一个反引号开头，如何判断
        -- 如果是单引号开头，然后后面跟着一些字母，或者其他内容，反引号暂时未闭合，如何处理？
        -- 如果是一个完整的反引号包裹的内容，如何处理？
        -- 判断,如果segments中只有一个元素,并且是backtick类型,

        -- 获取segment的基本信息
        local start_pos = seg.start    -- 片段开始位置
        local end_pos = seg._end       -- 片段结束位置  
        local length = seg.length      -- 片段长度
        local status = seg.status      -- 片段状态
        -- 打印信息
        logger:info(string.format("片段信息: start=%d, end=%d, length=%d, status=%s", start_pos, end_pos, length, status))
        -- 打印开始和结束位置
        logger:info(string.format("片段开始位置: %d, 结束位置: %d", segments[1].start, segments[1]._end))
        local cand_temp = Candidate("sentence", seg.start, seg.start + segments[1].length , segments[1].content, "   [英文]")
        yield(cand_temp)

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
            -- 获取第一个候选词进行拼接
            local candidates = get_candidates(segment.content, seg, env, 5)
            
            -- 遍历candidates并打印属性值
            logger:info("获取到 " .. #candidates .. " 个candidates，开始遍历:")
            for index, cand in ipairs(candidates) do
                debug_utils.print_candidate_info(cand, index, logger)
            end
            
            if #candidates > 0 then
                segment_text = candidates[1].text
                segment_preedit = candidates[1].preedit
            else
                segment_text = segment.content
                segment_preedit = segment.content
            end
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


    -- 接下来输出第一段abc部分的候选词内容



end

function script_backtick_translator.fini(env)
    env.notifier:disconnect()
    logger:info("脚本反引号翻译器结束运行")
end

return script_backtick_translator
