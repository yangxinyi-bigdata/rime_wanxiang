-- 引入日志工具模块
local logger_module = require("logger")
-- 引入文本切分模块
-- local text_splitter = require("text_splitter")
local debug_utils = require("debug_utils")

-- 引入TCP同步模块
local tcp_socket = nil
local tcp_ok, tcp_err = pcall(function()
    tcp_socket = require("tcp_socket_sync")
end)
if not tcp_ok then
    logger.error("加载 tcp_socket_sync 失败: " .. tostring(tcp_err))
end

local logger = logger_module.create("cloud_input_processor", {
    enabled = true,
    unique_file_log = false,
    log_level = "DEBUG"
})

-- 返回值常量定义
local kRejected = 0 -- 表示按键被拒绝
local kAccepted = 1 -- 表示按键已被处理
local kNoop = 2 -- 表示按键未被处理,继续传递给下一个处理器

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

    -- 读取AI助手配置
    local ai_assistant_config = {}
    ai_assistant_config.chat_triggers = {}
    ai_assistant_config.chat_names = {}
    ai_assistant_config.reply_messages_preedit = {}
    ai_assistant_config.prefix_to_reply = {}

    -- 读取 enabled 配置
    local enabled = config:get_bool("ai_assistant/enabled")
    ai_assistant_config.enabled = enabled or false
    logger.info("AI助手启用状态: " .. tostring(ai_assistant_config.enabled))

    -- 读取 behavior 配置
    ai_assistant_config.behavior = {}

    ai_assistant_config.behavior.commit_question = config:get_bool("ai_assistant/behavior/commit_question") or false
    ai_assistant_config.behavior.strip_chat_prefix = config:get_bool("ai_assistant/behavior/strip_chat_prefix") or false
    ai_assistant_config.behavior.auto_commit = config:get_bool("ai_assistant/behavior/auto_commit") or false
    ai_assistant_config.behavior.clipboard_mode = config:get_bool("ai_assistant/behavior/clipboard_mode") or false
    ai_assistant_config.behavior.prompt_chat = config:get_string("ai_assistant/behavior/prompt_chat")

    logger.info("行为配置 - commit_question: " .. tostring(ai_assistant_config.behavior.commit_question))
    logger.info("行为配置 - auto_commit: " .. tostring(ai_assistant_config.behavior.auto_commit))
    logger.info("行为配置 - clipboard_mode: " .. tostring(ai_assistant_config.behavior.clipboard_mode))
    logger.info("行为配置 - prompt_chat: " .. tostring(ai_assistant_config.behavior.prompt_chat))

    -- 动态读取 chat_triggers 配置
    local chat_triggers_config = config:get_map("ai_assistant/chat_triggers")
    if chat_triggers_config then
        -- 获取所有键名
        local trigger_keys = chat_triggers_config:keys()
        logger.info("找到 " .. #trigger_keys .. " 个触发器配置")

        -- 遍历配置中的所有触发器
        for _, trigger_name in ipairs(trigger_keys) do
            local trigger_value = config:get_string("ai_assistant/chat_triggers/" .. trigger_name)
            local reply_message = config:get_string("ai_assistant/reply_messages_preedit/" .. trigger_name)
            local chat_name = config:get_string("ai_assistant/chat_names/" .. trigger_name)

            if trigger_value then
                ai_assistant_config.chat_triggers[trigger_name] = trigger_value
                logger.info("云输入触发器 - " .. trigger_name .. ": " .. trigger_value)
            end

            if chat_name then
                ai_assistant_config.chat_names[trigger_name] = chat_name
                logger.info("聊天名称 - " .. trigger_name .. ": " .. chat_name)
            end

            if reply_message then
                ai_assistant_config.reply_messages_preedit[trigger_name] = reply_message
                logger.info("云输入回复消息 - " .. trigger_name .. ": " .. reply_message)
            end
        end
    else
        logger.warning("未找到 chat_triggers 配置")
    end

    -- 创建触发器前缀到回复消息的映射
    for trigger, prefix in pairs(ai_assistant_config.chat_triggers) do
        local reply_message = ai_assistant_config.reply_messages_preedit[trigger]
        if reply_message then
            ai_assistant_config.prefix_to_reply[prefix] = reply_message
        end
    end

    -- 缓存配置
    config_cache.ai_assistant_config = ai_assistant_config
    last_schema_id = schema_id

    -- 读取菜单配置
    local ok_menu, err_menu = pcall(function()
        ai_assistant_config.page_size = config:get_int("menu/page_size")
        ai_assistant_config.alternative_select_keys = config:get_string("menu/alternative_select_keys")
    end)
    if ok_menu then
        logger.info("page_size: " .. tostring(ai_assistant_config.page_size))
        logger.info("alternative_select_keys: " .. tostring(ai_assistant_config.alternative_select_keys))

        -- 从alternative_select_keys中截取前page_size个字符
        if ai_assistant_config.alternative_select_keys and ai_assistant_config.page_size then
            ai_assistant_config.alternative_select_keys = ai_assistant_config.alternative_select_keys:sub(1,
                ai_assistant_config.page_size)
            logger.info("截取后的alternative_select_keys: " .. tostring(ai_assistant_config.alternative_select_keys))
        end
    else
        logger.error("获取菜单配置失败: " .. tostring(err_menu))
        -- 设置默认值
        ai_assistant_config.page_size = 5
        ai_assistant_config.alternative_select_keys = "123456789"
        -- 截取默认值
        ai_assistant_config.alternative_select_keys = ai_assistant_config.alternative_select_keys:sub(1,
            ai_assistant_config.page_size)
        logger.info("使用默认菜单配置 - page_size: " .. ai_assistant_config.page_size ..
                        ", alternative_select_keys: " .. ai_assistant_config.alternative_select_keys)
    end

    return ai_assistant_config
end

local cloud_input_processor = {}
local delimiter = " " -- 默认分隔符

-- 获取当前AI上下文对应的回复输入格式
local function get_current_ai_reply_input(env, context)
    if not env.ai_assistant_config or not env.ai_assistant_config.chat_triggers then
        return "ai_reply:" -- 默认回复输入
    end

    -- 获取当前AI上下文标记
    local current_ai_context = context:get_property("current_ai_context")
    if current_ai_context and env.ai_assistant_config.chat_triggers[current_ai_context] then
        local trigger_prefix = env.ai_assistant_config.chat_triggers[current_ai_context]
        local reply_input = trigger_prefix:gsub(":$", "_reply:")
        logger.info("使用AI上下文回复输入: " .. current_ai_context .. " -> " .. reply_input)
        return reply_input
    end

    -- 如果没有设置上下文，尝试从输入历史中推断
    local input_history = context:get_property("ai_input_history")
    if input_history and env.ai_assistant_config.chat_triggers then
        for trigger, prefix in pairs(env.ai_assistant_config.chat_triggers) do
            if input_history:match("^" .. prefix:gsub("[%(%)%.%+%-%*%?%[%]%^%$%%]", "%%%1")) then
                local reply_input = prefix:gsub(":$", "_reply:")
                logger.info("从输入历史推断回复输入: " .. prefix .. " -> " .. reply_input)
                return reply_input
            end
        end
    end

    return "ai_reply:" -- 默认回复输入
end

-- 从script_text中提取中文的部分
-- 使用Lua模式匹配一次性提取前面的中文部分
local function extract_leading_chinese(text)
    -- 最高效的方法：反向查找最后一个中文字符的位置
    local last_pos = 0
    local pos = 1

    -- 使用string.find从前往后查找所有中文字符，记录最后一个位置
    while true do
        local start_pos, end_pos = text:find("[\228-\233][\128-\191][\128-\191]", pos)
        if not start_pos then
            break
        end
        last_pos = end_pos
        pos = end_pos + 1
    end

    -- 如果找到中文字符，返回从开头到最后一个中文字符的部分
    if last_pos > 0 then
        return text:sub(1, last_pos)
    end

    -- 如果没有中文字符，返回空字符串
    return ""
end

local function handle_ai_chat_selection(key_repr, chat_trigger, env, last_segment)
    local engine = env.engine
    local context = engine.context
    -- 检查当前按键是否为选词键或空格键
    local is_select_key = false
    local select_key_index = 0

    if key_repr == "space" then
        -- 空格键按照选词键1处理
        is_select_key = true
        select_key_index = 1
        logger.info("检测到空格键，按选词键1处理 (索引: " .. select_key_index .. ")")
    else
        -- 直接查找字符在选词键字符串中的位置
        select_key_index = string.find(env.ai_assistant_config.alternative_select_keys, key_repr, 1, true)
        if select_key_index then
            is_select_key = true
            logger.info("检测到选词键: " .. key_repr .. " (索引: " .. select_key_index .. ")")
        end
    end

    if is_select_key then

        local menu = last_segment.menu
        if last_segment and menu then
            -- 检查menu是否为空以及选词索引是否在有效范围内
            if not menu:empty() and select_key_index <= menu:candidate_count() then
                -- 获取即将上屏的候选词
                local candidate = last_segment:get_candidate_at(select_key_index - 1) -- 0-based索引
                if candidate then

                    -- 检查选词后是否会完成完整输入（上屏）
                    -- 通过检查context状态和segment状态来判断

                    -- 判断是否为最后一个未确认的segment，且选择后会导致上屏
                    local is_last_candidate = (candidate._end == #context.input)
                    if is_last_candidate then
                        logger.info("选词将完成上屏操作，拦截按键并发送AI消息")
                        local candidate_text = candidate.text
                        logger.info("候选词文本: " .. candidate_text)

                        -- 如果是ac:nihk 那么匹配不到中文, 也就是script_text_chinese为空, going_commit_text只有候选词
                        local script_text = context:get_script_text()
                        logger.info("script_text: " .. script_text)

                        local script_text_chinese = extract_leading_chinese(script_text)
                        local going_commit_text = script_text_chinese .. candidate_text
                        logger.info("即将上屏文本: " .. going_commit_text)
                        -- 发送聊天消息到AI服务，使用keepon_chat_trigger作为对话类型

                        local ok, result = pcall(function()

                            -- 读取最新消息（丢弃积压的旧消息，保留最新的有用消息）
                            local flushed_bytes = tcp_socket.flush_ai_socket_buffer()
                            if flushed_bytes and flushed_bytes > 0 then
                                logger.info("清理了积压的AI消息: " .. flushed_bytes .. " 字节")
                            else
                                logger.info("无积压的AI消息需要处理")
                            end

                            -- 清理上次的候选词
                            local current_content = context:get_property("ai_replay_stream")
                            if current_content ~= "" and current_content ~= "等待AI回复..." then
                                context:set_property("ai_replay_stream", "等待AI回复...")
                            end

                            local get_ai_stream = context:get_property("get_ai_stream")
                            if get_ai_stream ~= "true" then
                                logger.debug("设置get_ai_stream属性开关true")
                                context:set_property("get_ai_stream", "true")
                            end

                            if env.ai_assistant_config.behavior.commit_question then
                                tcp_socket.send_chat_message(going_commit_text, chat_trigger) -- 正常输入换行
                                -- 再判断strip_chat_prefix为true或者false,如果为true,则清空并且重新上屏字符串
                                if env.ai_assistant_config.behavior.strip_chat_prefix then

                                    logger.info("context:clear()")
                                    context:clear()
                                    -- logger.info("context:clear() finish")
                                    -- 对上屏文本前边去除掉, 首先要知道最前边的那个是什么, 在chat_names中
                                    logger.info("chat_trigger: " .. chat_trigger)
                                    local chat_trigger_name = env.ai_assistant_config.chat_triggers[chat_trigger]
                                    logger.info("chat_trigger_name: " .. chat_trigger_name)

                                    -- 判断going_commit_text是否以chat_names开头，如果是则删除前缀
                                    local final_commit_text = going_commit_text
                                    if chat_trigger_name and going_commit_text:sub(1, #chat_trigger_name) ==
                                        chat_trigger_name then
                                        final_commit_text = going_commit_text:sub(#chat_trigger_name + 1)
                                        logger.info("删除chat_trigger_name前缀: " .. chat_trigger_name .. " -> " ..
                                                        final_commit_text)
                                    else
                                        logger.info("不需要删除前缀，直接上屏: " .. final_commit_text)
                                    end

                                    engine:commit_text(final_commit_text)
                                    return kAccepted
                                else
                                    -- 正常上屏操作
                                    return kNoop
                                end

                            else
                                -- 发送聊天消息，包含对话类型信息
                                tcp_socket.send_chat_message(going_commit_text, chat_trigger, false)
                                -- 拦截按键, 清空当前context中的内容. 应该根据配置清空控制是否清空,或者正常上屏. 如果上屏则应该发送回车.
                                logger.info("context:clear()")
                                context:clear()
                                return kAccepted
                            end
                        end)

                        if ok then
                            -- 执行成功，返回pcall内部函数的返回值
                            return result
                        else
                            -- 执行失败，记录错误但不拦截按键
                            logger.error("AI对话请求处理出错: " .. tostring(result))
                            return kNoop
                        end
                    end

                else
                    logger.warning("无法获取候选词对象")
                end
            else
                logger.info("菜单为空或选词索引超出范围: " .. select_key_index .. " > " ..
                                (menu:candidate_count() or 0))
            end
        else
            logger.info("没有有效的segment或menu")
        end
    end
end

function cloud_input_processor.init(env)
    -- 获取输入法引擎和上下文   
    local config = env.engine.schema.config
    -- 初始化时清空日志文件
    -- logger.clear()
    logger.info("云输入处理器初始化完成")
    delimiter = config:get_string("speller/delimiter"):sub(1, 1) or " "
    logger.info("当前分隔符: " .. delimiter)

    -- 使用配置加载函数
    env.ai_assistant_config = load_ai_config(env)
    logger.info("AI助手配置加载完成")

    --  fixed 设置一个变量
    -- context:set_property只能设置字符串类型
    env.engine.context:set_property("cloud_convert_flag", "0")
    env.engine.context:set_property("backtick_prompt", "0")
end

local function set_cloud_convert_flag(context)
    -- 这部分代码时检测输入的字符长度，通过检测中间有几个分隔符实现
    -- 检查当前是否正在组词状态（即用户正在输入但还未确认）
    local is_composing = context:is_composing()
    local preedit = context:get_preedit()
    local preedit_text = preedit.text
    -- 这里不需要考虑已经确认的部分,确认的部分不会出现在preedit_text中.
    -- 移除光标符号和后续的prompt内容
    local clean_text = preedit_text:gsub("‸.*$", "") -- 从光标符号开始删除到结尾
    logger.info("当前预编辑文本: " .. clean_text)
    local _, count = string.gsub(clean_text, delimiter, delimiter)
    logger.info("当前输入内容分隔符数量: " .. count)
    -- local has_punct = has_punctuation(input)

    -- 触发状态改成,当数如字符超过4个,或者有标点且超过2个:
    if is_composing and count >= 3 then
        logger.info("当前正在组词状态,检测到分隔符数量达到3,触发云输入提示")
        -- 只在值真正需要改变时才设置
        -- 先获取当前选项的值，避免不必要的更新
        logger.info("当前云输入提示标志: " .. context:get_property("cloud_convert_flag"))

        if context:get_property("cloud_convert_flag") == "0" then
            logger.info("云输入提示标志为 0, 设置为 1")
            context:set_property("cloud_convert_flag", "1")
            -- context:set_option("cloud_convert_prompt", true)
            logger.info("cloud_convert_flag 已设置为 1")

        end

    else
        -- 如果不在组词状态或没有达到触发条件,则重置提示选项
        logger.info("当前不在组词状态或未达到触发条件,云输入提示已重置")
        if context:get_property("cloud_convert_flag") == "1" then
            -- context:set_option("cloud_convert_prompt", false)
            context:set_property("cloud_convert_flag", "0")
            logger.info("cloud_convert_flag 已设置为 0")

        end
    end
end

-- 按键处理器函数
-- 负责监听按键事件,判断是否应该触发翻译器
function cloud_input_processor.func(key, env)
    local engine = env.engine
    local context = engine.context
    local segmentation = context.composition:toSegmentation()
    local input = context.input
    local key_repr = key:repr()
    logger.info("测试虚拟按键: " .. key_repr)

    if key_repr == "Release+Control_L" then
        logger.info("拦截所有Release+Control_L按键")
        return kAccepted
    end

    if context:get_property("get_ai_stream") == "true" then

        if key_repr == "Control+F11" then
            logger.info("get_ai_stream==true, 触发重新刷新候选词: ")
            if context.input == "" then
                local reply_input = get_current_ai_reply_input(env, context)
                context.input = reply_input
                logger.info("设置AI回复输入: " .. reply_input)
            end
            context:refresh_non_confirmed_composition()
            return kAccepted
        end

    elseif context:get_property("get_cloud_stream") == "true" then

        if key_repr == "Control+F11" then
            logger.info("get_cloud_stream==true, 触发重新刷新云输入候选词: ")
            context:refresh_non_confirmed_composition()
            return kAccepted
        end

    else
        if key_repr == "Control+F11" then
            logger.info("get_ai_stream==false && get_cloud_stream==false, 依然拦截输入Control+F11: ")
            return kAccepted
        end
    end

    local is_composing = context:is_composing()
    if not key or not context:is_composing() then
        return kNoop
    end

    -- AI回复上屏处理分支
    if context:get_property("intercept_select_key") == "1" then

        if key_repr == "space" or key_repr == "1" then
            logger.debug("进入分支 get_property intercept_select_key: 1")

            -- 判断是不是直接一个段落, 内容中是否存在换行符.
            local commit_text = context:get_commit_text()
            logger.info("commit_text: " .. commit_text)
            if commit_text and commit_text:find("\n") then
                logger.info("commit_text 中存在换行符")
                -- 拦截按键, 清空当前context中的内容.
                logger.info("context:clear()")
                context:clear()

                -- 使用TCP通信发送粘贴命令到Python服务端（跨平台通用）
                if tcp_socket then
                    logger.info("🍴 通过TCP发送粘贴命令到Python服务端 (intercept模式)")
                    local paste_success = tcp_socket.send_paste_command()
                    if paste_success then
                        logger.info("✅ 粘贴命令发送成功 (intercept模式)")
                    else
                        logger.error("❌ 粘贴命令发送失败 (intercept模式)")
                    end
                else
                    logger.warn("⚠️ TCP模块未加载，无法发送粘贴命令 (intercept模式)")
                end

                logger.debug("set_property intercept_select_key: 0")
                context:set_property("intercept_select_key", "0")
                return kAccepted
            else
                logger.info("commit_text 中不存在换行符")
                logger.debug("set_property intercept_select_key: 0")
                context:set_property("intercept_select_key", "0")
                return kNoop
            end

        end

    end

    -- 如果是ai_talk标签的segment, 则需要判断是不是将要上屏, 如果要上屏,则进行拦截后处理
    local last_segment = segmentation:back()
    local first_segment = segmentation:get_at(0)
    if first_segment:has_tag("ai_talk") then
        logger.info("first_segment.tags: ai_talk")
        -- for element, _ in pairs(first_segment.tags) do
        --     logger.info("first_segment.tags: " .. element)
        -- end
        local tag = first_segment.tags - Set {"ai_talk"}
        -- 遍历Set，由于只有一个元素，第一次循环就会得到结果
        local tag_chat_trigger
        for element, _ in pairs(tag) do
            tag_chat_trigger = element
            logger.info("tag_chat_trigger: " .. tag_chat_trigger)
            break
        end

        -- 处理AI会话是否要进行传输等操作
        local result = handle_ai_chat_selection(key_repr, tag_chat_trigger, env, last_segment)
        if result then
            return result
        end

    end

    -- 开始判断连续ai对话分支内容
    -- context:set_property("keepon_chat_trigger", "translate_ai_chat")
    local keepon_chat_trigger = context:get_property('keepon_chat_trigger')
    logger.info("keepon_chat_trigger: " .. keepon_chat_trigger)
    -- 属性存在值代表要进入自动ai对话模式
    if keepon_chat_trigger ~= "" then
        logger.info("keepon_chat_trigger: " .. keepon_chat_trigger)

        -- 应该有豁免,对于两种情况是豁免发送的,1. AI:对话消息,2:AI回复消息
        -- segment.tags 是一个Set，遍历输出其中的内容
        -- local tags_str = ""
        -- if first_segment.tags and type(first_segment.tags) == "table" then
        --     for tag, _ in pairs(first_segment.tags) do
        --         tags_str = tags_str .. tostring(tag) .. " "
        --     end
        -- end
        -- logger.info("first_segment.tags: " .. tags_str)
        if first_segment:has_tag("ai_talk") or first_segment:has_tag("ai_reply") then
            logger.info("first_segment.tags: ai_talk or ai_reply")
            return kNoop
        end

        -- 处理AI会话是否要进行传输等操作
        local result = handle_ai_chat_selection(key_repr, keepon_chat_trigger, env, last_segment)
        if result then
            return result
        end



    end

    -- 使用 pcall 捕获所有可能的错误
    local success, result = pcall(function()

        if #input <= 1 then
            logger.info("input为1, 不判断直接退出")
            return kNoop
        end

        local segmentation = context.composition:toSegmentation()

        -- 读取配置中的常规输入字符内容
        -- local config = engine.schema.config
        -- local regular_input = config:get_string("speller/alphabet")

        -- 检查按键是否有效
        if not key then
            error("按键对象为空")
        end

        -- 如果输入的按键是一个反引号,则判断这个反引号是不是一个和前边的反引号配对的闭合单引号
        -- 如果是则直接将当前第一个候选项上屏.
        logger.info("")
        logger.info("=== 开始分析lua/cloud_input_processor.lua ===")
        logger.info("当前按键: " .. key_repr)
        logger.info("当前input: " .. input)

        logger.info("context:get_property:backtick_prompt " .. context:get_property("backtick_prompt"))

        -- 首先打印seg的信息
        -- 使用debug_utils打印Segmentation信息
        -- debug_utils.print_segmentation_info(segmentation, logger)

        -- 最后输入的这个按键还没有来得及进入input中,所以不包含最后一个按键
        -- 这里应该做什么来着？如果直接上屏就会导致没有内容了,直接结束输入.
        -- 首先查看segment,和候选项
        -- 对input切片出当前剩余的部分 `haha`woke
        local current_start = segmentation:get_current_start_position()
        local current_end = segmentation:get_current_end_position()
        local segmente_input = input:sub(current_start + 1, current_end)
        logger.info("segmente_input: " .. segmente_input)
        -- 已经上屏的部分也会被影响吗?  这里的input是所有的,包含已经上屏确认的部分,应该提取出剩余的
        -- 这个有没有可能通过标签处理，当前便有反引号片段,是不是应该已经打了标签? 但标签不能判断是以反引号开通的, 除非是那个切割函数
        if #segmente_input >= 3 and segmente_input:sub(1, 1) == "`" and segmente_input:sub(-2, -2) == "`" then
            if context:confirm_current_selection() then
                logger.info("确认当前选择成功")
            else
                logger.error("确认当前选择失败")
            end
        end

        -- 这里segmentation.input获取到的应该是上一轮结束之后, 当前的segmentation.input
        -- 
        -- local segmentation_input = segmentation.input
        -- logger.info("segmentation_input: " .. segmentation_input)
        -- 检查反引号的数量是否为奇数(说明有未闭合的反引号)

        -- 如果当前输入的就是反引号,会有一个延迟,单独判断一下.
        -- 如果输入的是反引号,那么segmente_input是前边的内容, 
        -- 这就有两种情况, 一种是 wo` 一种是wo`ok`
        -- 如果是前边的情况, segmente_input为 input, 后面的情况 segmente_input为 wo`ok

        if key_repr == "grave" then
            -- segmente_input 后面追加一个反引号字符
            segmente_input = segmente_input .. "`"
            logger.info("检测到反引号输入，segmente_input 更新为: " .. segmente_input)
        elseif key_repr == "BackSpace" then
            -- 删除按键之后,如果删除掉的是一个反引号,也应该马上触发
            segmente_input = segmente_input:sub(1, -2)
        end
        local _, backtick_count = segmente_input:gsub("`", "")
        if backtick_count % 2 == 1 then
            logger.info(
                "检测到奇数个反引号,存在未闭合情况: " .. segmente_input .. " (反引号数量: " ..
                    backtick_count .. ")")
            -- 只在值真正需要改变时才设置
            -- 先获取当前选项的值，避免不必要的更新
            logger.info("当前云输入提示标志: " .. context:get_property("backtick_prompt"))

            if context:get_property("backtick_prompt") == "0" then
                logger.info("backtick_prompt提示标志为 0, 设置为 1")
                context:set_property("backtick_prompt", "1")
                logger.info("backtick_prompt 已设置为 1")
            end

            if key_repr:match("^Release%+") then
                logger.info("反引号状态下跳过按键事件: " .. key_repr)
                return kAccepted
            end

            -- 定义需要转换为普通字符的按键
            local handle_keys = {
                ["space"] = " ", -- 空格转为空格字符
                -- 数字键
                ["1"] = "1",
                ["2"] = "2",
                ["3"] = "3",
                ["4"] = "4",
                ["5"] = "5",
                ["6"] = "6",
                ["7"] = "7",
                ["8"] = "8",
                ["9"] = "9",
                ["0"] = "0",
                -- 数字键的Shift版本（符号）
                ["Shift+1"] = "!", -- !
                ["Shift+2"] = "@", -- @
                ["Shift+3"] = "#", -- #
                ["Shift+4"] = "$", -- $
                ["Shift+5"] = "%", -- %
                ["Shift+6"] = "^", -- ^
                ["Shift+7"] = "&", -- &
                ["Shift+8"] = "*", -- *
                ["Shift+9"] = "(", -- (
                ["Shift+0"] = ")", -- )

                -- 标点符号（不需要Shift）
                ["period"] = ".", -- 句号
                ["comma"] = ",", -- 逗号
                ["semicolon"] = ";", -- 分号
                ["apostrophe"] = "'", -- 单引号/撇号
                ["bracketleft"] = "[", -- 左方括号
                ["bracketright"] = "]", -- 右方括号
                ["hyphen"] = "-", -- 连字符
                ["equal"] = "=", -- 等号
                ["slash"] = "/", -- 斜杠
                ["backslash"] = "\\", -- 反斜杠
                ["grave"] = "`", -- 反引号

                -- 标点符号的Shift版本
                ["Shift+semicolon"] = ":", -- :
                ["Shift+apostrophe"] = "\"", -- "
                ["Shift+bracketleft"] = "{", -- {
                ["Shift+bracketright"] = "}", -- }
                ["Shift+hyphen"] = "_", -- _
                ["Shift+equal"] = "+", -- +
                ["Shift+slash"] = "?", -- ?
                ["Shift+backslash"] = "|", -- |
                ["Shift+grave"] = "~", -- ~

                -- 直接映射的符号键
                ["minus"] = "-", -- 冒号
                ["colon"] = ":", -- 冒号
                ["question"] = "?", -- 问号
                ["exclam"] = "!", -- 感叹号
                ["quotedbl"] = "\"", -- 双引号
                ["parenleft"] = "(", -- 左圆括号
                ["parenright"] = ")", -- 右圆括号
                ["braceleft"] = "{", -- 左花括号
                ["braceright"] = "}", -- 右花括号
                ["underscore"] = "_", -- 下划线
                ["plus"] = "+", -- 加号
                ["asterisk"] = "*", -- 星号
                ["at"] = "@", -- @ 符号
                ["numbersign"] = "#", -- # 号
                ["dollar"] = "$", -- 美元符号
                ["percent"] = "%", -- 百分号
                ["ampersand"] = "&", -- & 符号
                ["less"] = "<", -- 小于号
                ["greater"] = ">", -- 大于号
                ["asciitilde"] = "~", -- 波浪号
                ["asciicircum"] = "^", -- 插入符号
                ["bar"] = "|", -- 竖线

                -- 为这些符号键也添加Shift版本（以防万一）
                ["Shift+colon"] = ":",
                ["Shift+question"] = "?",
                ["Shift+exclam"] = "!",
                ["Shift+quotedbl"] = "\"",
                ["Shift+parenleft"] = "(",
                ["Shift+parenright"] = ")",
                ["Shift+braceleft"] = "{",
                ["Shift+braceright"] = "}",
                ["Shift+underscore"] = "_",
                ["Shift+plus"] = "+",
                ["Shift+asterisk"] = "*",
                ["Shift+at"] = "@",
                ["Shift+numbersign"] = "#",
                ["Shift+dollar"] = "$",
                ["Shift+percent"] = "%",
                ["Shift+ampersand"] = "&",
                ["Shift+less"] = "<",
                ["Shift+greater"] = ">",
                ["Shift+asciitilde"] = "~",
                ["Shift+asciicircum"] = "^",
                ["Shift+bar"] = "|"

            }
            logger.info("key_repr: " .. key_repr)
            if handle_keys[key_repr] then
                logger.info("处于反引号状态，将按键转为普通字符: " .. key_repr)

                -- 将按键对应的字符添加到输入中
                local char_to_add = handle_keys[key_repr]
                -- 如果添加英文字母没有影响,但是
                context:push_input(char_to_add)

                -- 返回 kAccepted 表示我们已经处理了这个按键
                return kAccepted
            end

        else
            -- 如果不在组词状态或没有达到触发条件,则重置提示选项
            logger.info("当前不在反引号当中backtick提示已重置")
            if context:get_property("backtick_prompt") == "1" then
                context:set_property("backtick_prompt", "0")
                logger.info("backtick_prompt 已设置为 0")
            end
        end

        logger.info("=== 结束分析lua/cloud_input_processor.lua ===")
        logger.info("")

        -- 设置云输入法表示标
        set_cloud_convert_flag(context)

        -- 检查当前按键是否为预设的触发键
        if key:repr() == "Return" and context:get_property("cloud_convert_flag") == "1" then
            logger.info("触发云输入处理cloud_convert, 添加option")
            context:set_option("cloud_convert", true)

            -- 返回已处理,阻止其他处理器处理这个按键
            return kAccepted
        end

        logger.info("没有处理该按键, 返回kNoop")
        return kNoop
    end)

    -- 处理错误情况
    if not success then
        local error_message = tostring(result)
        logger.error("云输入处理器发生错误: " .. error_message)

        -- 记录详细的错误信息用于调试
        logger.error("错误堆栈信息: " .. debug.traceback())

        -- 在发生错误时,安全地返回 kNoop,让其他处理器继续工作
        return kNoop
    end

    -- 成功执行,返回处理结果
    logger.info("云输入处理器执行成功, 返回值: " .. tostring(result))
    return result or kNoop
end

function cloud_input_processor.fini(env)
    logger.info("云输入处理器结束运行")
end

return cloud_input_processor
