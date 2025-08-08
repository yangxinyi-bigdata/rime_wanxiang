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

    local confirmed_pos = segmentation:get_confirmed_position()
    local segmentation_input = segmentation.input
    -- 清空前面的分词,从这里开始进行分词
    segmentation:reset_length(0)

    if confirmed_pos ~= 0 then
        -- 如果不是从头开始是分段处理,而是已经进行过一切选词了,则不再进本脚本的分词处理
        return true
    end

    -- 检查是否是AI回复消息（使用新的回复输入格式）
    logger.debug("检测AI回复输入: " .. segmentation_input)
    for trigger_name, reply_prefix in pairs(ai_assistant_segmentor.reply_messages_preedits) do
        if trigger_name .. "_reply:" == segmentation_input then
            logger.debug("检测到AI回复输入: " .. segmentation_input .. " (触发器: " .. trigger_name .. ")")
            local ai_reply_segment = Segment(0, #input)
            ai_reply_segment.tags = Set {trigger_name .. "_reply", "ai_reply"}
            segmentation:reset_length(0)
            segmentation:add_segment(ai_reply_segment)
            logger.info("创建AI回复段落，标签: " .. trigger_name .. "_reply")
            return false -- 处理完成
        end
    end

    -- 检查是否是提示触发符号, 例如"a"
    local prompt_chat = ai_assistant_segmentor.behavior.prompt_chat
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

    -- 检查是否匹配任何AI触发器
    local matched_trigger = nil
    local matched_prefix = nil

    -- logger.info("循环外部")
    -- debug_utils.print_segmentation_info(segmentation, logger)
    for trigger_name, trigger_prefix in pairs(ai_assistant_segmentor.chat_triggers) do
        -- debug_utils.print_segmentation_info(segmentation, logger)
        -- 处理纯触发器（没有后续字符）
        -- if segmentation_input:match("^" .. trigger_prefix:gsub("[%(%)%.%+%-%*%?%[%]%^%$%%]", "%%%1") .. ".") then
        if segmentation_input:match("^" .. trigger_prefix:gsub("[%(%)%.%+%-%*%?%[%]%^%$%%]", "%%%1")) then
            local ai_segment = Segment(0, #trigger_prefix)
            ai_segment.tags = Set {trigger_name, "ai_talk"} -- 使用触发器名称作为标签
            logger.debug(trigger_name .. " 触发器匹配, 添加标签: " .. trigger_name)

            -- 设置当前AI上下文
            context:set_property("current_ai_context", trigger_name)
            logger.info("设置AI上下文: " .. trigger_name)

            -- segmentation:reset_length(0)
            segmentation:add_segment(ai_segment)
            segmentation:forward()

            logger.info("循环内部")
            debug_utils.print_segmentation_info(segmentation, logger)
            return true
        -- 处理带内容的触发器,所以这里不应该是直接使用input,而是应该去掉已经确认的部分,而且是光标左侧的部分,也就是实际生效中的input段
        -- elseif segmentation_input:match("^" .. trigger_prefix:gsub("[%(%)%.%+%-%*%?%[%]%^%$%%]", "%%%1") .. ".") then
        --     matched_trigger = trigger_name
        --     matched_prefix = trigger_prefix
        --     break
        end
    end

    -- 如果没有匹配到任何触发器，不处理
    if not matched_trigger then
        return true
    end


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

function ai_assistant_segmentor.fini(env)
    logger.info("AI对话分词器结束运行")

end

return ai_assistant_segmentor
