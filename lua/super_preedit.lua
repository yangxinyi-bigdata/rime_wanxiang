-- 修改输入预览的过滤器函数
-- 此函数用于美化和处理输入法的预编辑文本显示
-- 引入日志工具模块
local logger_module = require("logger")

-- 创建当前模块的日志记录器
local logger = logger_module.create("super_preedit", {
    enabled = false, -- 启用日志以便测试
    unified_log = false, -- 启用日志以便测试
    log_level = "DEBUG"
})

local function modify_preedit_filter(input, env)
    -- 获取输入法引擎的配置对象
    local config = env.engine.schema.config
    -- 从配置中获取分隔符，默认为 " '"（空格和单引号）
    local delimiter = config:get_string('speller/delimiter') or " '"

    -- 获取当前输入方案的标识符
    local schema_id = env.engine.schema.schema_id or ""
    -- 判断是否为万象Pro输入方案
    local is_wanxiang_pro = (schema_id == "wanxiang_pro")

    -- 从YAML配置文件中读取相关参数
    local tone_isolate = config:get_bool("speller/tone_isolate") -- 是否将数字声调从转换后拼音中隔离出来
    local visual_delim = config:get_string("speller/visual_delimiter") or " " -- 定义转换后的分隔符号，用于视觉显示

    -- 设置环境变量，获取声调显示选项
    env.settings = {
        tone_display = env.engine.context:get_option("tone_display")
    } or false
    -- 提取自动分隔符（第一个字符，通常是空格）
    local auto_delimiter = delimiter:sub(1, 1)
    -- 提取手动分隔符（第二个字符，通常是单引号）
    local manual_delimiter = delimiter:sub(2, 2)

    -- 获取声调显示设置
    local is_tone_display = env.settings.tone_display
    -- 获取输入法上下文对象
    local context = env.engine.context

    -- 获取当前编辑的文本段
    local seg = context.composition:back()
    -- 判断是否处于部首模式（部首查字或反向笔画模式）
    env.is_radical_mode = seg and (seg:has_tag("radical_lookup") or seg:has_tag("reverse_stroke")) or false

    -- 遍历所有候选词进行处理
    for cand in input:iter() do
        -- 如果是部首模式，直接输出候选词，不做任何处理
        if env.is_radical_mode then
            yield(cand)
            goto continue
        end

        -- 获取候选词的原始对象
        local genuine_cand = cand:get_genuine()
        -- 获取预编辑文本（用户输入的原始文本）
        local preedit = genuine_cand.preedit or ""
        -- 获取注释文本（通常包含拼音信息）
        local comment = genuine_cand.comment

        -- 如果没有注释或不显示声调，直接输出候选词
        if not comment or comment == "" or not is_tone_display then
            yield(cand)
            goto continue
        end

        -- 检查并清理comment中的chinese_pos信息
        if comment:match("^chinese_pos:") then
            -- 如果comment以chinese_pos开头，删除"chinese_pos:数字,数字,"格式的前缀
            logger.debug("检测到chinese_pos前缀，清理前: " .. comment)
            yield(cand)
            goto continue
        end

        -- 解析并拆分预编辑文本（preedit）
        -- 将用户输入按分隔符拆分成不同的部分
        local input_parts = {}
        local current_segment = ""
        for i = 1, #preedit do
            -- 逐字符遍历预编辑文本
            local char = preedit:sub(i, i)
            -- 如果遇到分隔符，保存当前段并开始新段
            if char == auto_delimiter or char == manual_delimiter then
                if #current_segment > 0 then
                    table.insert(input_parts, current_segment)
                    current_segment = ""
                end
                table.insert(input_parts, char)
            else
                -- 将字符添加到当前段
                current_segment = current_segment .. char
            end
        end
        -- 添加最后一个段（如果存在）
        if #current_segment > 0 then
            table.insert(input_parts, current_segment)
        end

        -- 从注释（comment）中提取拼音段
        -- 注释通常包含完整的拼音信息，格式如 "pin1yin1;pin2yin2"
        local pinyin_segments = {}

        for segment in string.gmatch(comment, "[^" .. auto_delimiter .. manual_delimiter .. "]+") do
            -- 提取分号前的拼音部分（去掉权重等信息）
            local pinyin = segment:match("^[^;]+")
            if pinyin then
                table.insert(pinyin_segments, pinyin)
                logger.debug("提取到拼音段: " .. pinyin)
            end
        end
        -- 执行替换逻辑：将用户输入的编码替换为对应的拼音显示
        local pinyin_index = 1
        for i, part in ipairs(input_parts) do
            -- 如果是分隔符，替换为视觉分隔符
            if part == auto_delimiter or part == manual_delimiter then
                input_parts[i] = visual_delim
            else
                -- 解析当前部分的字母和数字（声调）
                local body, tone = part:match("(%a+)(%d?)")
                -- 获取对应的拼音
                local py = pinyin_segments[pinyin_index]

                if py then
                    if is_wanxiang_pro then
                        -- 万象Pro模式：直接使用完整拼音
                        input_parts[i] = py
                        pinyin_index = pinyin_index + 1
                    elseif i == #input_parts and #part == 1 then
                        -- 特殊处理：如果是最后一个部分且只有一个字符
                        local prefix = py:sub(1, 2)
                        local first_char = part:sub(1, 1):lower()
                        -- 对于s、c、z开头的音，保持原样
                        if first_char == "s" or first_char == "c" or first_char == "z" then
                            input_parts[i] = part
                        else
                            -- 对于zh、ch、sh等双字母声母，显示完整前缀
                            if prefix == "zh" or prefix == "ch" or prefix == "sh" then
                                input_parts[i] = prefix
                            else
                                input_parts[i] = part
                            end
                        end
                    else
                        -- 常规处理：根据tone_isolate设置决定是否包含声调
                        if tone_isolate then
                            input_parts[i] = py .. (tone or "")
                        else
                            input_parts[i] = py
                        end
                        pinyin_index = pinyin_index + 1
                    end
                end
            end
        end
        -- 将处理后的部分重新组合成完整的预编辑文本
        genuine_cand.preedit = table.concat(input_parts)
        -- 输出处理后的候选词
        yield(genuine_cand)
        ::continue::
    end
end
-- 返回过滤器函数供Rime调用
return modify_preedit_filter
