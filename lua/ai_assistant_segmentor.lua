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

-- 配置缓存机制
local config_cache = {}
local last_schema_id = nil

-- 读取配置的辅助函数
local function load_ai_config(env)
    local schema = env.engine.schema
    local config = schema.config
    local schema_id = schema.schema_id

    -- 如果schema没有变化且已有缓存，直接使用缓存
    if last_schema_id == schema_id and config_cache.ai_assistant_config then
        logger.info("使用缓存的AI助手配置 (schema: " .. schema_id .. ")")
        return config_cache.ai_assistant_config
    end

    logger.info("重新加载AI助手配置 (schema: " .. schema_id .. ")")

    -- 读取 ai_assistant 配置
    local ai_assistant_config = {}

    -- 读取 enabled 配置
    local enabled = config:get_bool("ai_assistant/enabled")
    ai_assistant_config.enabled = enabled or false
    logger.info("AI助手启用状态: " .. tostring(ai_assistant_config.enabled))

    -- 读取 behavior 配置
    ai_assistant_config.behavior = {}
    ai_assistant_config.behavior.commit_question = config:get_bool("ai_assistant/behavior/commit_question") or false
    ai_assistant_config.behavior.auto_commit = config:get_bool("ai_assistant/behavior/auto_commit") or false
    ai_assistant_config.behavior.clipboard_mode = config:get_bool("ai_assistant/behavior/clipboard_mode") or false
    ai_assistant_config.behavior.prompt_chat = config:get_string("ai_assistant/behavior/prompt_chat")

    logger.info("行为配置 - commit_question: " .. tostring(ai_assistant_config.behavior.commit_question))
    logger.info("行为配置 - auto_commit: " .. tostring(ai_assistant_config.behavior.auto_commit))
    logger.info("行为配置 - clipboard_mode: " .. tostring(ai_assistant_config.behavior.clipboard_mode))
    logger.info("行为配置 - prompt_chat: " .. tostring(ai_assistant_config.behavior.prompt_chat))

    -- 动态读取 chat_triggers 配置
    ai_assistant_config.chat_triggers = {}
    ai_assistant_config.reply_messages_preedits = {}
    ai_assistant_config.reply_tags = {}
    ai_assistant_config.chat_names = {}
    ai_assistant_config.clean_prefix_to_trigger = {} -- 去掉冒号的前缀到触发器的映射

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
                ai_assistant_config.chat_triggers[trigger_name] = trigger_value
                logger.info("聊天触发器 - " .. trigger_name .. ": " .. trigger_value)

                -- 预处理：去掉冒号并保存映射
                local clean_prefix = trigger_value:gsub(":$", "")
                ai_assistant_config.clean_prefix_to_trigger[clean_prefix] = {
                    trigger_name = trigger_name,
                    trigger_prefix = trigger_value,
                    chat_name = chat_name
                }
                logger.info("预处理触发器前缀 - " .. clean_prefix .. " -> " .. trigger_name)
            end

            if reply_messages_preedit then
                ai_assistant_config.reply_messages_preedits[trigger_name] = reply_messages_preedit
                logger.info("回复消息 - " .. trigger_name .. ": " .. reply_messages_preedit)
            end

            if chat_name then
                ai_assistant_config.chat_names[trigger_name] = chat_name
                logger.info("聊天名称 - " .. trigger_name .. ": " .. chat_name)
            end

            -- 动态生成回复标签（触发器名称 + "_reply"）
            local reply_tag = trigger_name .. "_reply"
            ai_assistant_config.reply_tags[trigger_name] = reply_tag
            logger.info("动态生成回复标签 - " .. trigger_name .. ": " .. reply_tag)
        end
    else
        logger.warning("未找到 chat_triggers 配置")
    end

    -- 创建回复消息到触发器的反向映射（使用触发器前缀加 _reply: 后缀）
    ai_assistant_config.reply_input_to_trigger = {}
    for trigger, prefix in pairs(ai_assistant_config.chat_triggers) do
        -- 生成回复输入格式：去掉原前缀的冒号，加上 _reply:
        local reply_input = prefix:gsub(":$", "_reply:")
        ai_assistant_config.reply_input_to_trigger[reply_input] = trigger
        logger.info("设置AI回复输入映射: " .. reply_input .. " -> " .. trigger)
    end

    -- 缓存配置
    config_cache.ai_assistant_config = ai_assistant_config
    last_schema_id = schema_id

    return ai_assistant_config
end

local segmentor = {}

function segmentor.init(env)
    logger.clear()
    logger.info("AI对话分词器初始化完成")

    -- 使用配置加载函数
    env.ai_assistant_config = load_ai_config(env)
end

function segmentor.func(segmentation, env)
    local context = env.engine.context
    local input = context.input

    -- 检查AI助手是否启用
    if not env.ai_assistant_config or not env.ai_assistant_config.enabled then
        return true -- AI助手未启用，不处理
    end

    local confirmed_pos = segmentation:get_confirmed_position()
    local segmentation_input = segmentation.input

    if confirmed_pos ~= 0 then
        -- 如果不是从头开始是分段处理,而是已经进行过一切选词了,则不再进本脚本的分词处理
        return true
    end

    -- 检查是否是AI回复消息（使用新的回复输入格式）
    if env.ai_assistant_config.reply_input_to_trigger then
        for reply_input, trigger_name in pairs(env.ai_assistant_config.reply_input_to_trigger) do
            if segmentation_input == reply_input then
                logger.debug("检测到AI回复输入: " .. reply_input .. " (触发器: " .. trigger_name .. ")")
                debug_utils.print_segmentation_info(segmentation, logger)

                local ai_reply_segment = Segment(0, #input)
                local reply_tag = trigger_name .. "_reply" -- 动态生成回复标签
                ai_reply_segment.tags = Set {reply_tag, "ai_reply"}

                segmentation:reset_length(0)
                segmentation:add_segment(ai_reply_segment)
                logger.info("创建AI回复段落，标签: " .. reply_tag)
                return false -- 处理完成
            end
        end
    end

    -- 检查是否匹配任何AI触发器
    local matched_trigger = nil
    local matched_prefix = nil

    if env.ai_assistant_config.chat_triggers then

        -- 
        -- local confirmed_pos_input = segmentation.input:sub(confirmed_pos + 1)
        -- logger.info("confirmed_pos_input: " .. confirmed_pos_input)

        -- 检查是否是提示触发符号, 例如"a"
        local prompt_chat = env.ai_assistant_config.behavior.prompt_chat
        if segmentation_input == prompt_chat then
            logger.debug("segmentation_input == prompt: " .. segmentation_input)
            -- 收集所有以 prompt_chat 字母开头的触发器
            -- 创建提示段落
            local prompt_segment = Segment(0, #segmentation_input)
            prompt_segment.tags = Set {"ai_prompt", "abc"}

            segmentation:reset_length(0)
            segmentation:add_segment(prompt_segment)

            return true
        end
        -- if input == prompt_chat then
        --     logger.debug("input == prompt: " .. input)
        --     -- 收集所有以 prompt_chat 字母开头的触发器
        --     local prompt_triggers = {}
        --     for trigger_name, trigger_prefix in pairs(env.ai_assistant_config.chat_triggers) do
        --         if trigger_prefix:sub(1, 1) == prompt_chat then
        --             -- 检查触发器前缀是否以 prompt_chat 开头
        --             local chat_name = env.ai_assistant_config.chat_names[trigger_name]
        --             logger.debug("chat_name: " .. chat_name)
        --             -- 移除触发器前缀末尾的冒号
        --             -- local clean_prefix = trigger_prefix:gsub(":$", "")
        --             -- logger.debug("clean_prefix: " .. clean_prefix)
        --             local chat_name_clear = chat_name:gsub(":$", "")
        --             table.insert(prompt_triggers, trigger_prefix .. chat_name_clear)
        --         end
        --     end

        --     if #prompt_triggers > 0 then
        --         logger.debug("#prompt_triggers > 0")
        --         -- 排序并合并成提示字符串
        --         table.sort(prompt_triggers)
        --         local prompt_text = table.concat(prompt_triggers, " ")
        --         logger.debug("prompt_text: " .. prompt_text)

        --         -- 创建提示段落
        --         local prompt_segment = Segment(0, #input)
        --         prompt_segment.tags = Set {"ai_prompt", "abc"}
        --         prompt_segment.prompt = " " .. prompt_text

        --         segmentation:reset_length(0)
        --         segmentation:add_segment(prompt_segment)
        --         logger.info("创建AI提示段落: " .. prompt_text)

        --         return true
        --     end

        --     -- 检查是否是单个触发器前缀（去掉冒号），例如"ar"对应"ar:"
        -- elseif env.ai_assistant_config.clean_prefix_to_trigger[input] then
        --     local trigger_info = env.ai_assistant_config.clean_prefix_to_trigger[input]
        --     logger.debug("匹配到单个触发器前缀: " .. input .. " -> " .. trigger_info.trigger_prefix)

        --     if trigger_info.chat_name then
        --         local chat_name_clear = trigger_info.chat_name:gsub(":$", "")
        --         local single_prompt_text = trigger_info.trigger_prefix .. chat_name_clear

        --         -- 创建单个触发器提示段落
        --         local single_prompt_segment = Segment(0, #input)
        --         single_prompt_segment.tags = Set {"abc"}
        --         single_prompt_segment.prompt = " " .. single_prompt_text

        --         segmentation:reset_length(0)
        --         segmentation:add_segment(single_prompt_segment)
        --         logger.info("创建单个触发器AI提示段落: " .. single_prompt_text)

        --         return true
        --     end
        -- end

        for trigger_name, trigger_prefix in pairs(env.ai_assistant_config.chat_triggers) do
            -- debug_utils.print_segmentation_info(segmentation, logger)
            -- 处理纯触发器（没有后续字符）
            if segmentation_input == trigger_prefix then
                local ai_segment = Segment(0, #trigger_prefix)
                ai_segment.tags = Set {trigger_name, "ai_talk"} -- 使用触发器名称作为标签
                logger.debug(trigger_name .. " 触发器匹配, 添加标签: " .. trigger_name)

                -- 设置当前AI上下文
                context:set_property("current_ai_context", trigger_name)
                context:set_property("ai_input_history", input)
                logger.info("设置AI上下文: " .. trigger_name)

                segmentation:reset_length(0)
                segmentation:add_segment(ai_segment)
                return false
                -- 处理带内容的触发器,所以这里不应该是直接使用input,而是应该去掉已经确认的部分,而且是光标左侧的部分,也就是实际生效中的input段
            elseif segmentation_input:match("^" .. trigger_prefix:gsub("[%(%)%.%+%-%*%?%[%]%^%$%%]", "%%%1") .. ".") then
                matched_trigger = trigger_name
                matched_prefix = trigger_prefix
                break
            end
        end
    end

    -- 如果没有匹配到任何触发器，不处理
    if not matched_trigger then
        return true
    end

    logger.info("检测到AI对话输入（" .. matched_trigger .. "），开始分词: " .. segmentation_input)

    -- 设置当前AI上下文
    context:set_property("current_ai_context", matched_trigger)
    context:set_property("ai_input_history", segmentation_input)
    logger.info("设置AI上下文: " .. matched_trigger)

    -- 分割输入
    local prefix_len = #matched_prefix
    local pinyin_part = segmentation_input:sub(prefix_len + 1) -- 去掉触发器前缀的部分

    -- 清空原有的分割结果
    segmentation:reset_length(0)
    logger.info("清空原有分割结果")

    -- 创建 AI 前缀段落
    local ai_segment = Segment(0, prefix_len)
    ai_segment.tags = Set {matched_trigger, "ai_talk"} -- 使用触发器名称作为标签
    segmentation:add_segment(ai_segment)
    logger.info("创建AI前缀段落: " .. matched_prefix .. " (0-" .. prefix_len .. ") 触发器类型: " ..
                    matched_trigger)

    -- 如果有拼音部分，创建拼音段落
    if #pinyin_part > 0 then
        segmentation:forward()
        local pinyin_segment = Segment(prefix_len, #segmentation_input)
        pinyin_segment.tags = Set {"abc"} -- 使用 abc 标签，让 script_translator 处理
        segmentation:add_segment(pinyin_segment)
        logger.info("创建拼音段落: " .. pinyin_part .. " (" .. prefix_len .. "-" .. #input .. ")")
    end

    return true -- 不能false啊,应该继续让后面的分词器继续处理呢!
end

function segmentor.fini(env)
    logger.info("AI对话分词器结束运行")

end

return segmentor
