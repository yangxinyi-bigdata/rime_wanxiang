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
local logger = logger_module.create("cloud_ai_filter", {
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

local http = require("simplehttp")
http.TIMEOUT = 0.3

local function make_url(input, bg, ed)
    return 'https://olime.baidu.com/py?input=' .. input .. '&inputtype=py&bg=' .. bg .. '&ed=' .. ed ..
               '&result=hanzi&resultcoding=utf-8&ch_en=0&clientinfo=web&version=1'
end

local translator = {}

local ziranma_mapping_config = {} -- 自然码映射表
local backtick_delimiter_before = "" -- 反引号分隔符
local backtick_delimiter_after = ""
local delimiter = ""
local replace_punct_enabled = false

local function set_cloud_translate_flag(cand, context)
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

    local engine = env.engine
    local context = engine.context
    local config = engine.schema.config
    env.schema_name = engine.schema.schema_name
    env.shuru_schema = config:get_string("schema/my_shuru_schema") or ""

    -- 加载自然码映射表
    ziranma_mapping_config = config:get_map("speller/ziranma_to_quanpin")

    -- 读取反引号分隔符配置
    backtick_delimiter_before = config:get_string("translator/backtick_delimiter_before") or ""
    backtick_delimiter_after = config:get_string("translator/backtick_delimiter_after") or ""
    -- 获取输入法引擎和上下文   
    local config = env.engine.schema.config
    delimiter = config:get_string("speller/delimiter"):sub(1, 1) or " "
    logger.info("当前分隔符: " .. delimiter)

    -- 读取候选词数量限制配置
    env.max_cloud_candidates = config:get_int("cloud_ai_filter/max_cloud_candidates") or 2
    env.max_ai_candidates = config:get_int("cloud_ai_filter/max_ai_candidates") or 1
    logger.info("云候选词最大数量: " .. env.max_cloud_candidates)
    logger.info("AI候选词最大数量: " .. env.max_ai_candidates)

end

local function double_pinyin_to_full_pinyin(input)
    local success, result = pcall(function()
        -- 这里可以添加具体的双拼转全拼的实现逻辑
        local result_table = {}
        for i = 1, #input, 2 do
            local pair = input:sub(i, i + 1)
            if i + 1 > #input then
                pair = input:sub(i)
            end
            -- 使用 get_value 方法获取配置值
            local value = ziranma_mapping_config:get_value(pair)
            if value then
                table.insert(result_table, value:get_string())
            else
                -- 如果没有找到映射，使用原始值
                table.insert(result_table, pair)
            end
        end
        return table.concat(result_table, "")
    end)

    if success then
        return result
    else
        logger.error("双拼转全拼失败:  " .. tostring(result))
        return input -- 出错时返回原始输入
    end
end

-- 获取云输入结果的函数（同步调用）
local function get_cloud_result(pinyin_text)
    if pinyin_text == "" then
        return ""
    end

    local full_pinyin = double_pinyin_to_full_pinyin(pinyin_text)
    logger.info("片段 '" .. pinyin_text .. "' 转换后的全拼: " .. full_pinyin)

    local url = make_url(full_pinyin, 0, 5)
    local reply = http.request(url)
    local parse_success, baidu_response = pcall(json.decode, reply)

    if parse_success and baidu_response.status == "T" and baidu_response.result and baidu_response.result[1] and
        baidu_response.result[1][1] then
        local result = baidu_response.result[1][1][1]
        logger.info("片段 '" .. pinyin_text .. "' 云输入结果: " .. result)
        return result
    else
        logger.info("片段 '" .. pinyin_text .. "' 云输入无结果，保持原样")
        return pinyin_text
    end
end

function translator.func(translation, env)
    local engine = env.engine
    local context = engine.context
    local input = context.input

    -- 自动检查并清除过期的spans信息
    -- spans_manager.auto_clear_check(context, input)

    if not context:get_option("cloud_translate") then
        -- 查看有没有云翻译的标识, 没有的话直接返回原有的候选词
        local count = 0
        for cand in translation:iter() do
            count = count + 1
            if count == 1 then
                set_cloud_translate_flag(cand, context)
                yield(cand) -- 输出原有候选词
            else
                yield(cand) -- 输出原有候选词
            end

        end

        return
    else
        context:set_option("cloud_translate", false) -- 重置选项，避免重复触发
    end

    -- 检查输入是否包含标点符号或反引号
    -- local has_punctuation = confirmed_pos_input:match("[,.!?;:()%[%]<>/_=+*&^%%$#@~|%-`'\"']") ~= nil

    -- 包含标点符号或反引号，使用智能切分处理
    logger.info("检测到标点符号或反引号，使用智能切分处理方式")

    -- 判断是否存在标点符号或者长度超过设定值,如果是在seg后面添加prompt说明
    local segment = ""

    -- 在segment后面添加prompt
    local composition = context.composition
    local segmentation = composition:toSegmentation()
    local confirmed_pos_input = ""
    if (not segmentation:empty()) then
        -- 获得队尾的 Segment 对象
        segment = segmentation:back()
        local confirmed_pos = segmentation:get_confirmed_position()
        confirmed_pos_input = input:sub(confirmed_pos + 1)

        logger.info("segmentation:get_confirmed_position(): " .. segmentation:get_confirmed_position())
        logger.info("confirmed_pos_input: " .. confirmed_pos_input)
    end

    -- 升级成将拼音发送到python那边,python那边进行处理之后,返回结果
    -- 1. input好像内容太多了,这里是否切分光标剩余的部分更加合理?  confirmed_pos_input
    -- 2. 将confirmed_pos_input使用socket发送到python端 tcp_socket
    -- 3. 发送tcp_socket.translate 等待获取结果

    -- 这里原来的confirmed_pos_input是不合理的,如果有多个segment就会都发送过去,应该是最后一个segment, 并且标签为abc
    local ordered_candidates = {}
    local ok, err = pcall(function()
        -- segment切片出应的input部分 _start: 8 _end: 14
        local segment_input = input:sub(segment._start + 1, segment._end)
        logger.info("根据segment切片得到 segment_input: " .. segment_input)

        local parsed_data = tcp_socket.translate(env.schema_name, env.shuru_schema, segment_input)
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
    local segments = {}

    local first_original_cand = nil
    local original_preedit = ""
    local cand_start = 0
    local cand_end = 0
    local cand_type = nil
    local cand_comment = ""
    local spans = nil
    -- 检查是否有智能合成结果
    if #ordered_candidates > 0 then
        -- 先保存第一个原始候选词
        for cand in translation:iter() do
            first_original_cand = cand
            original_preedit = cand.preedit
            cand_start = cand.start
            cand_end = cand._end
            logger.info(string.format(
                "原始候选词信息: text=%s, preedit=%s, start=%s, end=%s, type=%s, comment=%s",
                tostring(cand.text), tostring(cand.preedit), tostring(cand.start), tostring(cand._end),
                tostring(cand.type), tostring(cand.comment)))
            cand_type = cand.type
            cand_comment = cand.comment

            if cand_type == "punch" then
                context:confirm_current_selection()
                return 
            end

            if cand_type == "abc" then
                 
            end

            -- 获取候选词的 spans

            -- 这里获取的是原始第一个候选词的分割信息, 原始是的 nihk`haha`wode, 这个候选词本身就是我自己合成出来的, 所以是不存在spans信息的
            -- 但在产生的时候候选信息已经被我保存下来了.
            -- 获取所有分割点
            -- 检查是否已有spans信息（可能由其他脚本保存）
            local existing_spans = spans_manager.get_spans(context)

            if existing_spans then
                logger.info("已存在spans信息，来源: " .. existing_spans.source)
            else
                -- 尝试从候选词中提取spans信息
                spans_manager.extract_and_save_from_candidate(context, cand, input, "baidu_filter")
            end
            -- for i, vertex in ipairs(vertices) do
            --    logger.info("spans Vertex " .. i .. ": " .. vertex)
            -- end

            break
        end

        -- 按顺序创建候选词（保持返回结果的顺序）
        for i, cand_info in ipairs(ordered_candidates) do
            logger.info("创建候选词 " .. i .. ": " .. cand_info.text .. " (类型: " .. cand_info.type .. ")")
            local candidate = Candidate(cand_info.type, cand_start, cand_end, cand_info.text, cand_comment)
            candidate.preedit = original_preedit
            yield(candidate)
        end

        -- 输出原始候选词
        if first_original_cand then
            yield(first_original_cand)
        end

        for cand in translation:iter() do
            logger.info(string.format("剩余选词信息: text=%s, preedit=%s, start=%s, end=%s, type=%s, comment=%s",
                tostring(cand.text), tostring(cand.preedit), tostring(cand.start), tostring(cand._end),
                tostring(cand.type), tostring(cand.comment)))
            yield(cand)
        end
        logger.info("所有候选词输出完成.")
    else
        -- 没有智能合成结果，输出原有候选词
        logger.info("没有智能合成结果，输出原始候选词")
        for cand in translation:iter() do
            yield(cand)
        end
    end
end

function translator.fini(env)
    logger.info("云输入处理器结束运行")
end

return translator
