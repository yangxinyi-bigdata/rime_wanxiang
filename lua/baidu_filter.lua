-- lua/baidu_filter.lua 修改成filter版本,通过百度云接口获取云输入法拼音词组,并添加到候选词中第一位中来
-- 百度云输入获取filter版本
local json = require("json")

-- 引入日志工具模块
local logger_module = require("logger")
-- 引入文本切分模块
local text_splitter = require("text_splitter")
local debug_utils = require("debug_utils")
-- 引入spans管理模块
local spans_manager = require("spans_manager")

-- 创建当前模块的日志记录器
local logger = logger_module.create("baidu_filter", {
    enabled = true, -- 启用日志以便测试
    unified_log = false -- 启用日志以便测试
})

-- 添加 ARM64 Homebrew 的 Lua 路径
local function setup_lua_paths()
    -- 保存原始路径
    local original_path = package.path
    local original_cpath = package.cpath

    -- 添加 ARM64 Homebrew 路径
    package.path = package.path .. ";/opt/homebrew/share/lua/5.4/?.lua;/opt/homebrew/share/lua/5.4/?/init.lua"
    package.cpath = package.cpath .. ";/opt/homebrew/lib/lua/5.4/?.so;/opt/homebrew/lib/lua/5.4/?/core.so"

    logger:info("已添加 ARM64 Homebrew Lua 路径")
end

setup_lua_paths()

local http = require("simplehttp")
http.TIMEOUT = 0.5

local function make_url(input, bg, ed)
    return 'https://olime.baidu.com/py?input=' .. input .. '&inputtype=py&bg=' .. bg .. '&ed=' .. ed ..
               '&result=hanzi&resultcoding=utf-8&ch_en=0&clientinfo=web&version=1'
end

-- 封装 curl 发送网络请求 
local function http_get(url)
    local handle = io.popen("curl -m 0.5 -s '" .. url .. "'")
    local result = handle:read("*a")
    handle:close()
    return result
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
    logger:info("当前预编辑文本: " .. clean_text)
    local _, count = string.gsub(clean_text, delimiter, delimiter)
    logger:info("当前输入内容分隔符数量: " .. count)
    -- local has_punct = has_punctuation(input)

    -- 触发状态改成,当数如字符超过4个,或者有标点且超过2个:
    if is_composing and count >= 3 then
        logger:info("当前正在组词状态,检测到分隔符数量达到3,触发云输入提示")
        -- 只在值真正需要改变时才设置
        -- 先获取当前选项的值，避免不必要的更新
        logger:info("当前云输入提示标志: " .. context:get_property("cloud_translate_flag"))

        if context:get_property("cloud_translate_flag") == "0" then
            logger:info("云输入提示标志为 0, 设置为 1")
            context:set_property("cloud_translate_flag", "1")
            -- context:set_option("cloud_translate_prompt", true)
            logger:info("cloud_translate_flag 已设置为 1")

        end

    else
        -- 如果不在组词状态或没有达到触发条件,则重置提示选项
        logger:info("当前不在组词状态或未达到触发条件,云输入提示已重置")
        if context:get_property("cloud_translate_flag") == "1" then
            -- context:set_option("cloud_translate_prompt", false)
            context:set_property("cloud_translate_flag", "0")
            logger:info("cloud_translate_flag 已设置为 0")

        end
    end
end

function translator.init(env)
    -- 初始化时清空日志文件
    logger:clear()
    logger:info("云输入处理器初始化完成")

    local engine = env.engine
    local context = engine.context
    local config = engine.schema.config

    -- 加载自然码映射表
    ziranma_mapping_config = config:get_map("speller/ziranma_to_quanpin")

    -- 读取反引号分隔符配置
    backtick_delimiter_before = config:get_string("translator/backtick_delimiter_before") or ""
    backtick_delimiter_after = config:get_string("translator/backtick_delimiter_after") or ""
    -- 获取输入法引擎和上下文   
    local config = env.engine.schema.config
    delimiter = config:get_string("speller/delimiter"):sub(1, 1) or " "
    logger:info("当前分隔符: " .. delimiter)

    --  replace_punct_enabled = config:get_string("translator/replace_punct_enabled") or false
    -- logger:info("反引号分隔符设置: '" .. backtick_delimiter_before .. "' '" .. backtick_delimiter_after .. "'")

    -- if ziranma_mapping_config then
    --    logger:info("开始打印自然码映射表...")
    --    local count = 0
    --    local success, error_msg = pcall(function()
    --       -- 创建一个新的表来存储映射
    --       local temp_mapping = {}

    --       -- 获取所有的键
    --       local keys = ziranma_mapping_config:keys()
    --       if keys then
    --          for _, key in ipairs(keys) do
    --             -- 使用 get_value 方法获取对应的值
    --             local value = ziranma_mapping_config:get_value(key)
    --             if value then
    --                local quanpin = value:get_string()
    --                temp_mapping[key] = quanpin
    --                logger:info(string.format("自然码映射: %s -> %s", key, quanpin))
    --                count = count + 1
    --             end
    --          end
    --       end

    --       -- 成功加载后，替换全局映射表
    --       ziranma_mapping = temp_mapping
    --    end)

    --    if success then
    --       logger:info(string.format("自然码映射表加载完成，共 %d 项", count))
    --    else
    --       logger:error(string.format("加载自然码映射表时发生错误: %s", error_msg))
    --    end
    -- else
    --    logger:error("未找到自然码映射配置")
    -- end
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
        logger:error("双拼转全拼失败:  " .. tostring(result))
        return input -- 出错时返回原始输入
    end
end

-- 获取云输入结果的函数（同步调用）
local function get_cloud_result(pinyin_text)
    if pinyin_text == "" then
        return ""
    end

    local full_pinyin = double_pinyin_to_full_pinyin(pinyin_text)
    logger:info("片段 '" .. pinyin_text .. "' 转换后的全拼: " .. full_pinyin)

    local url = make_url(full_pinyin, 0, 5)
    local reply = http.request(url)
    local parse_success, baidu_response = pcall(json.decode, reply)

    if parse_success and baidu_response.status == "T" and baidu_response.result and baidu_response.result[1] and
        baidu_response.result[1][1] then
        local result = baidu_response.result[1][1][1]
        logger:info("片段 '" .. pinyin_text .. "' 云输入结果: " .. result)
        return result
    else
        logger:info("片段 '" .. pinyin_text .. "' 云输入无结果，保持原样")
        return pinyin_text
    end
end

function translator.func(translation, env)
    local engine = env.engine
    local context = engine.context
    local input = context.input

    -- 自动检查并清除过期的spans信息
    -- spans_manager.auto_clear_check(context, input)

    -- 判断是否存在标点符号或者长度超过设定值,如果是在seg后面添加prompt说明
    local segment = ""

    -- 在segment后面添加prompt
    local composition = context.composition
    if (not composition:empty()) then
        -- 获得队尾的 Segment 对象
        segment = composition:back()
    end

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
    local has_punctuation = input:match("[,.!?;:()%[%]<>/_=+*&^%%$#@~|%-`'\"']") ~= nil

    if not has_punctuation then
        -- 纯英文字母输入，使用原来的方式直接调用百度云接口
        logger:info("检测到纯英文字母输入，使用传统百度云处理方式")

        local full_pinyin = double_pinyin_to_full_pinyin(input)
        logger:info("输入 '" .. input .. "' 转换后的全拼: " .. full_pinyin)

        local url = make_url(full_pinyin, 0, 5)
        local reply = http.request(url)
        local parse_success, baidu_response = pcall(json.decode, reply)

        local first_original_cand = nil
        local original_preedit = ""
        local cand_start = 0
        local cand_end = 0
        local cand_type = nil
        local spans = nil

        -- logger:info("parse_success: " .. tostring(parse_success)  .. "  baidu_response.status: "  .. tostring(baidu_response.status)  .. " baidu_response.result: " .. tostring(baidu_response.result) .. " baidu_response.result[1]: " .. tostring(baidu_response.result[1]))
        if parse_success and baidu_response.status == "T" and baidu_response.result and baidu_response.result[1] then
            -- 先保存第一个原始候选词
            for cand in translation:iter() do
                first_original_cand = cand
                original_preedit = cand.preedit
                cand_start = cand.start
                cand_end = cand._end
                cand_type = cand.type

                -- 获取候选词的 spans
                spans = cand:spans()
                -- 获取所有分割点
                local vertices = spans.vertices
                -- for i, vertex in ipairs(vertices) do
                --    logger:info("spans Vertex " .. i .. ": " .. vertex)
                -- end

                -- 使用spans_manager保存spans信息
                spans_manager.save_spans(context, vertices, input, "baidu_filter")

                break
            end

            -- 添加百度云候选词
            for candidate_index, candidate_data in ipairs(baidu_response.result[1]) do
                logger:info("添加百度云候选词: " .. candidate_data[1])
                logger:info("原始候选词preedit: " .. original_preedit)
                logger:info(
                    "segment.start: " .. segment.start .. " segment._end: " .. segment._end .. " cand_start: " ..
                        cand_start .. " cand_end: " .. cand_end)

                -- local cloud_candidate = Candidate("", segment.start, segment._end, candidate_data[1], "   [云输入]")
                local cloud_candidate = Candidate("baidu_cloud", cand_start, cand_end, candidate_data[1],
                    "   [云输入]")
                cloud_candidate.preedit = original_preedit

                yield(cloud_candidate)
            end

            -- 输出原始候选词
            if first_original_cand then
                yield(first_original_cand)
            end

            -- 输出剩余原始候选词
            for cand in translation:iter() do
                yield(cand)
            end

        else
            logger:info("百度云接口无结果，输出原始候选词")
            for cand in translation:iter() do
                yield(cand)
            end
        end
    else
        -- 包含标点符号或反引号，使用智能切分处理
        logger:info("检测到标点符号或反引号，使用智能切分处理方式")

        -- 切分并处理输入（添加错误捕获）
        local segments = {}
        local final_result = ""

        local success, result = pcall(function()
            -- 是否替换中文标点符号
            return text_splitter.split_and_convert_input_with_log_and_delimiter(input, logger,
                backtick_delimiter_before, backtick_delimiter_after, replace_punct_enabled)
        end)

        if success and result then
            segments = result
            logger:info("成功运行切分函数，获得 " .. #segments .. " 个片段")
            for i, seg in ipairs(segments) do
                logger:info(string.format("片段 %d: type=%s, content='%s'", i, seg.type, seg.content))
            end
        else
            logger:error("切分函数运行失败: " .. tostring(result))
            logger:info("降级到原始处理方式")
            -- 降级处理：将整个输入当作纯文本处理
            segments = {{
                type = "abc",
                content = input
            }}
        end

        -- 处理每个片段（添加错误捕获）
        for i, segment in ipairs(segments) do
            local segment_success, segment_result = pcall(function()
                if segment.type == "abc" then
                    -- 文本片段：进行双拼转换和云输入
                    logger:info(string.format("处理文本片段 %d: '%s'", i, segment.content))
                    return get_cloud_result(segment.content)
                elseif segment.type == "punct" then
                    -- 标点符号：直接添加
                    logger:info(string.format("处理标点片段 %d: '%s'", i, segment.content))
                    return segment.content
                elseif segment.type == "backtick" then
                    -- 反引号内容：不处理，直接添加
                    logger:info(string.format("处理反引号片段 %d: '%s'", i, segment.content))
                    return segment.content
                else
                    logger:info(string.format("未知片段类型 %d: type=%s, content='%s'", i, segment.type,
                        segment.content))
                    return segment.content
                end
            end)

            if segment_success and segment_result then
                final_result = final_result .. segment_result
                logger:info(string.format("片段 %d 处理成功，结果: '%s'", i, segment_result))
            else
                logger:error(string.format("片段 %d 处理失败: %s", i, tostring(segment_result)))
                -- 失败时使用原始内容
                final_result = final_result .. (segment.content or "")
            end
        end

        logger:info("智能切分最终结果: " .. final_result)

        local first_original_cand = nil
        local original_preedit = ""
        local cand_start = 0
        local cand_end = 0
        local cand_type = nil
        local cand_comment = ""
        local spans = nil
        -- 检查是否有智能合成结果
        if final_result ~= "" then
            -- 先保存第一个原始候选词
            for cand in translation:iter() do
                first_original_cand = cand
                original_preedit = cand.preedit
                cand_start = cand.start
                cand_end = cand._end
                cand_type = cand.type
                cand_comment = cand.comment

                -- 获取候选词的 spans

                -- 这里获取的是原始第一个候选词的分割信息, 原始是的 nihk`haha`wode, 这个候选词本身就是我自己合成出来的, 所以是不存在spans信息的
                -- 但在产生的时候候选信息已经被我保存下来了.
                -- 获取所有分割点
                -- 检查是否已有spans信息（可能由其他脚本保存）
                local existing_spans = spans_manager.get_spans(context)

                if existing_spans then
                    logger:info("已存在spans信息，来源: " .. existing_spans.source)
                else
                    -- 尝试从候选词中提取spans信息
                    spans_manager.extract_and_save_from_candidate(context, cand, input, "baidu_filter")
                end
                -- for i, vertex in ipairs(vertices) do
                --    logger:info("spans Vertex " .. i .. ": " .. vertex)
                -- end

                break
            end

            -- 创建智能合成候选词
            logger:info("创建智能合成候选词: " .. final_result)
            -- local candidate = Candidate("baidu_cloud", cand_start, cand_end, final_result, "   [云输入]")
            -- 为了替换标点符号,把这个含有反引号片段的百度云返回值也标记成backtick_combo
            local candidate = Candidate("baidu_cloud", cand_start, cand_end, final_result, cand_comment)
            candidate.preedit = original_preedit
            yield(candidate)

            -- 输出原始候选词
            if first_original_cand then
                yield(first_original_cand)
            end

            for cand in translation:iter() do
                yield(cand)
            end
        else
            -- 没有智能合成结果，输出原有候选词
            logger:info("没有智能合成结果，输出原始候选词")
            for cand in translation:iter() do
                yield(cand)
            end
        end
    end
end

function translator.fini(env)
    logger:info("云输入处理器结束运行")
end

return translator
