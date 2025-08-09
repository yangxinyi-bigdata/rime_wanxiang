-- AI对话分词器
-- 将 a:nihk 分割为两个段落：
-- 1. a: -> ai_talk 标签
-- 2. nihk -> abc 标签（正常拼音处理）
local logger_module = require("logger")
local debug_utils = require("debug_utils")

local logger = logger_module.create("ai_assistant_segmentor", {
    enabled = true,
    unique_file_log = false,
    log_level = "DEBUG"
})

-- 初始化时清空日志文件
logger.clear()

-- 模块级配置缓存
local ai_assistant_segmentor = {}
ai_assistant_segmentor.enabled = false
ai_assistant_segmentor.behavior = {}
ai_assistant_segmentor.chat_triggers = {}
ai_assistant_segmentor.reply_messages_preedits = {}
ai_assistant_segmentor.reply_tags = {}
ai_assistant_segmentor.chat_names = {}
ai_assistant_segmentor.clean_prefix_to_trigger = {}
-- 新增：回复输入快速查表（如 "<trigger>_reply:" -> "<trigger>"）
ai_assistant_segmentor.reply_inputs_to_trigger = {}
-- 新增：chat_triggers 的反向查表（如 "a:" -> "gpt"）
ai_assistant_segmentor.chat_triggers_reverse = {}

-- 读取配置的辅助函数，从config中读取并缓存到模块级变量
-- 读取配置的辅助函数，从config中读取并缓存到模块级变量
function ai_assistant_segmentor.update_current_config(config)
    logger.info("开始更新ai_assistant_segmentor模块配置")

    -- 读取 enabled 配置
    local enabled = config:get_bool("ai_assistant/enabled")
    ai_assistant_segmentor.enabled = enabled or false
    logger.info("AI助手启用状态: " .. tostring(ai_assistant_segmentor.enabled))

    -- 读取 behavior 配置
    ai_assistant_segmentor.behavior = {}
    ai_assistant_segmentor.behavior.commit_question = config:get_bool("ai_assistant/behavior/commit_question") or false
    ai_assistant_segmentor.behavior.auto_commit_reply = config:get_bool("ai_assistant/behavior/auto_commit_reply") or
                                                            false
    ai_assistant_segmentor.behavior.clipboard_mode = config:get_bool("ai_assistant/behavior/clipboard_mode") or false
    ai_assistant_segmentor.behavior.prompt_chat = config:get_string("ai_assistant/behavior/prompt_chat")

    logger.info("行为配置 - commit_question: " .. tostring(ai_assistant_segmentor.behavior.commit_question))
    logger.info("行为配置 - auto_commit_reply: " .. tostring(ai_assistant_segmentor.behavior.auto_commit_reply))
    logger.info("行为配置 - clipboard_mode: " .. tostring(ai_assistant_segmentor.behavior.clipboard_mode))
    logger.info("行为配置 - prompt_chat: " .. tostring(ai_assistant_segmentor.behavior.prompt_chat))

    -- 重新初始化所有配置表
    ai_assistant_segmentor.chat_triggers = {}
    ai_assistant_segmentor.reply_messages_preedits = {}
    ai_assistant_segmentor.reply_tags = {}
    ai_assistant_segmentor.chat_names = {}
    ai_assistant_segmentor.clean_prefix_to_trigger = {}
    -- 新增：重置回复输入查表
    ai_assistant_segmentor.reply_inputs_to_trigger = {}
    -- 新增：重置触发器反向查表
    ai_assistant_segmentor.chat_triggers_reverse = {}

    -- 获取 chat_triggers 配置项
    local chat_triggers_config = config:get_map("ai_assistant/chat_triggers")
    if chat_triggers_config then
        -- 获取所有键名
        local trigger_keys = chat_triggers_config:keys()
        logger.info("找到 " .. #trigger_keys .. " 个触发器配置")

        -- 遍历配置中的所有触发器
        for _, trigger_name in ipairs(trigger_keys) do
            local trigger_value = config:get_string("ai_assistant/chat_triggers/" .. trigger_name)
            local reply_messages_preedit = config:get_string("ai_assistant/reply_messages_preedits/" .. trigger_name)
            local chat_name = config:get_string("ai_assistant/chat_names/" .. trigger_name)

            if trigger_value then
                ai_assistant_segmentor.chat_triggers[trigger_name] = trigger_value
                logger.info("聊天触发器 - " .. trigger_name .. ": " .. trigger_value)

                -- 新增：建立反向映射，便于 O(1) 查找
                ai_assistant_segmentor.chat_triggers_reverse[trigger_value] = trigger_name
                logger.debug("触发器反向映射 - " .. trigger_value .. " -> " .. trigger_name)

                -- 预处理：去掉冒号并保存映射
                local clean_prefix = trigger_value:gsub(":$", "")
                ai_assistant_segmentor.clean_prefix_to_trigger[clean_prefix] = {
                    trigger_name = trigger_name,
                    trigger_prefix = trigger_value,
                    chat_name = chat_name
                }
                logger.info("预处理触发器前缀 - " .. clean_prefix .. " -> " .. trigger_name)
            end

            if reply_messages_preedit then
                ai_assistant_segmentor.reply_messages_preedits[trigger_name] = reply_messages_preedit
                logger.info("回复消息 - " .. trigger_name .. ": " .. reply_messages_preedit)
                -- 同步构建：将 key 增加 "_reply:" 后作为输入快速查找表
                local reply_input_key = trigger_name .. "_reply:"
                ai_assistant_segmentor.reply_inputs_to_trigger[reply_input_key] = trigger_name
                logger.info("回复输入映射 - " .. reply_input_key .. " -> " .. trigger_name)
            end

            if chat_name then
                ai_assistant_segmentor.chat_names[trigger_name] = chat_name
                logger.info("聊天名称 - " .. trigger_name .. ": " .. chat_name)
            end

        end
    else
        logger.warn("未找到 chat_triggers 配置")
    end

    logger.info("ai_assistant_segmentor模块配置更新完成")
end

function ai_assistant_segmentor.init(env)
    logger.info("AI对话分词器初始化完成")

    -- 配置更新由 cloud_input_processor 统一管理，无需在此处调用
    local config = env.engine.schema.config
    logger.info("等待 cloud_input_processor 统一更新配置")
end

function ai_assistant_segmentor.func(segmentation, env)
    local context = env.engine.context
    local input = context.input

    -- 检查AI助手是否启用
    if not ai_assistant_segmentor.enabled then
        return true -- AI助手未启用，不处理
    end

    local segmentation_input = segmentation.input
    local confirmed_pos = segmentation:get_confirmed_position()
    local current_start = segmentation:get_current_start_position()
    local current_end = segmentation:get_current_end_position()

    logger.info("segmentation_input: " .. segmentation_input)
    local current_start_input = segmentation_input:sub(current_start + 1)
    logger.info("current_start_input: " .. current_start_input)

    -- 清空前面的分词,从这里开始进行分词

    if confirmed_pos ~= 0 or current_start ~= 0 then
        -- 如果不是从头开始是分段处理,而是已经进行过一切选词了,则不再进本脚本的分词处理
        return true
    end

    -- 检查是否是AI回复消息（使用新的回复输入格式）
    logger.debug("检测AI回复输入: " .. segmentation_input)
    -- O(1) 直接查表，不再遍历
    local reply_trigger = ai_assistant_segmentor.reply_inputs_to_trigger[segmentation_input]
    if reply_trigger then
        logger.debug("检测到AI回复输入: " .. segmentation_input .. " (触发器: " .. reply_trigger .. ")")
        local ai_reply_segment = Segment(0, #input)
        ai_reply_segment.tags = Set {reply_trigger .. "_reply", "ai_reply"}
        segmentation:pop_back()
        segmentation:add_segment(ai_reply_segment)
        logger.info("创建AI回复段落，标签: " .. reply_trigger .. "_reply")
        return false -- 处理完成, 其他所有分词器不再处理
    end

    -- 检查是否是提示触发符号, 例如"a"
    local prompt_chat = ai_assistant_segmentor.behavior.prompt_chat
    if segmentation_input == prompt_chat then
        logger.debug("segmentation_input == prompt: " .. segmentation_input)
        -- 收集所有以 prompt_chat 字母开头的触发器
        -- 创建提示段落
        local prompt_segment = Segment(0, #prompt_chat)
        prompt_segment.tags = Set {"ai_prompt", "abc"}

        segmentation:reset_length(0)
        -- segmentation:pop_back()
        segmentation:add_segment(prompt_segment)

        return false
    end

    -- 检查是否匹配任何AI触发器
    local matched_trigger = nil
    local matched_prefix = nil

    -- 使用反向查表，O(1) 判定是否为纯触发器输入
    local trigger_name = ai_assistant_segmentor.chat_triggers_reverse[segmentation_input]
    if trigger_name then
        local trigger_prefix = ai_assistant_segmentor.chat_triggers[trigger_name]
        local ai_segment = Segment(0, #trigger_prefix)
        ai_segment.tags = Set {trigger_name, "ai_talk"}
        logger.debug(trigger_name .. " 触发器匹配, 添加标签: " .. trigger_name)

        -- 设置当前AI上下文
        context:set_property("current_ai_context", trigger_name)
        logger.info("设置AI上下文: " .. trigger_name)

        if segmentation.size > 0 then
            segmentation:pop_back()
        end
        
        segmentation:add_segment(ai_segment)
        

        logger.info("循环内部")
        debug_utils.print_segmentation_info(segmentation, logger)
        
    end

    -- 判断第一段是不是"ai_talk", 如果只有一段"ai_talk", 则应该向前推进
    local success, error_msg = pcall(function()
        local first_segment = segmentation:get_at(0)
        if segmentation.size == 1 and first_segment and first_segment:has_tag("ai_talk") then
            segmentation:forward()
            logger.debug("AI话题段落已向前推进")
        end
    end)
    
    if not success then
        logger.error("处理AI话题段落时发生错误: " .. tostring(error_msg))
    end
    
    debug_utils.print_segmentation_info(segmentation, logger)
    return true -- 不能false啊,应该继续让后面的分词器继续处理呢!
end

function ai_assistant_segmentor.fini(env)
    logger.info("AI对话分词器结束运行")

end

return ai_assistant_segmentor
