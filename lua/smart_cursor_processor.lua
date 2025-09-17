-- 智能光标移动处理器 - 在标点符号处停止
local logger_module = require("logger")
local debug_utils = require("debug_utils")
-- 引入文本切分模块
local text_splitter = require("text_splitter")
-- 引入spans管理模块
local spans_manager = require("spans_manager")

-- 创建日志记录器
local logger = logger_module.create("smart_cursor_processor", {
    enabled = true,
    unique_file_log = false, -- 启用日志以便测试
    log_level = "DEBUG"
})

-- 初始化时清空日志文件
logger.clear()

local tcp_socket = nil
local ok, err = pcall(function()
    tcp_socket = require("tcp_socket_sync")
end)
if not ok then
    logger.error("加载 tcp_socket_sync 失败: " .. tostring(err))
else
    logger.info("加载 tcp_socket_sync 成功")
    if tcp_socket then
        local ok_init, err = pcall(function()
            tcp_socket.init()
        end)
        if not ok_init then
            logger.error("sync_module.init() 执行失败: " .. tostring(err))
        else
            logger.info("sync_module.init() 执行成功")
        end
    else
        logger.error("sync_module为nil，尽管require没有报错")
    end
end

-- 模块级配置缓存
local smart_cursor_processor = {}
smart_cursor_processor.move_next_punct = nil
smart_cursor_processor.move_prev_punct = nil
smart_cursor_processor.paste_to_input = nil
smart_cursor_processor.search_move_cursor = nil
smart_cursor_processor.shuru_schema = nil
smart_cursor_processor.chat_triggers = {}
smart_cursor_processor.previous_client_app = ""
smart_cursor_processor.app_vim_mode_state = {}

-- 读取配置的辅助函数，从config中读取并缓存到模块级变量
function smart_cursor_processor.update_current_config(config)
    logger.info("开始更新smart_cursor_processor模块配置")

    -- 读取键位绑定配置
    smart_cursor_processor.move_next_punct = config:get_string("key_binder/move_next_punct")
    smart_cursor_processor.move_prev_punct = config:get_string("key_binder/move_prev_punct")
    smart_cursor_processor.search_move_cursor = config:get_string("key_binder/search_move_cursor")
    smart_cursor_processor.paste_to_input = config:get_string("key_binder/paste_to_input")
    smart_cursor_processor.shuru_schema = config:get_string("schema/my_shuru_schema")
    smart_cursor_processor.keep_input_uncommit = config:get_bool("translator/keep_input_uncommit")

    smart_cursor_processor.app_options = config:get_map("app_options")

    if smart_cursor_processor.app_options then
        for _, app_key in ipairs(smart_cursor_processor.app_options:keys()) do
            local item = smart_cursor_processor.app_options:get(app_key)
            if item and item.get_map then
                local app_map = item:get_map()
                for _, k in ipairs(app_map:keys()) do
                    logger.debug("app_key: " .. app_key .. " k: " .. k .. " value: " ..
                                     config:get_string("app_options/" .. app_key .. "/" .. k))
                end
            end
        end
    end

    logger.info("键位配置 - move_next_punct: " .. tostring(smart_cursor_processor.move_next_punct))
    logger.info("键位配置 - move_prev_punct: " .. tostring(smart_cursor_processor.move_prev_punct))
    logger.info("键位配置 - search_move_cursor: " .. tostring(smart_cursor_processor.search_move_cursor))
    logger.info("键位配置 - paste_to_input: " .. tostring(smart_cursor_processor.paste_to_input))
    logger.info("键位配置 - shuru_schema: " .. tostring(smart_cursor_processor.shuru_schema))

    -- 重新初始化chat_triggers
    smart_cursor_processor.chat_triggers = {}

    -- 动态读取 ai_prompts 配置（新结构）
    local ai_prompts_config = config:get_map("ai_assistant/ai_prompts")
    if ai_prompts_config then
        -- 获取所有键名
        local trigger_keys = ai_prompts_config:keys()
        logger.info("找到 " .. #trigger_keys .. " 个 ai_prompts 配置")

        -- 遍历 ai_prompts 中的所有触发器项
        for _, trigger_name in ipairs(trigger_keys) do
            local base_key = "ai_assistant/ai_prompts/" .. trigger_name
            local trigger_value = config:get_string(base_key .. "/chat_triggers")

            if trigger_value and #trigger_value > 0 then
                smart_cursor_processor.chat_triggers[trigger_name] = trigger_value
                logger.info("云输入触发器 - " .. trigger_name .. ": " .. trigger_value)
            end
        end
    else
        logger.warn("未找到 ai_prompts 配置")
    end

    logger.info("smart_cursor_processor模块配置更新完成")
end

function smart_cursor_processor.init(env)
    local engine = env.engine
    local context = engine.context
    local schema = engine.schema
    local config = schema.config
    logger.info("智能光标移动处理器初始化完成")

    -- 配置更新由 cloud_input_processor 统一管理，无需在此处调用
    logger.info("等待 cloud_input_processor 统一更新配置")

    -- 初始化时应用 tcp_socket_sync 记录的全局开关（实现跨会话同步）
    if tcp_socket and tcp_socket.apply_global_options_to_context then
        local applied = tcp_socket.apply_global_options_to_context(context)
        if applied > 0 then
            logger.info("初始化应用全局开关数量: " .. tostring(applied))
        end
    end

    -- 定义标点符号集合
    env.punctuation_chars = {
        [","] = true,
        ["."] = true,
        ["!"] = true,
        ["?"] = true,
        [";"] = true,
        [":"] = true,
        ["("] = true,
        [")"] = true,
        ["["] = true,
        ["]"] = true,
        ["<"] = true,
        [">"] = true,
        ["/"] = true,
        ["_"] = true,
        ["="] = true,
        ["+"] = true,
        ["*"] = true,
        ["&"] = true,
        ["^"] = true,
        ["%"] = true,
        ["$"] = true,
        ["#"] = true,
        ["@"] = true,
        ["~"] = true,
        ["|"] = true,
        ["-"] = true,
        ["'"] = true,
        ['"'] = true
    }

    -- env.unhandled_key_notifier = context.unhandled_key_notifier:connect(function(context)
    --     logger.debug("unhandled_key_notifier")
    -- end)

    env.select_notifier = context.select_notifier:connect(function(context)
        -- 只要出发了选词通知,就关闭搜索模式
        -- 退出搜索模式
        if context:get_option("search_move") then
            logger.debug("选词通知: 退出搜索模式")
            context:set_option("search_move", false)
            context:set_property("search_move_str", "")
        end

        -- 选词完成后清除spans信息
        spans_manager.clear_spans(context, "选词完成")
    end)

    env.commit_notifier = context.commit_notifier:connect(function(context)
        -- 清空context:set_property("input_string", input)
        context:set_property("input_string", "")
        logger.info("清空context:set_property input_string")

        -- 上屏之后,将当前的状态和上屏内容发送过去
        logger.info("上屏通知触发sync_with_server")
        -- 传递提交内容文本的信息
        logger.debug("send_key: " .. context:get_property("send_key"))
        if context:get_property("send_key") ~= "" then
            tcp_socket.sync_with_server(env, true, true, "button", context:get_property("send_key"))
            context:set_property("send_key", "")
        else
            tcp_socket.sync_with_server(env, true, true)
        end
    end)

    env.update_notifier = context.update_notifier:connect(function(context)
        -- 只要出发了上屏通知,就关闭搜索模式
        -- 退出搜索模式
        -- logger.debug("触发update_notifier context更新通知")
        if not context:is_composing() then

            -- logger.debug("input_string: " .. context:get_property("input_string"))
            if context:get_option("search_move") then
                logger.debug("update_notifier通知:is_composing为false, 退出搜索模式")
                context:set_option("search_move", false)
                context:set_property("search_move_str", "")
            end

            -- 清空云输入法的状态
            if context:get_property("cloud_convert_flag") == "1" then
                context:set_property("cloud_convert_flag", "0")
            end

            if context:get_property("cloud_convert") == "1" then
                context:set_property("cloud_convert", "0")
            end

            -- 清空反引号英文模式的状态
            if context:get_property("rawenglish_prompt") == "1" then
                context:set_property("rawenglish_prompt", "0")
            end

            -- 清空ai回复消息模式的状态
            if context:get_property("intercept_select_key") == "1" then
                context:set_property("intercept_select_key", "0")
            end

            -- 清空云输入法获取状态local get_cloud_stream = context:get_property("get_cloud_stream")
            if context:get_property("get_cloud_stream") ~= "idle" then
                context:set_property("get_cloud_stream", "idle")
            end
            -- (因为ai传输是跨两次输入的,所以不能在这里清空,否则会导致失效)清空ai流式传输状态
            -- 如果内容
            local ai_replay_stream = context:get_property("ai_replay_stream")
            if context:get_property("get_ai_stream") ~= "idle" and
                (ai_replay_stream ~= "" and ai_replay_stream ~= "等待回复...") then
                -- logger.debug("ai_replay_stream: " .. ai_replay_stream)
                context:set_property("get_ai_stream", "idle")
            end

        end

        -- local input = context.input or ""
        -- local caret_pos = context.caret_pos
        -- local is_composing = context:is_composing()
        -- logger.debug(string.format("输入变化: '%s', 光标:%d, 组合:%s", 
        --                    input, caret_pos, tostring(is_composing)))

    end)

    env.property_update_notifier = context.property_update_notifier:connect(function(context)
        -- 属性更新通知：当 client_app 变化时，将 tcp_socket 的全局开关应用到新会话
        local current_app = context:get_property("client_app")
        -- if current_app ~= "" then
        --     logger.debug("current_app: " .. current_app)
        -- end

        if previous_client_app == "" and current_app ~= "" then
            previous_client_app = current_app
            logger.debug("第一次设置prev_app(env):  current_app: " .. current_app)

        elseif current_app ~= "" and previous_client_app ~= "" and current_app ~= previous_client_app then
            logger.debug("current_app ~= prev_app: previous_client_app(env): " .. previous_client_app ..
                             " current_app: " .. current_app)

            previous_client_app = current_app
            -- 切换到新会话后，应用一次全局开关（覆盖各会话差异，保持一致）
            if tcp_socket and tcp_socket.apply_global_options_to_context then
                local applied = tcp_socket.apply_global_options_to_context(context)
                if applied > 0 then
                    logger.info("切换会话时应用全局开关数量: " .. tostring(applied))
                end
            end
        elseif context:get_property("config_update_flag") == "1" then
            logger.debug("config_update_flag: " .. context:get_property("config_update_flag"))
            if tcp_socket and tcp_socket.apply_global_options_to_context then
                local applied = tcp_socket.apply_global_options_to_context(context)
                if applied > 0 then
                    logger.info("切换会话时应用全局开关数量: " .. tostring(applied))
                end
            end
            -- 配置更新了, 清空config_update_flag
            context:set_property("config_update_flag", "0")

        else
            return
        end

        -- 切换到新的应用中后, 检查一次app_options当中的开关选项和当前的开关选项是否一致,如果不一致则切换成配置中设置的结果
        -- 正常应该是检测到app变化之后再执行, 当前放在这里相当于每次都执行
        -- 对app_options当中的每个应用选项进行检查
        for _, app_key in ipairs(smart_cursor_processor.app_options:keys()) do
            -- 将current_app中的"."替换成"_"
            current_app = current_app:gsub("%.", "_")
            if app_key == current_app then
                -- logger.debug("current_app和app_key相同, 开始匹配开关状态")
                local item = smart_cursor_processor.app_options:get(app_key)
                if item and item.get_map then
                    local app_map = item:get_map()
                    for _, k in ipairs(app_map:keys()) do
                        local value = config:get_bool("app_options/" .. app_key .. "/" .. k)
                        logger.debug(" k: " .. k .. "value: " .. tostring(value))
                        -- 这里应该是判断这个value和当前context中的开关状态是否一致,如果不一致则切换成配置中设置的结果
                        if k ~= "__label__" and value ~= context:get_option(k) then
                            context:set_option(k, value)
                            logger.debug("set_option k: " .. k .. " value: " .. tostring(value))
                        end
                    end
                end
            end
        end

    end)
    -- env.unhandled_key_notifier = context.unhandled_key_notifier:connect(function(context)
    --     -- 只要出发了上屏通知,就关闭搜索模式
    --     -- 退出搜索模式
    --     logger.debug("触发unhandled_key_notifier更新通知")

    -- end)

    -- env.custom_update_notifier = context.update_notifier:connect(function(context)
    --     -- 防止递归调用的标志
    --     if context:get_property("tcp_sync_in_progress") == "true" then
    --         logger.debug("tcp_socket.sync_with_server() 正在进行中，跳过本次调用")
    --         return
    --     end

    --     if tcp_socket then
    --         -- 设置标志，表示正在进行同步
    --         context:set_property("tcp_sync_in_progress", "true")

    --         local success, err = pcall(function()
    --             tcp_socket.sync_with_server()
    --         end)

    --         if not success then
    --             logger.error("tcp_socket.sync_with_server() 调用失败: " .. tostring(err))
    --         end

    --         -- 清除标志
    --         context:set_property("tcp_sync_in_progress", "false")
    --     else
    --         logger.debug("sync_module为nil，跳过状态更新")
    --     end
    -- end)

    env.unhandled_key_notifier = context.unhandled_key_notifier:connect(function(context)
        logger.debug("unhandled_key_notifier触发： sync_with_server和服务端同步信息")
        tcp_socket.sync_with_server(env, true)
    end)

    env.new_update_notifier = context.update_notifier:connect(function(context)
        -- 每次上下文更新都和服务端同步
        logger.debug("sync_with_server和服务端同步信息")
        tcp_socket.sync_with_server(env, true)

        -- 判断is_composing状态是否发生了变化
        local current_is_composing = context:is_composing()
        local previous_is_composing = context:get_property("previous_is_composing")

        -- 如果没有记录过previous状态，则初始化
        if previous_is_composing == "" then
            context:set_property("previous_is_composing", tostring(current_is_composing))
            logger.debug("初始化 previous_is_composing: " .. tostring(current_is_composing))
            return
        end
        -- 转换字符串为布尔值
        local prev_state = (previous_is_composing == "true")
        -- 检查状态是否发生变化
        if current_is_composing ~= prev_state then
            logger.debug("is_composing状态发生变化: " .. tostring(prev_state) .. " -> " ..
                             tostring(current_is_composing))
            -- 更新记录的状态
            context:set_property("previous_is_composing", tostring(current_is_composing))

        end
        -- 检查从非输入状态变成输入状态
        if current_is_composing and not prev_state then
            local input = context.input
            logger.debug("从非输入状态,变成输入状态")
            -- 开始判断连续ai对话分支内容
            -- context:set_property("keepon_chat_trigger", "translate_ai_chat")
            local keepon_chat_trigger = context:get_property('keepon_chat_trigger')
            logger.info("keepon_chat_trigger: " .. keepon_chat_trigger)
            -- 属性存在值代表要进入自动ai对话模式

            logger.info("input_string: " .. context:get_property("input_string"))
            if smart_cursor_processor.keep_input_uncommit and context:get_property("input_string") ~= "" then
                if #input == 1 then -- and not first_segment:has_tags("ai_reply") 
                    logger.info("input: " .. input)
                    context.input = context:get_property("input_string") .. input
                    -- context:refresh_non_confirmed_composition()
                end
            elseif keepon_chat_trigger ~= "" then
                local segmentation = context.composition:toSegmentation()
                local last_segment = segmentation:back()
                local first_segment = segmentation:get_at(0)
                logger.info("keepon_chat_trigger: " .. keepon_chat_trigger)

                -- 测试另外一种方案,在前边添加字母"a:"这类的内容。
                -- 思路: 当keepon_chat_trigger属性中存在值的时候,应该通过这个属性获取到 chat_trigger
                local chat_trigger_name = smart_cursor_processor.chat_triggers[keepon_chat_trigger]
                logger.info("chat_trigger_name: " .. chat_trigger_name)
                -- 然后当用户输入第一个字母的时候,应该将chat_trigger_name添加到input的最前边. 
                -- 第一个字母也伴随着is_composing状态的改变, 也就是说监控到is_composing变成True, 然后再去添加chat_trigger_name?
                -- 还是应该判断,当从非输入状态变成输入状态,则应该进行添加,这样也不用判断了
                if #input == 1 then -- and not first_segment:has_tags("ai_reply") 
                    logger.info("input: " .. input)
                    context.input = chat_trigger_name .. input
                    -- context:refresh_non_confirmed_composition()
                end

            end

        end
    end)

    -- env.new_update_notifier = context.update_notifier:connect(function(context)

    --     -- 判断is_composing状态是否发生了变化
    --     local current_is_composing = context:is_composing()
    --     local previous_is_composing = context:get_property("previous_is_composing")

    --     -- 如果没有记录过previous状态，则初始化
    --     if previous_is_composing == "" then
    --         context:set_property("previous_is_composing", tostring(current_is_composing))
    --         logger.debug("初始化 previous_is_composing: " .. tostring(current_is_composing))
    --         return
    --     end

    --     -- 转换字符串为布尔值
    --     local prev_state = (previous_is_composing == "true")

    --     -- 检查状态是否发生变化
    --     if current_is_composing ~= prev_state then
    --         logger.debug("is_composing状态发生变化: " .. tostring(prev_state) .. " -> " ..
    --                          tostring(current_is_composing))
    --         logger.debug("从输入状态变化，触发发送当前开关信息.")
    --         if tcp_socket then
    --             -- 传递option信息
    --             tcp_socket.sync_with_server(env, true)
    --         else
    --             logger.debug("sync_module为nil，跳过状态更新")
    --         end
    --         -- 更新记录的状态
    --         context:set_property("previous_is_composing", tostring(current_is_composing))

    --     end

    --     -- 检查从非输入状态变成输入状态
    --     if current_is_composing and not prev_state then
    --         logger.debug("从非输入状态,变成输入状态")
    --         -- 开始判断连续ai对话分支内容
    --         -- context:set_property("keepon_chat_trigger", "translate_ai_chat")
    --         local keepon_chat_trigger = context:get_property('keepon_chat_trigger')
    --         logger.info("keepon_chat_trigger: " .. keepon_chat_trigger)
    --         -- 属性存在值代表要进入自动ai对话模式
    --         if keepon_chat_trigger ~= "" then
    --             local segmentation = context.composition:toSegmentation()
    --             local last_segment = segmentation:back()
    --             local first_segment = segmentation:get_at(0)
    --             logger.info("keepon_chat_trigger: " .. keepon_chat_trigger)
    --             local input = context.input

    --             -- 测试另外一种方案,在前边添加字母"a:"这类的内容。
    --             -- 思路: 当keepon_chat_trigger属性中存在值的时候,应该通过这个属性获取到 chat_trigger
    --             local chat_trigger_name = smart_cursor_processor.chat_triggers[keepon_chat_trigger]
    --             logger.info("chat_trigger_name: " .. chat_trigger_name)
    --             -- 然后当用户输入第一个字母的时候,应该将chat_trigger_name添加到input的最前边. 
    --             -- 第一个字母也伴随着is_composing状态的改变, 也就是说监控到is_composing变成True, 然后再去添加chat_trigger_name?
    --             -- 还是应该判断,当从非输入状态变成输入状态,则应该进行添加,这样也不用判断了
    --             if #input == 1 then -- and not first_segment:has_tags("ai_reply") 
    --                 logger.info("input: " .. input)
    --                 context.input = chat_trigger_name .. input
    --                 -- context:refresh_non_confirmed_composition()
    --             end

    --         end
    --     end
    -- end)

end

-- 向右移动光标直到遇到标点符号
function smart_cursor_processor.move_to_next_punctuation(env)
    local engine = env.engine
    local context = engine.context
    -- 应该是剩余的segment_input吧? 
    local input = context.input
    local segmentation = context.composition:toSegmentation()
    -- debug_utils.print_segmentation_info(segmentation, logger)

    if not segmentation then
        return false
    end

    local current_start_position = segmentation:get_current_start_position()
    local current_end_position = segmentation:get_current_end_position()
    local current_segment_length = segmentation:get_current_segment_length()
    -- local segment_input = input:sub(current_start_position + 1, current_end_position)

    logger.info("当前片段开始位置current_start_position: " .. current_start_position)
    logger.info("当前片段结束位置current_end_position: " .. current_end_position)
    logger.info("当前输入: " .. input)

    -- 从当前位置开始向右查找标点符号
    -- 1. 如果当前光标处于末端, 则应该移动到从前向后的第一个标点符号结束
    -- 2. 如果光标当前处于最前端,则应该移动到从前向后的第一个标点符号结束
    -- 3. 如果光标处于其他位置,则应该移动到当前向后第一个标点符号结束
    -- 分几种情况吧：如果是在末尾, 循环判断标点符号在位置5,则移动5+1
    -- 如果是在最前端, 在移动5
    -- 如果是在第一个句子中, 例如 ni | hk wo de,mg xd jq ui ni, 这是current_end_position为2?
    -- 需要移动6位, 循环从current_end_position开始, #input结束
    -- 接下来考虑特殊情况,在最后一句当中, 向后移动发现没有标点符号了,怎么办? 移动到最后吧

    -- 如果本来就在末尾,则移动到第一句标点符号结束, 先移动到第一个,再执行后续移动
    local caret_pos = context.caret_pos
    logger.info("当前光标位置: " .. caret_pos)
    logger.info("caret_pos: " .. caret_pos .. " #input: " .. #input)
    if caret_pos == #input then
        caret_pos = current_start_position
        -- 这里应该直接
        logger.info("光标在末尾，直接从开头位置开始计算, 但并不需要真实移动光标: " ..
                        current_start_position)
    end

    local found_punctuation = false
    for i = caret_pos + 1, #input, 1 do
        -- 提取出当前索引对应字符
        local char = input:sub(i, i)
        logger.info("检查字符 " .. i .. ": " .. char)

        if env.punctuation_chars and env.punctuation_chars[char] then
            logger.info("找到标点符号 '" .. char .. "' 在位置 " .. i)

            -- 直接设置光标位置到标点符号后面
            context.caret_pos = i
            logger.info("直接设置光标位置到: " .. i)

            found_punctuation = true
            return true
        end
    end

    -- 如果没有找到标点符号，移动到末尾
    if not found_punctuation then
        logger.info("未找到标点符号，移动到末尾")
        context.caret_pos = #input
        logger.info("直接设置光标位置到末尾: " .. #input)
    end
    return true
end

-- 向左移动光标直到遇到标点符号
function smart_cursor_processor.move_to_prev_punctuation(env)
    local engine = env.engine
    local context = engine.context
    -- 应该是剩余的segment_input吧? 
    local input = context.input
    local segmentation = context.composition:toSegmentation()
    -- debug_utils.print_segmentation_info(segmentation, logger)

    if not segmentation then
        return false
    end

    local current_start_position = segmentation:get_current_start_position()
    local current_end_position = segmentation:get_current_end_position()
    local current_segment_length = segmentation:get_current_segment_length()
    local caret_pos = context.caret_pos
    logger.info("当前光标位置: " .. caret_pos)

    logger.info("当前片段开始位置current_start_position: " .. current_start_position)
    logger.info("当前片段结束位置current_end_position: " .. current_end_position)
    logger.info("当前输入: " .. input)

    -- 从当前位置开始向左查找标点符号
    -- 1. 如果当前光标处于末端, 则应该移动到前一个标点符号结束
    -- 2. 如果光标当前处于最前端,则应该移动到最后
    -- 3. 如果光标处于第一句话中间, 则应该移动到开头
    -- 如果光标处于第二句话中间,则应该移动到前一个标点符号结束
    -- 
    -- 
    -- 如果是在第一个句子中, 例如 ni | hk wo de,mg xd jq ui ni
    -- ni | hk wo de,mg xd jq, ui ni 移动后应该是:  | ni hk wo de,mg xd jq, ui ni
    -- ni hk wo de,mg | xd jq, ui ni 移动后应该是:  ni hk wo de,| mg xd jq, ui ni
    -- ni hk wo de,mg xd jq, ui ni |  移动后应该是:  ni hk wo de, mg xd jq,| ui ni
    -- | ni hk wo de,mg xd jq, ui ni   移动后应该是:  ni hk wo de, mg xd jq,ui ni | 

    -- 如果本来就在末尾,则移动到第一句标点符号结束, 先移动到第一个,再执行后续移动
    logger.info("caret_pos: " .. caret_pos .. " #input: " .. #input)
    if caret_pos == current_start_position then
        context.caret_pos = #input
        logger.info("光标在开头，直接设置到末尾位置: " .. #input)
        return true
    end

    local found_punctuation = false
    -- 从当前光标位置向前移动, 每次移动一格, 然后判断当前光标是否标点符号
    for i = caret_pos - 1, current_start_position, -1 do
        -- 提取出当前索引对应字符
        local char = input:sub(i, i)
        logger.info("检查字符 " .. i .. ": " .. char)

        if env.punctuation_chars and env.punctuation_chars[char] then
            logger.info("找到标点符号 '" .. char .. "' 在位置 " .. i)

            -- 直接设置光标位置到标点符号后面
            context.caret_pos = i
            logger.info("直接设置光标位置到: " .. i)

            found_punctuation = true
            return true
        end
    end

    -- 如果没有找到标点符号，移动到开头
    if not found_punctuation then
        logger.info("未找到标点符号，移动到开头")
        context.caret_pos = current_start_position
        logger.info("直接设置光标位置到开头: " .. current_start_position)
    end
    return true
end

-- 基于 vertices 分割点进行智能光标移动（新版本，使用spans_manager）
function smart_cursor_processor.move_by_spans_manager(env, direction)
    local engine = env.engine
    local context = engine.context
    local caret_pos = context.caret_pos

    logger.info("开始基于spans_manager进行光标移动")

    -- 使用spans_manager获取下一个光标位置
    -- 这里传入当前光标位置
    local next_pos
    if direction == "next" then
        next_pos = spans_manager.get_next_cursor_position(context, caret_pos)
    elseif direction == "prev" then
        next_pos = spans_manager.get_prev_cursor_position(context, caret_pos)
    end

    if next_pos ~= nil then
        logger.info("移动光标从 " .. caret_pos .. " 到 " .. next_pos)
        context.caret_pos = next_pos
        return true
    else
        logger.info("spans_manager未返回有效的下一个位置")
        return false
    end
end

function smart_cursor_processor.func(key, env)
    local engine = env.engine
    local context = engine.context
    -- 返回值常量定义
    local kRejected = 0 -- 表示按键被拒绝
    local kAccepted = 1 -- 表示按键已被处理
    local kNoop = 2 -- 表示按键未被处理,继续传递给下一个处理器

    local key_repr = key:repr()
    logger.info("key_repr: " .. key_repr)

    -- 根据当前应用与 app_options 中的 vim_mode 配置，同步 ascii_mode 状态（按应用独立文件）
    local current_app = context:get_property("client_app")
    if current_app ~= "" and smart_cursor_processor.app_options then
        -- 将 client_app 中的 . 替换为 _，以匹配 app_options 的键
        local app_key = current_app:gsub("%.", "_")

        -- 读取该 app 的 vim_mode 开关
        local config = engine.schema.config
        -- 获取这个app的配置
        local item = smart_cursor_processor.app_options:get(app_key)
        local vim_mode_enabled = false
        if item then
            vim_mode_enabled = config:get_bool("app_options/" .. app_key .. "/vim_mode")
            logger.debug("app: " .. app_key .. " vim_mode 状态: " .. tostring(vim_mode_enabled))
        end

        if vim_mode_enabled then
            -- 读取用户目录下 /Users/.../Library/Rime/.{app_key}_vim_mode 文件
            local user_data_dir = rime_api.get_user_data_dir()
            local vim_mode_path = user_data_dir .. "/log" .. "/." .. app_key .. "_vim_mode"
            -- logger.debug("vim_mode_path: " .. vim_mode_path)

            local mode_file, open_err = io.open(vim_mode_path, "r")
            if not mode_file then
                logger.debug("无法打开 vim_mode 文件: " .. vim_mode_path .. " 错误: " .. tostring(open_err))
            else
                local current_vim_mode = mode_file:read("*l")
                mode_file:close()
                -- 记录下来当前应用的vim模式

                local previous_mode = smart_cursor_processor.app_vim_mode_state[app_key]
                if previous_mode ~= current_vim_mode then
                    smart_cursor_processor.app_vim_mode_state[app_key] = current_vim_mode
                    logger.debug("app: " .. app_key .. " 模式变化: " .. tostring(previous_mode) .. " -> " .. tostring(current_vim_mode))
                    if current_vim_mode == "normal_mode" then
                        -- normal 模式默认切换到 ascii 输入
                        local ascii_mode = context:get_option("ascii_mode")
                        if ascii_mode == false then
                            context:set_option("ascii_mode", true)
                            -- logger.debug("检测到 normal_mode, 切换 ascii_mode 为 true")
                        end
                    elseif current_vim_mode == "insert_mode" then
                        -- insert 模式保持中文输入
                        local ascii_mode = context:get_option("ascii_mode")
                        if ascii_mode == true then
                            context:set_option("ascii_mode", false)
                            -- logger.debug("检测到 insert_mode, 切换 ascii_mode 为 false")
                        end
                    end
                end
            end
        end
    end

    -- update_global_option_state为true，则应用一次全局开关（覆盖各会话差异，保持一致）
    -- if tcp_socket and tcp_socket.update_global_option_state then
    --     local applied = tcp_socket.apply_global_options_to_context(context)
    --     if applied > 0 then
    --         logger.info("切换应用全局开关数量: " .. tostring(applied))
    --     end
    -- end
    -- 

    if not key or not context:is_composing() then
        return kNoop
    end
    local composition = context.composition

    -- logger.info("开始测试: ")
    -- local user_data_dir = rime_api.get_user_data_dir()
    -- local config = engine.schema.config
    -- -- 载入squirrel.yaml
    -- config:load_from_file(user_data_dir .. "/" .. "squirrel.yaml")
    -- local color_scheme = config:get_string("style/color_scheme") 

    -- logger.debug("color_scheme: " .. tostring(color_scheme))
    -- if key_repr == "t" then
    --     config:set_string("style/color_scheme", "mint_light_green")
    --     local color_scheme = config:get_string("style/color_scheme") 
    --     logger.debug("color_scheme: " .. tostring(color_scheme))
    -- end 

    local search_move_prompt = " ▶ [搜索模式:] "

    local success, result = pcall(function()

        -- local segmentation = context.composition:toSegmentation()
        -- debug_utils.print_segmentation_info(segmentation, logger)

        ------------------------------------------------------------------------
        -- 开始进入搜索模式
        if context:get_option("search_move") then

            -- 判断是否为英文字母或标点符号
            local is_valid_char = false
            if key_repr == "Tab" then
                is_valid_char = true
            elseif key_repr:match("^[a-zA-Z]$") then
                -- 英文字母
                is_valid_char = true
            elseif key_repr:match("^[%p]$") then
                -- 标点符号（不包含空格）
                is_valid_char = true
            end

            local segment = nil
            if (not composition:empty()) then
                segment = composition:back()
            end

            -- 如果是有效字符，执行搜索模式逻辑
            if is_valid_char then

                -- 在segment后面添加prompt
                if segment then

                    -- 这里有问题, 如果说其他程序替换了 prompt 怎么办                
                    -- if segment.prompt:sub(1, #search_move_prompt) == search_move_prompt then

                    -- 2. 继续输入的字母, 被拦截,然后将这个字母添加到prompt当中去, 获取也可以不添加,反正都跳过去了.
                    -- 3. 并且将这个字母记录下来, 在当前segment_input当中,从头搜索匹配的字母,然后进行跳转.再输入一个字母则有两个字母,用这两个字母进行跳转.
                    -- 4. 如果存在多个重复的搜索匹配项,怎么办？按tab键可以在多个重复项之间跳转.
                    -- 5. 如果搜索到的位置试想要跳转到的位置, 按下回车键,或者再次按下ctrl+f键退出搜索模式. 或者直接用空格进行选词,选词之后也会自动退出搜索模式

                    local add_search_move_str = ""
                    if key_repr == "Tab" then
                        local search_move_str = context:get_property("search_move_str")
                        add_search_move_str = search_move_str
                        logger.info("搜索模式中Tab, add_search_move_str不变: " .. add_search_move_str)
                    else
                        -- search_move_str就是搜索的字符串
                        local search_move_str = context:get_property("search_move_str")
                        add_search_move_str = search_move_str .. key_repr

                        context:set_property("search_move_str", add_search_move_str)
                        logger.info("add_search_move_str: " .. add_search_move_str)
                    end

                    -- segment.prompt = string.format(" ▶ [搜索模式:%s] ", add_search_move_str)
                    -- logger.info("更新搜索模式提示: " .. segment.prompt)

                    -- 移动光标位置,只在当前segment（未确认部分）中搜索
                    local input = context.input

                    local segmentation = context.composition:toSegmentation()

                    local confirmed_pos = segmentation:get_confirmed_position()
                    local confirmed_pos_input = input:sub(confirmed_pos + 1)
                    logger.info("confirmed_pos_input: " .. confirmed_pos_input)
                    local current_caret_pos = context.caret_pos

                    local caret_relative_pos = current_caret_pos - confirmed_pos

                    logger.info("光标在剩余input内的相对位置: " .. caret_relative_pos)

                    local search_start_pos = nil
                    -- 如果是tab模式,则光标移动到当前单词后面匹配, 如果不是tab模式,则光标移动到当前单词后面进行匹配.
                    if key_repr == "Tab" then
                        -- 对于tab模式,应该从当前光标位置开始搜索下一个符合的, 所以向后移动一位开始搜索
                        -- 从当前光标位置开始向后搜索
                        search_start_pos = caret_relative_pos + 1
                        -- 当tab键, 不用移动
                    else
                        -- 对于普通模式,应该是添加了一个字符串, 如果原来是"", 则现在变成了"w"
                        -- 如果原来是"w",则变成了"wo"
                        -- 应该从头开始搜索即可,只搜索第一个
                        -- 向前移动搜索字符长度个数 - 1
                        -- ni hk wo de wo 光标位置10, 搜索wo, 
                        search_start_pos = 1
                    end

                    local found_pos = text_splitter.find_text_skip_rawenglishs_with_wrap(confirmed_pos_input,
                        add_search_move_str, search_start_pos, logger)
                    if found_pos then
                        local move_pos = confirmed_pos + found_pos - 1 + #add_search_move_str
                        context.caret_pos = move_pos
                        logger.info("在confirmed_pos_input内找到搜索字符串 '" .. add_search_move_str ..
                                        "' 在相对位置 " .. found_pos .. "，移动光标位置 " .. move_pos)
                    else
                        -- 当没有搜索到不会触发重新分词,需要自己添加prompt
                        segment.prompt = string.format(" ▶ [搜索模式:%s] ", add_search_move_str)
                        logger.info(
                            "在当前confirmed_pos_input内未找到搜索字符串 '" .. add_search_move_str .. "'")
                    end

                    -- local found_pos = string.find(confirmed_pos_input, add_search_move_str, search_start_pos, true)

                    -- if found_pos then
                    --     local move_pos = confirmed_pos + found_pos - 1 + #add_search_move_str
                    --     context.caret_pos = move_pos
                    --     logger.info("在confirmed_pos_input内找到搜索字符串 '" .. add_search_move_str ..
                    --                     "' 在相对位置 " .. found_pos .. "，移动光标位置 " .. move_pos)
                    -- else
                    --     -- 没找到，从segment开头搜索
                    --     found_pos = string.find(confirmed_pos_input, add_search_move_str, 1, true)
                    --     if found_pos then
                    --         local move_pos = confirmed_pos + found_pos - 1 + #add_search_move_str
                    --         context.caret_pos = move_pos
                    --         logger.info("从confirmed_pos_input开头搜索找到字符串 '" .. add_search_move_str ..
                    --                         "' 在相对位置 " .. found_pos .. "，移动光标位置 " .. move_pos)
                    --     else
                    --         -- 当没有搜索到不会触发重新分词,需要自己添加prompt
                    --         segment.prompt = string.format(" ▶ [搜索模式:%s] ", add_search_move_str)
                    --         logger.info("在当前confirmed_pos_input内未找到搜索字符串 '" ..
                    --                         add_search_move_str .. "'")
                    --     end
                    -- end

                    return kAccepted
                    -- else
                    --     logger.debug("退出搜索模式")
                    --     context:set_option("search_move", false)

                end

            elseif key_repr == "Escape" then
                -- 退出搜索模式
                logger.debug("退出搜索模式")
                context:set_option("search_move", false)
                -- segment.prompt = ""
                context:set_property("search_move_str", "")
                return kAccepted
            elseif key_repr == "BackSpace" then
                logger.debug("删除一个搜索字符串")
                local search_move_str = context:get_property("search_move_str")
                local delete_search_move_str = search_move_str:sub(1, -2)
                context:set_property("search_move_str", delete_search_move_str)
                logger.info("delete_search_move_str: " .. delete_search_move_str)
                segment.prompt = string.format(" ▶ [搜索模式:%s] ", delete_search_move_str)
                return kAccepted
            elseif key_repr == "Return" then
                -- 退出搜索模式
                logger.debug("退出搜索模式")
                context:set_option("search_move", false)
                -- segment.prompt = ""
                context:set_property("search_move_str", "")
                return kAccepted
            else
                logger.info("非有效搜索字符，跳过搜索模式处理")
            end

        end

        -- 如果是ac:nihk 那么匹配不到中文, 也就是script_text_chinese为空, going_commit_text只有候选词
        -- local script_text = context:get_script_text()
        -- logger.info("script_text: " .. script_text)
        -- local commit_text = context:get_commit_text()
        -- logger.info("commit_text: " .. commit_text)
        -- local get_preedit = context:get_preedit()
        -- logger.info("get_preedit.text: " .. get_preedit.text)

        ------------------------------------------------------------------------
        -- -- 判断只要input发生了变化, 就清空属性
        -- local my_spans_input = context:get_property("my_spans_input")
        -- -- 如果等于空,则什么都不做, 如果不等于空,但是等于context.input 说明没有变化,不用清空
        -- if my_spans_input ~= "" and context.input ~= my_spans_input then
        --     -- 输入已变化，清空spans相关属性
        --     logger.debug("输入my_spans_input已变化, 清空my_spans_vertices和my_spans_input")
        --     context:set_property("my_spans_vertices", "")
        --     context:set_property("my_spans_input", "")
        -- end

        ------------------------------------------------------------------------

        -- if spans_manager.get_spans(context) then
        --     logger.debug("当前存在spans信息")
        -- else
        --     logger.debug("当前不存在spans信息")
        -- end

        -- 检测自定义的智能移动快捷键
        if key_repr == "Tab" then
            -- 尝试使用新的spans_manager进行光标移动
            if spans_manager.get_spans(context) then
                logger.debug("获取到spans信息")
                if smart_cursor_processor.move_by_spans_manager(env, "next") then
                    return kAccepted
                end
            end
            return kNoop
        elseif key_repr == "Left" then
            -- 尝试使用新的spans_manager进行光标移动
            if spans_manager.get_spans(context) then
                if smart_cursor_processor.move_by_spans_manager(env, "prev") then
                    return kAccepted
                end
            end
            return kNoop
        elseif key_repr == "Escape" then
            -- 记录一个属性或者是直接清空
            if smart_cursor_processor.keep_input_uncommit then
                logger.debug("清空属性")
                context:set_property("input_string", "")
                logger.debug("清空input_string, 结束输入context:clear()")
                context:clear()
                return kAccepted
            end

        elseif key_repr == smart_cursor_processor.paste_to_input then
            -- 粘贴命令, 向服务器请求粘贴板中的文本内容get_clipboard
            if tcp_socket then
                logger.debug("🍴通过TCP发送get_clipboard命令到Python服务端")
                local paste_success = tcp_socket.sync_with_server(env, false, false, "get_clipboard", "", 0.2)

                if paste_success then
                    logger.debug("✅ get_clipboard令发送成功")
                else
                    logger.error("❌ get_clipboard命令发送失败")
                end
            else
                logger.warn("⚠️ TCP模块未加载，无法发送粘贴命令")
            end
            return kAccepted

        elseif key_repr == smart_cursor_processor.move_prev_punct then
            logger.debug("触发向左智能移动")
            if smart_cursor_processor.move_to_prev_punctuation(env) then
                return kAccepted
            end
        elseif key_repr == smart_cursor_processor.move_next_punct then
            logger.debug("触发向右智能移动")
            if smart_cursor_processor.move_to_next_punctuation(env) then
                return kAccepted
            end
        elseif key_repr == smart_cursor_processor.search_move_cursor then
            -- 获得队尾的 Segment 对象
            local segment = composition:back()

            if not context:get_option("search_move") then
                logger.debug("进入搜索模式")
                context:set_option("search_move", true)

                if segment then
                    if segment.prompt ~= search_move_prompt then
                        segment.prompt = search_move_prompt
                        context:set_property("search_move_str", "")
                        logger.info("设置搜索模式提示: " .. search_move_prompt)
                    end

                end
            else
                logger.debug("退出搜索模式")
                context:set_option("search_move", false)
                if segment then
                    -- segment.prompt = ""
                    context:set_property("search_move_str", "")
                end
            end

            return kAccepted

        end

        return kNoop
    end)

    if not success then
        logger.error("智能光标移动处理器错误: " .. tostring(result))
        return kNoop
    end

    return result or kNoop
end

function smart_cursor_processor.fini(env)
    logger.info("智能光标移动处理器结束运行")

    -- 清理TCP同步标志
    local context = env.engine.context
    if context then
        context:set_property("tcp_sync_in_progress", "false")
    end

    if env.update_notifier then
        env.update_notifier:disconnect()
    end

    if env.custom_update_notifier then
        env.custom_update_notifier:disconnect()
    end

    if env.new_update_notifier then
        env.new_update_notifier:disconnect()
    end

    if env.commit_notifier then
        env.commit_notifier:disconnect()
    end

    if env.unhandled_key_notifier then
        env.unhandled_key_notifier:disconnect()
    end

    if env.select_notifier then
        env.select_notifier:disconnect()
    end

    if env.property_update_notifier then
        env.property_update_notifier:disconnect()
    end
    -- RimeTcpServer.stop()
end

return smart_cursor_processor
