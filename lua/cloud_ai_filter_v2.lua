-- lua/baidu_filter.lua 修改成filter版本,通过百度云接口获取云输入法拼音词组,并添加到候选词中第一位中来
-- 百度云输入获取filter版本
-- - 20250718打算整个百度云输入获取和AI输入法的功能, 两个恐怕必须要放在一起，不太好拆开开发.
local json = require("json")

-- 引入日志工具模块
local logger_module = require("logger")
-- 引入文本切分模块
local text_splitter = require("text_splitter")
local debug_utils = require("debug_utils")
-- 引入spans管理模块
local spans_manager = require("spans_manager")

-- 创建当前模块的日志记录器
local logger = logger_module.create("cloud_ai_filter_v2", {
    enabled = true, -- 启用日志以便测试
    unique_file_log = false, -- 启用日志以便测试
    log_level = "DEBUG"
})

-- 添加 ARM64 Homebrew 的 Lua 路径
local function setup_lua_paths()
    -- 保存原始路径
    local original_path = package.path
    local original_cpath = package.cpath

    -- 添加 ARM64 Homebrew 路径
    package.path = package.path .. ";/opt/homebrew/share/lua/5.4/?.lua;/opt/homebrew/share/lua/5.4/?/init.lua"
    package.cpath = package.cpath .. ";/opt/homebrew/lib/lua/5.4/?.so;/opt/homebrew/lib/lua/5.4/?/core.so"

    logger.info("已添加 ARM64 Homebrew Lua 路径")
end

setup_lua_paths()

local tcp_socket = nil
local ok, err = pcall(function()
    tcp_socket = require("tcp_socket_sync")
end)
if not ok then
    logger.error("加载 tcp_socket_sync 失败: " .. tostring(err))
else
    logger.info("加载 tcp_socket_sync 成功")
    if tcp_socket then
        logger.info("sync_module不为nil")
    else
        logger.error("sync_module为nil，尽管require没有报错")
    end
end

-- 配置缓存机制
local config_cache = {}
local last_schema_id = nil

-- 读取AI助手配置的辅助函数
local function load_ai_config(env)
    local schema = env.engine.schema
    local config = schema.config
    local schema_id = schema.schema_id
    
    -- 如果schema没有变化且已有缓存，直接使用缓存并应用配置
    if last_schema_id == schema_id and config_cache.ai_assistant_config then
        logger.info("使用缓存的AI助手配置 (schema: " .. schema_id .. ")")
        local ai_assistant_config = config_cache.ai_assistant_config
        
        -- 应用配置到环境变量
        env.schema_name = ai_assistant_config.schema_name
        env.shuru_schema = ai_assistant_config.shuru_schema
        env.max_cloud_candidates = ai_assistant_config.max_cloud_candidates
        env.max_ai_candidates = ai_assistant_config.max_ai_candidates
        
        -- 将全局变量也保存到env中
        env.ziranma_mapping_config = ai_assistant_config.ziranma_mapping_config
        env.backtick_delimiter_before = ai_assistant_config.backtick_delimiter_before
        env.backtick_delimiter_after = ai_assistant_config.backtick_delimiter_after
        env.delimiter = ai_assistant_config.delimiter
        
        return ai_assistant_config
    end
    
    logger.info("重新加载AI助手配置 (schema: " .. schema_id .. ")")
    
    -- 读取 ai_assistant 配置
    local ai_assistant_config = {}
    
    -- 读取 behavior 配置
    ai_assistant_config.behavior = {}
    ai_assistant_config.behavior.prompt_chat = config:get_string("ai_assistant/behavior/prompt_chat")
    
    -- 动态读取 chat_triggers 配置
    ai_assistant_config.chat_triggers = {}
    ai_assistant_config.chat_names = {}
    
    -- 获取 chat_triggers 配置项
    local chat_triggers_config = config:get_map("ai_assistant/chat_triggers")
    if chat_triggers_config then
        -- 获取所有键名
        local trigger_keys = chat_triggers_config:keys()
        logger.info("找到 " .. #trigger_keys .. " 个触发器配置")
        
        -- 遍历配置中的所有触发器
        for _, trigger_name in ipairs(trigger_keys) do
            local trigger_value = config:get_string("ai_assistant/chat_triggers/" .. trigger_name)
            local chat_name = config:get_string("ai_assistant/chat_names/" .. trigger_name)
            
            if trigger_value then
                ai_assistant_config.chat_triggers[trigger_name] = trigger_value
                logger.info("AI触发器 - " .. trigger_name .. ": " .. trigger_value)
            end
            
            if chat_name then
                ai_assistant_config.chat_names[trigger_name] = chat_name
                logger.info("AI聊天名称 - " .. trigger_name .. ": " .. chat_name)
            end
        end
    else
        logger.warning("未找到 chat_triggers 配置")
    end
    
    -- 读取其他配置项并添加到ai_assistant_config中
    ai_assistant_config.schema_name = env.engine.schema.schema_name
    ai_assistant_config.shuru_schema = config:get_string("schema/my_shuru_schema") or ""
    
    -- 读取候选词数量限制配置
    ai_assistant_config.max_cloud_candidates = config:get_int("cloud_ai_filter/max_cloud_candidates") or 2
    ai_assistant_config.max_ai_candidates = config:get_int("cloud_ai_filter/max_ai_candidates") or 1
    
    -- 读取分隔符配置
    ai_assistant_config.delimiter = config:get_string("speller/delimiter"):sub(1, 1) or " "
    
    -- 读取反引号分隔符配置
    ai_assistant_config.backtick_delimiter_before = config:get_string("translator/backtick_delimiter_before") or ""
    ai_assistant_config.backtick_delimiter_after = config:get_string("translator/backtick_delimiter_after") or ""
    
    -- 加载自然码映射表
    ai_assistant_config.ziranma_mapping_config = config:get_map("speller/ziranma_to_quanpin")
    
    logger.info("云候选词最大数量: " .. ai_assistant_config.max_cloud_candidates)
    logger.info("AI候选词最大数量: " .. ai_assistant_config.max_ai_candidates)
    logger.info("当前分隔符: " .. ai_assistant_config.delimiter)
    
    -- 应用配置到环境变量
    env.schema_name = ai_assistant_config.schema_name
    env.shuru_schema = ai_assistant_config.shuru_schema
    env.max_cloud_candidates = ai_assistant_config.max_cloud_candidates
    env.max_ai_candidates = ai_assistant_config.max_ai_candidates
    
    -- 将全局变量也保存到env中
    env.ziranma_mapping_config = ai_assistant_config.ziranma_mapping_config
    env.backtick_delimiter_before = ai_assistant_config.backtick_delimiter_before
    env.backtick_delimiter_after = ai_assistant_config.backtick_delimiter_after
    env.delimiter = ai_assistant_config.delimiter
    
    -- 缓存配置
    config_cache.ai_assistant_config = ai_assistant_config
    last_schema_id = schema_id
    
    return ai_assistant_config
end

local translator = {}

local replace_punct_enabled = false

local function set_cloud_translate_flag(cand, context, delimiter)
    -- 这部分代码时检测输入的字符长度，通过检测中间有几个分隔符实现
    -- 检查当前是否正在组词状态（即用户正在输入但还未确认）
    local is_composing = context:is_composing()
    local preedit_text = cand.preedit
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
        logger.info("当前云输入提示标志: " .. context:get_property("cloud_translate_flag"))

        if context:get_property("cloud_translate_flag") == "0" then
            logger.info("云输入提示标志为 0, 设置为 1")
            context:set_property("cloud_translate_flag", "1")
            -- context:set_option("cloud_translate_prompt", true)
            logger.info("cloud_translate_flag 已设置为 1")

        end

    else
        -- 如果不在组词状态或没有达到触发条件,则重置提示选项
        logger.info("当前不在组词状态或未达到触发条件,云输入提示已重置")
        if context:get_property("cloud_translate_flag") == "1" then
            -- context:set_option("cloud_translate_prompt", false)
            context:set_property("cloud_translate_flag", "0")
            logger.info("cloud_translate_flag 已设置为 0")

        end
    end
end

function translator.init(env)
    -- 初始化时清空日志文件
    logger.clear()
    logger.info("云输入处理器初始化完成")

    -- 使用配置加载函数加载AI助手配置（配置会自动应用到env中）
    env.ai_assistant_config = load_ai_config(env)
    
    logger.info("AI助手配置加载完成")
end

function translator.func(translation, env)
    local engine = env.engine
    local context = engine.context
    local input = context.input

    -- 自动检查并清除过期的spans信息
    -- spans_manager.auto_clear_check(context, input)

    -- 检查输入是否包含标点符号或反引号
    -- local has_punctuation = confirmed_pos_input:match("[,.!?;:()%[%]<>/_=+*&^%%$#@~|%-`'\"']") ~= nil

    -- 包含标点符号或反引号，使用智能切分处理

    logger.info("cloud_translate: " .. tostring(context:get_option("cloud_translate")))

    local segment = ""

    -- 在segment后面添加prompt
    local composition = context.composition
    local segmentation = composition:toSegmentation()
    local confirmed_pos_input = ""
    if (not segmentation:empty()) then
        -- 获得队尾的 Segment 对象
        segment = segmentation:back()
        -- local confirmed_pos = segmentation:get_confirmed_position()
        -- logger.info("segmentation:get_confirmed_position(): " .. confirmed_pos)
        -- confirmed_pos_input = input:sub(confirmed_pos + 1)

        -- logger.info("confirmed_pos_input: " .. confirmed_pos_input)

        -- -- 提取第一段segment,看看标签是不是 "ai_talk", 如果是这个标签,则将这个片段变成segment.status ~= "kConfirmed" 
        -- -- 那么需要调整segmente_input
        -- debug_utils.print_segmentation_info(segmentation, logger)
        -- local first_segment = segmentation:get_at(0)
        -- if first_segment:has_tag("ai_talk") then
        --     local ai_segment_length = first_segment._end - first_segment.start
        --     logger.info("发现AI段落，长度: " .. ai_segment_length .. "，内容: " ..
        --                     input:sub(first_segment.start + 1, first_segment._end))

        --     first_segment.status = "kConfirmed" 
        --     debug_utils.print_segmentation_info(segmentation, logger)
        -- end
    else
        logger.info("segmentation:empty 为空,直接返回: " .. tostring(segmentation:empty()))
        return
    end

    --  判断segment:has_tag("ai_prompt") , 给前x个候选词添加comment, x的数量和lua/ai_assistant_segmentor.lua中trigger_prefix:sub(1, 1) == prompt_chat 的数量相同, 
    -- 将每一个匹配上的prompt_triggers, 添加到候选词的comment当中去
    
    -- 检查是否是AI提示段落
    local is_ai_prompt = segment:has_tag("ai_prompt")
    if is_ai_prompt then
        logger.info("检测到ai_prompt标签，开始处理AI提示候选词")
        
        -- 生成prompt_triggers列表，与ai_assistant_segmentor.lua中的逻辑一致
        local prompt_triggers = {}
        if env.ai_assistant_config and env.ai_assistant_config.behavior and env.ai_assistant_config.chat_triggers then
            local prompt_chat = env.ai_assistant_config.behavior.prompt_chat
            if prompt_chat then
                for trigger_name, trigger_prefix in pairs(env.ai_assistant_config.chat_triggers) do
                    if trigger_prefix:sub(1, 1) == prompt_chat then
                        local chat_name = env.ai_assistant_config.chat_names[trigger_name]
                        if chat_name then
                            local chat_name_clear = chat_name:gsub(":$", "")
                            table.insert(prompt_triggers, trigger_prefix .. chat_name_clear)
                        end
                    end
                end
                
                -- 排序以保持一致性
                table.sort(prompt_triggers)
                logger.info("生成了 " .. #prompt_triggers .. " 个提示触发器")
            end
        end
        
        -- 为候选词添加comment，每个候选词对应两个触发器
        local count = 0
        local max_rounds = math.floor(#prompt_triggers / 2)  -- 计算最大轮数
        local current_round = 0
        
        for cand in translation:iter() do
            current_round = current_round + 1
            
            -- 如果超过最大轮数，不再添加comment
            if current_round <= max_rounds then
                count = count + 2
                local trigger_info1 = prompt_triggers[count - 1]
                local trigger_info2 = prompt_triggers[count]
                
                -- 组合触发器信息
                local combined_trigger_info = trigger_info1
                if trigger_info2 then
                    combined_trigger_info = combined_trigger_info .. "  " .. trigger_info2
                end
                
                cand.comment = " " .. combined_trigger_info
                logger.info("为候选词添加提示: " .. combined_trigger_info)
            end
            
            yield(cand)
        end
        
        logger.info("AI提示候选词处理完成，共处理 " .. count .. " 个候选词")
        return
    end
    
 

    local segments = {}

    local first_original_cand = nil
    local original_preedit = ""
    local cand_text
    local cand_start = 0
    local cand_end = 0
    local cand_type = nil
    local cand_comment = ""
    local spans = nil

    -- logger.info("232")

    -- 首先检查是不是标点符号的候选词, 如果是直接确认第一个候选项,并返回.
    -- 先保存第一个原始候选词
    local long_candidates_table = {}
    local no_long_candidates_table = {}
    local count = 0
    for cand in translation:iter() do

        count = count + 1
        if count == 1 then
            first_original_cand = cand
            table.insert(long_candidates_table, cand)
            original_preedit = cand.preedit
            cand_text = cand.text
            cand_start = cand.start
            cand_end = cand._end
            cand_type = cand.type
            cand_comment = cand.comment
            logger.info(string.format(
                "原始候选词信息: text=%s, preedit=%s, start=%s, end=%s, type=%s, comment=%s",
                tostring(cand_text), tostring(original_preedit), tostring(cand_start), tostring(cand_end),
                tostring(cand_type), tostring(cand_comment)))
        end
        -- 只提取一个候选词
        break
    end

    if cand_type == "punct" or cand_type:sub(-7) == "ai_chat" then
        logger.info("cand_type: punct or ai_chat cand_text: " .. cand_text)
        -- 输出原始候选词
        yield(first_original_cand)

        for cand in translation:iter() do
            logger.info(string.format(
                "punct剩余选词信息: text=%s, preedit=%s, start=%s, end=%s, type=%s, comment=%s",
                tostring(cand.text), tostring(cand.preedit), tostring(cand.start), tostring(cand._end),
                tostring(cand.type), tostring(cand.comment)))
            yield(cand)
        end

        return        
    else
        logger.info("cand_type:  " .. cand_type)
    end

    -- cand_type ~= "user_table"  phrase 等等
    if not context:get_option("cloud_translate") then
        logger.info("not cloud_translate")
        -- 查看有没有云翻译的标识, 没有的话直接返回原有的候选词
        yield(first_original_cand) -- 输出原有第一个候选词
        set_cloud_translate_flag(first_original_cand, context, env.delimiter)
        for cand in translation:iter() do
            logger.info(string.format(
                "没有cloud_translate, 剩余选词信息: text=%s, preedit=%s, start=%s, end=%s, type=%s, comment=%s",
                tostring(cand.text), tostring(cand.preedit), tostring(cand.start), tostring(cand._end),
                tostring(cand.type), tostring(cand.comment)))
            yield(cand) -- 输出原有候选词
        end

        return

    end

    -- 代码走到这里,代表已经进入context:get_option("cloud_translate")成立分支
    logger.info("已经进入云输入法分支: cloud_translate " .. tostring(context:get_option("cloud_translate")))
    logger.info("cand_text: " .. cand_text .. " cand_type: " .. cand_type)
    context:set_option("cloud_translate", false) -- 重置选项，避免重复触发

    local ordered_candidates = {}

    local ok, err = pcall(function()
        -- 长度足够的候选词放入到long_candidates_table, 不够的放到no_long_candidates_table,只放一个

        for cand in translation:iter() do
            if cand._end == segment._end then
                table.insert(long_candidates_table, cand)
            else
                table.insert(no_long_candidates_table, cand)
                break
            end
        end

        local segment_input = input:sub(segment._start + 1, segment._end)
        logger.info("根据segment切片得到 segment_input: " .. segment_input)

        local parsed_data =
            tcp_socket.translate(env.schema_name, env.shuru_schema, segment_input, long_candidates_table)
        if parsed_data and (parsed_data.cloud_candidates or parsed_data.ai_candidates) then
            --[[ {
                "cloud_candidates": [
                    {
                    "field_name": "cloud_candidate_1",
                    "value": "你好",
                    "source": "baidu_cloud", 
                    "rank": 1
                    }
                ],
                "ai_candidates": [
                    {
                    "field_name": "ai_result",
                    "value": "你好",
                    "source": "ai_cloud",
                    "rank": 1
                    }
                ]
                } ]]
            -- 按照 candidates 数组的顺序提取候选词，添加数量限制
            local cloud_count = 0
            local ai_count = 0

            for i, candidate in ipairs(parsed_data.cloud_candidates) do
                if cloud_count >= env.max_cloud_candidates then
                    logger.info("云候选词已达到最大数量限制: " .. env.max_cloud_candidates ..
                                    "，跳过后续候选词")
                    break
                end

                if candidate.value and candidate.value ~= "" then
                    local cand_info = {
                        text = candidate.value,
                        field_name = candidate.field_name,
                        source = candidate.source,
                        rank = candidate.rank or i,
                        type = candidate.source
                    }
                    table.insert(ordered_candidates, cand_info)
                    cloud_count = cloud_count + 1
                    logger.info("提取云候选词 " .. cloud_count .. "/" .. env.max_cloud_candidates .. ": " ..
                                    candidate.field_name .. " = " .. candidate.value .. " (source: " .. candidate.source ..
                                    ")")
                end
            end

            for i, candidate in ipairs(parsed_data.ai_candidates) do
                if ai_count >= env.max_ai_candidates then
                    logger.info("AI候选词已达到最大数量限制: " .. env.max_ai_candidates ..
                                    "，跳过后续候选词")
                    break
                end

                if candidate.value and candidate.value ~= "" then
                    local cand_info = {
                        text = candidate.value,
                        field_name = candidate.field_name,
                        source = candidate.source,
                        rank = candidate.rank or i,
                        type = candidate.source
                    }
                    table.insert(ordered_candidates, cand_info)
                    ai_count = ai_count + 1
                    logger.info("提取AI候选词 " .. ai_count .. "/" .. env.max_ai_candidates .. ": " ..
                                    candidate.field_name .. " = " .. candidate.value .. " (source: " .. candidate.source ..
                                    ")")
                end
            end

            logger.info("按顺序提取到 " .. #ordered_candidates .. " 个候选词 (云: " .. cloud_count .. "/" ..
                            env.max_cloud_candidates .. ", AI: " .. ai_count .. "/" .. env.max_ai_candidates .. ")")
        else
            logger.info("parsed_data 为 nil 或不包含 candidates 数组")
        end
    end)
    if not ok then
        logger.error("tcp_socket.translate 调用失败: " .. tostring(err))
    end

    -- 检查是否有智能合成结果
    if #ordered_candidates > 0 then

        -- 获取候选词的 spans

        -- 这里获取的是原始第一个候选词的分割信息, 原始是的 nihk`haha`wode, 这个候选词本身就是我自己合成出来的, 所以是不存在spans信息的
        -- 但在产生的时候候选信息已经被我保存下来了.
        -- 获取所有分割点
        -- 检查是否已有spans信息（用于光标跳转功能）
        -- 云输入候选词成为第一候选词后，用户可能需要光标跳转重新编辑
        local existing_spans = spans_manager.get_spans(context)

        if existing_spans then
            logger.info("已存在spans信息，来源: " .. existing_spans.source)
        else
            -- 从原生候选词中提取spans信息（原生候选词包含准确的spans信息）
            -- first_original_cand 是Rime原生生成的候选词，包含正确的分割信息
            local success = spans_manager.extract_and_save_from_candidate(context, first_original_cand, input,
                "cloud_ai_filter_v2")
            if success then
                logger.info("extract_and_save_from_candidate创建spans信息")
            else
                logger.info("从原生候选词中提取spans信息失败，可能该候选词不包含spans信息")
            end
        end
        -- for i, vertex in ipairs(vertices) do
        --    logger.info("spans Vertex " .. i .. ": " .. vertex)
        -- end

        -- 我之前应该处理过这种情况,如果seg的类型不对的话,应该是直接跳过的.
        -- 按顺序创建候选词（保持返回结果的顺序）
        for i, cand_info in ipairs(ordered_candidates) do
            logger.info("创建候选词 " .. i .. ": " .. cand_info.text .. " (类型: " .. cand_info.type .. ")" ..
                            " segment._start :" .. segment._start .. " segment._end: " .. segment._end)
            if cand_info.type == "baidu_cloud" then
                cand_comment = "   [云输入]"
            elseif cand_info.type == "ai_cloud" then
                cand_comment = "   [AI识别]"
            end
            local candidate = Candidate(cand_info.type, segment._start, segment._end, cand_info.text, cand_comment)
            candidate.preedit = original_preedit
            yield(candidate)
        end

    end

    -- for i, vertex in ipairs(vertices) do
    --    logger.info("spans Vertex " .. i .. ": " .. vertex)
    -- end

    -- 输出原始候选词
    for _, cand in ipairs(long_candidates_table) do
        yield(cand)
    end

    for _, cand in ipairs(no_long_candidates_table) do
        yield(cand)
    end

    for cand in translation:iter() do
        logger.info(string.format("剩余选词信息: text=%s, preedit=%s, start=%s, end=%s, type=%s, comment=%s",
            tostring(cand.text), tostring(cand.preedit), tostring(cand.start), tostring(cand._end), tostring(cand.type),
            tostring(cand.comment)))
        yield(cand)
    end
    logger.info("所有候选词输出完成.")

end

function translator.fini(env)
    logger.info("云输入处理器结束运行")
end

return translator
