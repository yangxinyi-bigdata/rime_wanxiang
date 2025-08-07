-- 引入日志工具模块
local logger_module = require("logger")

local logger = logger_module.create("cloud_input_processor", {
    enabled = true,
    unique_file_log = false,
    log_level = "DEBUG"
})

-- 初始化时清空日志文件
logger.clear()

-- 引入文本切分模块
-- local text_splitter = require("text_splitter")
local debug_utils = require("debug_utils")


-- 其他需要更新配置的lua脚本
local smart_cursor_processor = nil
local ai_assistant_segmentor = nil
local rawenglish_segment = nil
local rawenglish_translator = nil
local ai_assistant_translator = nil
local aux_code_filter_v3 = nil
local cloud_ai_filter_v2 = nil
local punct_eng_chinese_filter = nil
local text_splitter = nil

-- 安全加载模块，防止脚本不存在时出错
local function safe_require(module_name)
    local ok, module = pcall(require, module_name)
    if ok then
        logger.debug("成功加载模块: " .. module_name)
        return module
    else
        logger.warn("加载模块失败: " .. module_name .. " - " .. tostring(module))
        return nil
    end
end

smart_cursor_processor = safe_require("smart_cursor_processor")
ai_assistant_segmentor = safe_require("ai_assistant_segmentor")
rawenglish_segment = safe_require("rawenglish_segment")
rawenglish_translator = safe_require("rawenglish_translator")
ai_assistant_translator = safe_require("ai_assistant_translator")
aux_code_filter_v3 = safe_require("aux_code_filter_v3")
cloud_ai_filter_v2 = safe_require("cloud_ai_filter_v2")
punct_eng_chinese_filter = safe_require("punct_eng_chinese_filter")
text_splitter = safe_require("text_splitter")

-- 引入TCP同步模块
local tcp_socket = nil
local tcp_ok, tcp_err = pcall(function()
    tcp_socket = require("tcp_socket_sync")
end)
if not tcp_ok then
    logger.error("加载 tcp_socket_sync 失败: " .. tostring(tcp_err))
end

-- 返回值常量定义
local kRejected = 0 -- 表示按键被拒绝
local kAccepted = 1 -- 表示按键已被处理
local kNoop = 2 -- 表示按键未被处理,继续传递给下一个处理器

local cloud_input_processor = {}

-- 模块级别的 schema 跟踪变量
cloud_input_processor.last_schema_id = nil

-- 配置更新函数
function cloud_input_processor.update_current_config(config)
    logger.debug("重新加载AI助手配置")

    -- 读取分隔符配置
    cloud_input_processor.delimiter = config:get_string("speller/delimiter"):sub(1, 1) or " "
    logger.debug("当前分隔符: " .. cloud_input_processor.delimiter)
    
    -- 读取云转换触发符号配置
    cloud_input_processor.cloud_convert_symbol = config:get_string("translator/cloud_convert_symbol") or "Return"
    logger.debug("云转换触发符号: " .. cloud_input_processor.cloud_convert_symbol)

    -- 初始化配置对象
    cloud_input_processor.ai_assistant_config = {}
    cloud_input_processor.ai_assistant_config.chat_triggers = {}
    cloud_input_processor.ai_assistant_config.chat_names = {}
    cloud_input_processor.ai_assistant_config.reply_messages_preedit = {}
    cloud_input_processor.ai_assistant_config.prefix_to_reply = {}

    -- 读取 enabled 配置
    cloud_input_processor.ai_assistant_config.enabled = config:get_bool("ai_assistant/enabled")
    logger.debug("AI助手启用状态: " .. tostring(cloud_input_processor.ai_assistant_config.enabled))

    -- 读取 behavior 配置
    cloud_input_processor.ai_assistant_config.behavior = {}

    cloud_input_processor.ai_assistant_config.behavior.commit_question = config:get_bool(
        "ai_assistant/behavior/commit_question") or false
    cloud_input_processor.ai_assistant_config.behavior.strip_chat_prefix = config:get_bool(
        "ai_assistant/behavior/strip_chat_prefix") or false
    cloud_input_processor.ai_assistant_config.behavior.auto_commit =
        config:get_bool("ai_assistant/behavior/auto_commit") or false
    cloud_input_processor.ai_assistant_config.behavior.clipboard_mode = config:get_bool(
        "ai_assistant/behavior/clipboard_mode") or false
    cloud_input_processor.ai_assistant_config.behavior.prompt_chat = config:get_string(
        "ai_assistant/behavior/prompt_chat")

    logger.debug("行为配置 - commit_question: " ..
                     tostring(cloud_input_processor.ai_assistant_config.behavior.commit_question))
    logger.debug("行为配置 - auto_commit: " ..
                     tostring(cloud_input_processor.ai_assistant_config.behavior.auto_commit))
    logger.debug("行为配置 - clipboard_mode: " ..
                     tostring(cloud_input_processor.ai_assistant_config.behavior.clipboard_mode))
    logger.debug("行为配置 - prompt_chat: " ..
                     tostring(cloud_input_processor.ai_assistant_config.behavior.prompt_chat))

    -- 动态读取 chat_triggers 配置
    local chat_triggers_config = config:get_map("ai_assistant/chat_triggers")
    if chat_triggers_config then
        -- 获取所有键名
        local trigger_keys = chat_triggers_config:keys()
        logger.debug("找到 " .. #trigger_keys .. " 个触发器配置")

        -- 遍历配置中的所有触发器
        for _, trigger_name in ipairs(trigger_keys) do
            local trigger_value = config:get_string("ai_assistant/chat_triggers/" .. trigger_name)
            local reply_message = config:get_string("ai_assistant/reply_messages_preedit/" .. trigger_name)
            local chat_name = config:get_string("ai_assistant/chat_names/" .. trigger_name)

            if trigger_value then
                cloud_input_processor.ai_assistant_config.chat_triggers[trigger_name] = trigger_value
                logger.debug("云输入触发器 - " .. trigger_name .. ": " .. trigger_value)
            end

            if chat_name then
                cloud_input_processor.ai_assistant_config.chat_names[trigger_name] = chat_name
                logger.debug("聊天名称 - " .. trigger_name .. ": " .. chat_name)
            end

            if reply_message then
                cloud_input_processor.ai_assistant_config.reply_messages_preedit[trigger_name] = reply_message
                logger.debug("云输入回复消息 - " .. trigger_name .. ": " .. reply_message)
            end
        end
    else
        logger.warn("未找到 chat_triggers 配置")
    end

    -- 创建触发器前缀到回复消息的映射
    for trigger, prefix in pairs(cloud_input_processor.ai_assistant_config.chat_triggers) do
        local reply_message = cloud_input_processor.ai_assistant_config.reply_messages_preedit[trigger]
        if reply_message then
            cloud_input_processor.ai_assistant_config.prefix_to_reply[prefix] = reply_message
        end
    end

    -- 读取菜单配置
    local ok_menu, err_menu = pcall(function()
        cloud_input_processor.ai_assistant_config.page_size = config:get_int("menu/page_size")
        cloud_input_processor.ai_assistant_config.alternative_select_keys = config:get_string(
            "menu/alternative_select_keys")
    end)
    if ok_menu then
        logger.debug("page_size: " .. tostring(cloud_input_processor.ai_assistant_config.page_size))
        logger.debug("alternative_select_keys: " ..
                         tostring(cloud_input_processor.ai_assistant_config.alternative_select_keys))

        -- 从alternative_select_keys中截取前page_size个字符
        if cloud_input_processor.ai_assistant_config.alternative_select_keys and
            cloud_input_processor.ai_assistant_config.page_size then
            cloud_input_processor.ai_assistant_config.alternative_select_keys =
                cloud_input_processor.ai_assistant_config.alternative_select_keys:sub(1,
                    cloud_input_processor.ai_assistant_config.page_size)
            logger.debug("截取后的alternative_select_keys: " ..
                             tostring(cloud_input_processor.ai_assistant_config.alternative_select_keys))
        end
    else
        logger.error("获取菜单配置失败: " .. tostring(err_menu))
        -- 设置默认值
        cloud_input_processor.ai_assistant_config.page_size = 5
        cloud_input_processor.ai_assistant_config.alternative_select_keys = "123456789"
        -- 截取默认值
        cloud_input_processor.ai_assistant_config.alternative_select_keys =
            cloud_input_processor.ai_assistant_config.alternative_select_keys:sub(1,
                cloud_input_processor.ai_assistant_config.page_size)
        logger.debug("使用默认菜单配置 - page_size: " .. cloud_input_processor.ai_assistant_config.page_size ..
                         ", alternative_select_keys: " ..
                         cloud_input_processor.ai_assistant_config.alternative_select_keys)
    end

    logger.debug("AI助手配置更新完成")
end

-- 统一的配置更新函数
function cloud_input_processor.update_all_modules_config(config)
    logger.info("开始更新所有模块配置")
    
    -- 更新所有模块的配置，添加nil检查防止模块加载失败
    cloud_input_processor.update_current_config(config)
    
    if rawenglish_translator and rawenglish_translator.update_current_config then
        rawenglish_translator.update_current_config(config)
    end
    
    if smart_cursor_processor and smart_cursor_processor.update_current_config then
        smart_cursor_processor.update_current_config(config)
    end
    if ai_assistant_segmentor and ai_assistant_segmentor.update_current_config then
        ai_assistant_segmentor.update_current_config(config)
    end
    if rawenglish_segment and rawenglish_segment.update_current_config then
        rawenglish_segment.update_current_config(config)
    end
    if ai_assistant_translator and ai_assistant_translator.update_current_config then
        ai_assistant_translator.update_current_config(config)
    end
    if aux_code_filter_v3 and aux_code_filter_v3.update_current_config then
        aux_code_filter_v3.update_current_config(config)
    end
    if cloud_ai_filter_v2 and cloud_ai_filter_v2.update_current_config then
        cloud_ai_filter_v2.update_current_config(config)
    end
    if punct_eng_chinese_filter and punct_eng_chinese_filter.update_current_config then
        punct_eng_chinese_filter.update_current_config(config)
    end
    if text_splitter and text_splitter.update_current_config then
        text_splitter.update_current_config(config)
    end

    logger.info("所有模块配置更新完成")
end

-- 获取当前AI上下文对应的回复输入格式
local function get_current_ai_reply_input(env, context)
    if not cloud_input_processor.ai_assistant_config or not cloud_input_processor.ai_assistant_config.chat_triggers then
        return "ai_reply:" -- 默认回复输入
    end

    -- 获取当前AI上下文标记
    local current_ai_context = context:get_property("current_ai_context")
    if current_ai_context and cloud_input_processor.ai_assistant_config.chat_triggers[current_ai_context] then
        local trigger_prefix = cloud_input_processor.ai_assistant_config.chat_triggers[current_ai_context]
        local reply_input = trigger_prefix:gsub(":$", "_reply:")
        logger.debug("使用AI上下文回复输入: " .. current_ai_context .. " -> " .. reply_input)
        return reply_input
    end

    -- 如果没有设置上下文，尝试从输入历史中推断
    local input_history = context:get_property("ai_input_history")
    if input_history and cloud_input_processor.ai_assistant_config.chat_triggers then
        for trigger, prefix in pairs(cloud_input_processor.ai_assistant_config.chat_triggers) do
            if input_history:match("^" .. prefix:gsub("[%(%)%.%+%-%*%?%[%]%^%$%%]", "%%%1")) then
                local reply_input = prefix:gsub(":$", "_reply:")
                logger.debug("从输入历史推断回复输入: " .. prefix .. " -> " .. reply_input)
                return reply_input
            end
        end
    end

    return "ai_reply:" -- 默认回复输入
end

-- 计算候选词中汉字的数量
local function count_chinese_characters(text)
    -- 使用utf8库计算中文字符数量
    local count = 0
    for pos, code in utf8.codes(text) do
        -- 中文字符的Unicode范围：
        -- 基本汉字区：0x4E00-0x9FFF
        -- 扩展A区：0x3400-0x4DBF
        -- 其他常用中文符号区间
        if (code >= 0x4E00 and code <= 0x9FFF) or (code >= 0x3400 and code <= 0x4DBF) then
            count = count + 1
        end
    end

    return count
end

-- 从script_text末尾移除指定数量的音节
local function remove_syllables_from_end(script_text, syllable_count, delimiter)
    if syllable_count <= 0 then
        return script_text
    end

    -- 按分隔符分割script_text
    local parts = {}
    for part in script_text:gmatch("[^" .. delimiter .. "]+") do
        table.insert(parts, part)
    end

    -- 如果要移除的音节数量大于等于总数，返回空字符串
    if syllable_count >= #parts then
        return ""
    end

    -- 移除末尾的指定数量音节
    local result_parts = {}
    for i = 1, #parts - syllable_count do
        table.insert(result_parts, parts[i])
    end

    -- 重新组合，保持原有的分隔符
    return table.concat(result_parts, delimiter)
end

-- 构建最终的上屏文本
local function build_commit_text(script_text, candidate_text, delimiter, chat_trigger_name)
    -- 检查并提取chat_trigger_name前缀
    local prefix = ""
    local actual_script_text = script_text

    if chat_trigger_name and script_text:sub(1, #chat_trigger_name) == chat_trigger_name then
        prefix = chat_trigger_name
        actual_script_text = script_text:sub(#chat_trigger_name + 1)
        logger.info("提取出前缀: '" .. prefix .. "', 剩余script_text: '" .. actual_script_text .. "'")
    end

    -- 将反引号替换成空格，确保分词的完整性
    actual_script_text = actual_script_text:gsub("`", " ")
    logger.info("candidate_text: " .. candidate_text)
    logger.info("替换反引号后的script_text: '" .. actual_script_text .. "'")

    -- 使用更聪明的匹配方法：按段落匹配而不是逐字符匹配
    local temp_script_text = actual_script_text

    -- 将候选词按空格分割成段落（保留空格信息）
    local candidate_parts = {}
    local current_part = ""
    local in_space_sequence = false

    for pos, code in utf8.codes(candidate_text) do
        local char = utf8.char(code)
        if char == " " then
            if not in_space_sequence and current_part ~= "" then
                table.insert(candidate_parts, {
                    type = "text",
                    content = current_part
                })
                current_part = ""
            end
            current_part = current_part .. char
            in_space_sequence = true
        else
            if in_space_sequence and current_part ~= "" then
                table.insert(candidate_parts, {
                    type = "space",
                    content = current_part
                })
                current_part = ""
            end
            current_part = current_part .. char
            in_space_sequence = false
        end
    end

    -- 添加最后一个部分
    if current_part ~= "" then
        local part_type = in_space_sequence and "space" or "text"
        table.insert(candidate_parts, {
            type = part_type,
            content = current_part
        })
    end

    -- 从后往前处理每个部分
    for i = #candidate_parts, 1, -1 do
        local part = candidate_parts[i]
        logger.info("处理候选词片段: '" .. part.content .. "' (类型: " .. part.type .. ")")

        if part.type == "text" then
            -- 文本片段：统计中文字符数量，移除对应的音节
            local chinese_count = count_chinese_characters(part.content)
            if chinese_count > 0 then
                temp_script_text = remove_syllables_from_end(temp_script_text, chinese_count, delimiter)
                logger.info("文本片段包含" .. chinese_count .. "个中文字符，移除" .. chinese_count ..
                                "个音节，剩余: '" .. temp_script_text .. "'")
            else
                -- 纯英文文本，移除对应长度的部分
                local text_len = utf8.len(part.content)
                temp_script_text = remove_syllables_from_end(temp_script_text, 1, delimiter) -- 假设英文单词对应一个音节
                logger.info(
                    "英文片段 '" .. part.content .. "'，移除1个音节，剩余: '" .. temp_script_text .. "'")
            end
        else
            -- 空格片段：从script_text末尾移除对应长度的空格
            local space_count = utf8.len(part.content)
            for j = 1, space_count do
                if temp_script_text:sub(-1) == " " then
                    temp_script_text = temp_script_text:sub(1, -2)
                end
            end
            logger.info("移除" .. space_count .. "个空格字符，剩余: '" .. temp_script_text .. "'")
        end
    end

    local processed_script_text = temp_script_text
    logger.info("最终处理后的script_text: '" .. processed_script_text .. "'")

    -- 组合最终文本
    local final_text
    if processed_script_text == "" then
        final_text = prefix .. candidate_text
    else
        final_text = prefix .. processed_script_text .. candidate_text
    end

    logger.info("最终上屏文本: '" .. final_text .. "'")
    return final_text
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
        logger.debug("检测到空格键，按选词键1处理 (索引: " .. select_key_index .. ")")
    else
        -- 直接查找字符在选词键字符串中的位置
        select_key_index = string.find(cloud_input_processor.ai_assistant_config.alternative_select_keys, key_repr, 1,
            true)
        if select_key_index then
            is_select_key = true
            logger.debug("检测到选词键: " .. key_repr .. " (索引: " .. select_key_index .. ")")
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
                        logger.debug("选词将完成上屏操作，拦截按键并发送AI消息")
                        local candidate_text = candidate.text
                        logger.debug("候选词文本: " .. candidate_text)

                        -- 如果是ac:nihk 那么匹配不到中文, 也就是script_text_chinese为空, going_commit_text只有候选词
                        -- 如果前面有一个纯英文片段, 而且中文是一次性选择到的,script_text: at: this is why wo ui zv hk de, 
                        -- 最后选的候选词,如果有五个字,则应该从script_text中切除最后五个音节
                        -- 候选词对应的明显不是全部的, 那么前边一定还有内容, 如果script_text_chinese为空, 则需要判断前面是不是有内容, 怎么判断呢? 
                        -- this is why nihk okhaha vejqui 对于这种 恐怕也是一定会被遗漏的, 所以这个函数获取就是有缺陷.
                        -- 必须考虑英文部分,怎么考虑呢? 看看, 遍历所有片段, 看看是什么类型的
                        local script_text = context:get_script_text()
                        logger.info("script_text: " .. script_text)

                        -- 对上屏文本前边去除掉, 首先要知道最前边的那个是什么, 在chat_names中
                        logger.debug("chat_trigger: " .. chat_trigger)
                        local chat_trigger_name = cloud_input_processor.ai_assistant_config.chat_triggers[chat_trigger]
                        logger.debug("chat_trigger_name: " .. chat_trigger_name)

                        -- 使用新的函数构建最终的上屏文本，传入chat_trigger_name参数
                        local going_commit_text = build_commit_text(script_text, candidate_text,
                            cloud_input_processor.delimiter, chat_trigger_name)
                        logger.info("going_commit_text: " .. going_commit_text)

                        -- 判断going_commit_text是否以chat_names开头，如果是则删除前缀
                        local final_commit_text = going_commit_text
                        if chat_trigger_name and going_commit_text:sub(1, #chat_trigger_name) == chat_trigger_name then
                            final_commit_text = going_commit_text:sub(#chat_trigger_name + 1)
                            logger.info("删除chat_trigger_name前缀 final_commit_text: " .. chat_trigger_name ..
                                            " -> " .. final_commit_text)
                        else
                            logger.info("未找到前缀，直接上屏final_commit_text: " .. final_commit_text)
                        end

                        -- 发送聊天消息到AI服务，使用keepon_chat_trigger作为对话类型

                        local ok, result = pcall(function()

                            -- 读取最新消息（丢弃积压的旧消息，保留最新的有用消息）
                            local flushed_bytes = tcp_socket.flush_ai_socket_buffer()
                            if flushed_bytes and flushed_bytes > 0 then
                                logger.debug("清理了积压的AI消息: " .. flushed_bytes .. " 字节")
                            else
                                logger.debug("无积压的AI消息需要处理")
                            end

                            tcp_socket.send_chat_message(final_commit_text, chat_trigger) -- 正常输入换行

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

                            if cloud_input_processor.ai_assistant_config.behavior.commit_question then

                                -- 再判断strip_chat_prefix为true或者false,如果为true,则清空并且重新上屏字符串
                                if cloud_input_processor.ai_assistant_config.behavior.strip_chat_prefix then

                                    logger.debug("context:clear()")
                                    context:clear()

                                    engine:commit_text(final_commit_text)
                                    return kAccepted
                                else
                                    -- 正常上屏操作, 不去除前缀的话,就会正常的向后推动,变成一个普通的上屏操作
                                    logger.info("未设置strip_chat_prefix, 不需要删除前缀，直接上屏: " ..
                                                    going_commit_text)
                                    logger.debug("context:clear()")
                                    context:clear()

                                    engine:commit_text(going_commit_text)
                                    return kAccepted
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
                    logger.warn("无法获取候选词对象")
                end
            else
                logger.debug("菜单为空或选词索引超出范围: " .. select_key_index .. " > " ..
                                 (menu:candidate_count() or 0))
            end
        else
            logger.debug("没有有效的segment或menu")
        end
    end
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
    logger.debug("当前预编辑文本: " .. clean_text)
    local _, count = string.gsub(clean_text, cloud_input_processor.delimiter, cloud_input_processor.delimiter)
    logger.debug("当前输入内容分隔符数量: " .. count)
    -- local has_punct = has_punctuation(input)

    -- 触发状态改成,当数如字符超过4个,或者有标点且超过2个:
    if is_composing and count >= 3 then
        logger.debug("当前正在组词状态,检测到分隔符数量达到3,触发云输入提示")
        -- 只在值真正需要改变时才设置
        -- 先获取当前选项的值，避免不必要的更新
        logger.debug("当前云输入提示标志: " .. context:get_property("cloud_convert_flag"))

        if context:get_property("cloud_convert_flag") == "0" then
            logger.debug("云输入提示标志为 0, 设置为 1")
            context:set_property("cloud_convert_flag", "1")
            -- context:set_option("cloud_convert_prompt", true)
            logger.debug("cloud_convert_flag 已设置为 1")

        end

    else
        -- 如果不在组词状态或没有达到触发条件,则重置提示选项
        logger.debug("当前不在组词状态或未达到触发条件,云输入提示已重置")
        if context:get_property("cloud_convert_flag") == "1" then
            -- context:set_option("cloud_convert_prompt", false)
            context:set_property("cloud_convert_flag", "0")
            logger.debug("cloud_convert_flag 已设置为 0")

        end
    end
end

function cloud_input_processor.init(env)
    -- 获取输入法引擎和上下文   
    local config = env.engine.schema.config
    local current_schema_id = env.engine.schema.schema_id
    

    -- 检查是否需要更新配置（第一次初始化或 schema 发生变化）
    local need_update = false
    if cloud_input_processor.last_schema_id == nil then
        logger.info("首次初始化，需要更新所有模块配置")
        need_update = true
    elseif cloud_input_processor.last_schema_id ~= current_schema_id then
        logger.info("Schema 发生变化: " .. tostring(cloud_input_processor.last_schema_id) .. " -> " .. current_schema_id .. "，需要更新所有模块配置")
        need_update = true
    else
        logger.info("Schema 未变化: " .. current_schema_id .. "，跳过配置更新")
    end

    if need_update then
        -- 使用统一的配置更新函数更新所有模块配置
        cloud_input_processor.update_all_modules_config(config)
        -- 更新记录的 schema ID
        cloud_input_processor.last_schema_id = current_schema_id
        logger.debug("cloud_input_processor及所有模块配置加载完成")
    else
        -- 即使不需要全面更新，也要确保当前模块的基本配置是正确的
        cloud_input_processor.update_current_config(config)
        logger.debug("cloud_input_processor配置更新完成（其他模块跳过）")
    end

    --  fixed 设置一个变量
    -- context:set_property只能设置字符串类型
    env.engine.context:set_property("cloud_convert_flag", "0")
    env.engine.context:set_property("rawenglish_prompt", "0")

    logger.debug("云输入处理器初始化完成")
end

-- 按键处理器函数
-- 负责监听按键事件,判断是否应该触发翻译器
function cloud_input_processor.func(key, env)
    local engine = env.engine
    local context = engine.context
    local segmentation = context.composition:toSegmentation()
    local input = context.input
    local key_repr = key:repr()
    -- logger.info("测试虚拟按键: " .. key_repr)

    if key_repr == "Release+Control_L" then
        logger.debug("拦截所有Release+Control_L按键")
        return kAccepted
    end

    if context:get_property("should_intercept_key_release") == "1" then
        -- 检查是否需要拦截Release+Shift_L按键
        if key_repr == "Release+Shift_L" or key_repr == "Release+Shift_R" then
            logger.debug("拦截Release+Shift_L按键（由于之前处理了Shift+组合键）")
            -- 清除标志，避免影响后续操作
            context:set_property("should_intercept_key_release", "0")
            return kAccepted
        end
    end

    -- 测试: 尝试去调用各个模块的update_current_config函数
    if key_repr == "Control+F10" then
        -- 应该是当前收到服务端发送过来的命令的时候, config就已经完成修改了.
        logger.info("Control+F10: 强制更新所有模块配置")
        local config = env.engine.schema.config

        -- 使用统一的配置更新函数，强制更新所有模块
        cloud_input_processor.update_all_modules_config(config)

        logger.info("Control+F10: 所有模块配置更新完成")
    end

    -- 检查Control+F11按键的处理
    if key_repr == "Control+F11" then
        if context:get_property("get_ai_stream") == "true" then
            logger.debug("get_ai_stream==true, 触发重新刷新候选词: ")
            if context.input == "" then
                local reply_input = get_current_ai_reply_input(env, context)
                context.input = reply_input
                logger.debug("设置AI回复输入: " .. reply_input)
            end
            context:refresh_non_confirmed_composition()
            return kAccepted
        elseif context:get_property("get_cloud_stream") == "true" then
            logger.debug("get_cloud_stream==true, 触发重新刷新云输入候选词: ")
            context:refresh_non_confirmed_composition()
            return kAccepted
        else
            logger.debug("get_ai_stream==false && get_cloud_stream==false, 依然拦截输入Control+F11: ")
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
            logger.debug("commit_text: " .. commit_text)
            if commit_text and commit_text:find("\n") then
                logger.debug("commit_text 中存在换行符")
                -- 拦截按键, 清空当前context中的内容.
                logger.debug("context:clear()")
                context:clear()

                -- 使用TCP通信发送粘贴命令到Python服务端（跨平台通用）
                if tcp_socket then
                    logger.debug("🍴 通过TCP发送粘贴命令到Python服务端 (intercept模式)")
                    local paste_success = tcp_socket.send_paste_command()
                    if paste_success then
                        logger.debug("✅ 粘贴命令发送成功 (intercept模式)")
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
                logger.debug("commit_text 中不存在换行符")
                logger.debug("set_property intercept_select_key: 0")
                context:set_property("intercept_select_key", "0")
                return kNoop
            end

        end

    end

    -- 如果是ai_talk标签的segment, 则需要判断是不是将要上屏, 如果要上屏,则进行拦截后处理
    local first_segment = segmentation:get_at(0)
    local last_segment = segmentation:back()
    -- 英文模式豁免
    logger.debug("property: rawenglish_prompt: " .. context:get_property("rawenglish_prompt"))
    if first_segment:has_tag("ai_talk") and context:get_property("rawenglish_prompt") == "0" then
        logger.debug("first_segment.tags: ai_talk")
        -- for element, _ in pairs(first_segment.tags) do
        --     logger.debug("first_segment.tags: " .. element)
        -- end
        local tag = first_segment.tags - Set {"ai_talk"}
        -- 遍历Set，由于只有一个元素，第一次循环就会得到结果
        local tag_chat_trigger
        for element, _ in pairs(tag) do
            tag_chat_trigger = element
            logger.debug("tag_chat_trigger: " .. tag_chat_trigger)
            break
        end

        debug_utils.print_segmentation_info(segmentation, logger)
        -- 处理AI会话是否要进行传输等操作
        local result = handle_ai_chat_selection(key_repr, tag_chat_trigger, env, last_segment)
        logger.debug("handle_ai_chat_selection result: " .. tostring(result))
        if result then
            return result
        end

    end

    -- -- 开始判断连续ai对话分支内容
    -- -- context:set_property("keepon_chat_trigger", "translate_ai_chat")
    -- local keepon_chat_trigger = context:get_property('keepon_chat_trigger')
    -- logger.debug("keepon_chat_trigger: " .. keepon_chat_trigger)
    -- -- 属性存在值代表要进入自动ai对话模式
    -- if keepon_chat_trigger ~= "" then
    --     logger.debug("keepon_chat_trigger: " .. keepon_chat_trigger)

    --     -- 应该有豁免,对于两种情况是豁免发送的,1. AI:对话消息,2:AI回复消息
    --     -- segment.tags 是一个Set，遍历输出其中的内容
    --     -- local tags_str = ""
    --     -- if first_segment.tags and type(first_segment.tags) == "table" then
    --     --     for tag, _ in pairs(first_segment.tags) do
    --     --         tags_str = tags_str .. tostring(tag) .. " "
    --     --     end
    --     -- end
    --     -- logger.debug("first_segment.tags: " .. tags_str)
    --     if first_segment:has_tag("ai_talk") or first_segment:has_tag("ai_reply") then
    --         logger.debug("first_segment.tags: ai_talk or ai_reply")
    --         return kNoop
    --     end

    --     -- -- 处理AI会话是否要进行传输等操作
    --     -- local result = handle_ai_chat_selection(key_repr, keepon_chat_trigger, env, last_segment)
    --     -- if result then
    --     --     return result
    --     -- end

    -- end

    -- 使用 pcall 捕获所有可能的错误
    local success, result = pcall(function()

        if #input <= 1 then
            logger.debug("input为1, 不判断直接退出")
            return kNoop
        end

        local segmentation = context.composition:toSegmentation()

        -- 检查按键是否有效
        if not key then
            error("按键对象为空")
        end

        -- 如果输入的按键是一个反引号,则判断这个反引号是不是一个和前边的反引号配对的闭合单引号
        -- 如果是则直接将当前第一个候选项上屏.
        logger.debug("")
        logger.debug("=== 开始分析lua/cloud_input_processor.lua ===")
        logger.debug("当前按键: " .. key_repr)
        logger.debug("当前input: " .. input)

        logger.debug("context:get_property:rawenglish_prompt " .. context:get_property("rawenglish_prompt"))

        -- 首先打印seg的信息
        -- 使用debug_utils打印Segmentation信息
        -- debug_utils.print_segmentation_info(segmentation, logger)
        logger.debug("当前云输入提示标志: " .. context:get_property("rawenglish_prompt"))

        if context:get_property("rawenglish_prompt") == "1" then
            if key_repr:match("^Release%+") then
                logger.debug("反引号状态下跳过按键事件: " .. key_repr)
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
            logger.debug("key_repr: " .. key_repr)
            if handle_keys[key_repr] then
                logger.debug("处于反引号状态，将按键转为普通字符: " .. key_repr)

                -- 如果是Shift+XXX按键，设置属性用于拦截后续的Release+Shift_L
                if key_repr:match("^Shift%+") then
                    context:set_property("should_intercept_key_release", "1")
                    logger.debug("检测到Shift+组合键，设置拦截按键释放标志")
                end

                -- 将按键对应的字符添加到输入中
                local char_to_add = handle_keys[key_repr]
                -- 如果添加英文字母没有影响,但是
                context:push_input(char_to_add)

                -- 返回 kAccepted 表示我们已经处理了这个按键
                return kAccepted
            end
        end

        -- -- local segmentation_input = segmentation.input
        -- -- logger.debug("segmentation_input: " .. segmentation_input)
        -- -- 检查反引号的数量是否为奇数(说明有未闭合的反引号)

        -- -- 如果当前输入的就是反引号,会有一个延迟,单独判断一下.
        -- -- 如果输入的是反引号,那么segmente_input是前边的内容, 
        -- -- 这就有两种情况, 一种是 wo` 一种是wo`ok`
        -- -- 如果是前边的情况, segmente_input为 input, 后面的情况 segmente_input为 wo`ok

        -- if key_repr == "grave" then
        --     -- segmente_input 后面追加一个反引号字符
        --     segmentation_input = segmentation_input .. "`"
        --     logger.debug("检测到反引号输入，segmente_input 更新为: " .. segmentation_input)
        -- elseif key_repr == "BackSpace" then
        --     -- 删除按键之后,如果删除掉的是一个反引号,也应该马上触发
        --     segmentation_input = segmentation_input:sub(1, -2)
        -- end
        -- local _, rawenglish_count = segmentation_input:gsub("`", "")
        -- if rawenglish_count % 2 == 1 then
        --     logger.debug("检测到奇数个反引号,存在未闭合情况: " .. segmentation_input ..
        --                      " (反引号数量: " .. rawenglish_count .. ")")
        --     -- 只在值真正需要改变时才设置
        --     -- 先获取当前选项的值，避免不必要的更新
        --     logger.debug("当前云输入提示标志: " .. context:get_property("rawenglish_prompt"))

        --     if context:get_property("rawenglish_prompt") == "0" then
        --         logger.debug("rawenglish_prompt提示标志为 0, 设置为 1")
        --         context:set_property("rawenglish_prompt", "1")
        --         logger.debug("rawenglish_prompt 已设置为 1")
        --     end

        --     if key_repr:match("^Release%+") then
        --         logger.debug("反引号状态下跳过按键事件: " .. key_repr)
        --         return kAccepted
        --     end

        --     -- 定义需要转换为普通字符的按键
        --     local handle_keys = {
        --         ["space"] = " ", -- 空格转为空格字符
        --         -- 数字键
        --         ["1"] = "1",
        --         ["2"] = "2",
        --         ["3"] = "3",
        --         ["4"] = "4",
        --         ["5"] = "5",
        --         ["6"] = "6",
        --         ["7"] = "7",
        --         ["8"] = "8",
        --         ["9"] = "9",
        --         ["0"] = "0",
        --         -- 数字键的Shift版本（符号）
        --         ["Shift+1"] = "!", -- !
        --         ["Shift+2"] = "@", -- @
        --         ["Shift+3"] = "#", -- #
        --         ["Shift+4"] = "$", -- $
        --         ["Shift+5"] = "%", -- %
        --         ["Shift+6"] = "^", -- ^
        --         ["Shift+7"] = "&", -- &
        --         ["Shift+8"] = "*", -- *
        --         ["Shift+9"] = "(", -- (
        --         ["Shift+0"] = ")", -- )

        --         -- 标点符号（不需要Shift）
        --         ["period"] = ".", -- 句号
        --         ["comma"] = ",", -- 逗号
        --         ["semicolon"] = ";", -- 分号
        --         ["apostrophe"] = "'", -- 单引号/撇号
        --         ["bracketleft"] = "[", -- 左方括号
        --         ["bracketright"] = "]", -- 右方括号
        --         ["hyphen"] = "-", -- 连字符
        --         ["equal"] = "=", -- 等号
        --         ["slash"] = "/", -- 斜杠
        --         ["backslash"] = "\\", -- 反斜杠
        --         ["grave"] = "`", -- 反引号

        --         -- 标点符号的Shift版本
        --         ["Shift+semicolon"] = ":", -- :
        --         ["Shift+apostrophe"] = "\"", -- "
        --         ["Shift+bracketleft"] = "{", -- {
        --         ["Shift+bracketright"] = "}", -- }
        --         ["Shift+hyphen"] = "_", -- _
        --         ["Shift+equal"] = "+", -- +
        --         ["Shift+slash"] = "?", -- ?
        --         ["Shift+backslash"] = "|", -- |
        --         ["Shift+grave"] = "~", -- ~

        --         -- 直接映射的符号键
        --         ["minus"] = "-", -- 冒号
        --         ["colon"] = ":", -- 冒号
        --         ["question"] = "?", -- 问号
        --         ["exclam"] = "!", -- 感叹号
        --         ["quotedbl"] = "\"", -- 双引号
        --         ["parenleft"] = "(", -- 左圆括号
        --         ["parenright"] = ")", -- 右圆括号
        --         ["braceleft"] = "{", -- 左花括号
        --         ["braceright"] = "}", -- 右花括号
        --         ["underscore"] = "_", -- 下划线
        --         ["plus"] = "+", -- 加号
        --         ["asterisk"] = "*", -- 星号
        --         ["at"] = "@", -- @ 符号
        --         ["numbersign"] = "#", -- # 号
        --         ["dollar"] = "$", -- 美元符号
        --         ["percent"] = "%", -- 百分号
        --         ["ampersand"] = "&", -- & 符号
        --         ["less"] = "<", -- 小于号
        --         ["greater"] = ">", -- 大于号
        --         ["asciitilde"] = "~", -- 波浪号
        --         ["asciicircum"] = "^", -- 插入符号
        --         ["bar"] = "|", -- 竖线

        --         -- 为这些符号键也添加Shift版本（以防万一）
        --         ["Shift+colon"] = ":",
        --         ["Shift+question"] = "?",
        --         ["Shift+exclam"] = "!",
        --         ["Shift+quotedbl"] = "\"",
        --         ["Shift+parenleft"] = "(",
        --         ["Shift+parenright"] = ")",
        --         ["Shift+braceleft"] = "{",
        --         ["Shift+braceright"] = "}",
        --         ["Shift+underscore"] = "_",
        --         ["Shift+plus"] = "+",
        --         ["Shift+asterisk"] = "*",
        --         ["Shift+at"] = "@",
        --         ["Shift+numbersign"] = "#",
        --         ["Shift+dollar"] = "$",
        --         ["Shift+percent"] = "%",
        --         ["Shift+ampersand"] = "&",
        --         ["Shift+less"] = "<",
        --         ["Shift+greater"] = ">",
        --         ["Shift+asciitilde"] = "~",
        --         ["Shift+asciicircum"] = "^",
        --         ["Shift+bar"] = "|"

        --     }
        --     logger.debug("key_repr: " .. key_repr)
        --     if handle_keys[key_repr] then
        --         logger.debug("处于反引号状态，将按键转为普通字符: " .. key_repr)

        --         -- 将按键对应的字符添加到输入中
        --         local char_to_add = handle_keys[key_repr]
        --         -- 如果添加英文字母没有影响,但是
        --         context:push_input(char_to_add)

        --         -- 返回 kAccepted 表示我们已经处理了这个按键
        --         return kAccepted
        --     end

        -- else
        --     -- 如果不在组词状态或没有达到触发条件,则重置提示选项
        --     logger.debug("当前不在反引号当中rawenglish提示已重置")
        --     if context:get_property("rawenglish_prompt") == "1" then
        --         context:set_property("rawenglish_prompt", "0")
        --         logger.debug("rawenglish_prompt 已设置为 0")
        --     end
        -- end

        logger.debug("=== 结束分析lua/cloud_input_processor.lua ===")
        logger.debug("")

        -- 设置云输入法表示标
        set_cloud_convert_flag(context)

        -- 检查当前按键是否为预设的触发键
        if key:repr() == cloud_input_processor.cloud_convert_symbol and context:get_property("cloud_convert_flag") == "1" then
            logger.debug("触发云输入处理cloud_convert, 添加option")
            context:set_option("cloud_convert", true)
            
            -- 设置拦截标志，用于拦截后续的按键释放事件
            context:set_property("should_intercept_key_release", "1")
            logger.debug("设置拦截按键释放标志")

            -- 返回已处理,阻止其他处理器处理这个按键
            return kAccepted
        end

        logger.debug("没有处理该按键, 返回kNoop")
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
    logger.debug("云输入处理器执行成功, 返回值: " .. tostring(result))
    return result or kNoop
end

function cloud_input_processor.fini(env)
    logger.debug("云输入处理器结束运行")
end

return cloud_input_processor
