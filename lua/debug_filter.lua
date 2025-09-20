-- lua/debug_filter.lua - 调试filter，用于打印Translation和Segmentation信息
-- 可以帮助调试其他翻译器和过滤器的输出
local logger_module = require("logger")
local debug_utils = require("debug_utils")

-- 创建当前模块的日志记录器
local logger = logger_module.create("debug_filter", {
    enabled = true, -- 启用日志以便测试
    unique_file_log = false, -- 启用日志以便测试
    log_level = "DEBUG"
})

local filter = {}

function filter.init(env)
    logger.clear()
    logger.info("调试过滤器初始化完成")
    logger.info("=" .. string.rep("=", 80))
end

local function split(str, delimiter)
    if delimiter == "" then
        return {str}
    end
    local res, start = {}, 1
    local delim_len = #delimiter
    while true do
        local pos = string.find(str, delimiter, start, true) -- plain match
        if not pos then
            res[#res + 1] = string.sub(str, start)
            break
        end
        res[#res + 1] = string.sub(str, start, pos - 1)
        start = pos + delim_len
    end
    return res
end

local function load_xform_rules(config)
    logger.debug("load_xform_rules")
    local rules, preedit_format = {}, config:get_list("translator/preedit_format")
    logger.debug("preedit_format.size: " .. preedit_format.size)

    for i = 0, preedit_format.size - 1 do
        local preedit_format_one = preedit_format:get_value_at(i)
        -- logger.debug("preedit_format_one: " .. tostring(preedit_format_one))
        -- logger.debug("preedit_format_one type: " .. preedit_format_one.type)
        if preedit_format_one then
            local raw = preedit_format_one:get_string()
            -- logger.debug("raw: " .. raw)
            -- 只处理 xform/.../.../
            local kind, rest = raw:match("^([^/]+)/(.+)$")
            if kind == "xform" then
                local pattern, replacement = rest:match("^(.*)/(.*)/$")
                -- logger.debug("pattern: " .. pattern)
                -- logger.debug("replacement: " .. replacement)
                if pattern and replacement then
                    table.insert(rules, {
                        pattern = pattern,
                        replacement = replacement
                    })
                end
            end
        end
    end
    return rules
end

function filter.func(translation, env)
    local engine = env.engine
    local context = engine.context
    local input = context.input
    local config = engine.schema.config

    -- local preedit_text = "ug ho co wul"

    logger.info()
    logger.info()
    logger.info(">>> 新的过滤器调试处理 <<<")
    logger.info("当前输入: '" .. input .. "'")
    logger.info("输入长度: " .. #input)

    -- 打印Environment信息
    -- debug_utils.print_env_info(env, logger)

    logger.info()

    -- 打印Segmentation信息
    local composition = context.composition
    if composition and not composition:empty() then
        local segmentation = composition:toSegmentation()
        debug_utils.print_segmentation_info(segmentation, logger)

    end

    -- 输出所有候选词并记录
    local count = 0
    for cand in translation:iter() do
        count = count + 1

        -- 只记录前20个候选词的详细信息
        if count <= 20 then
            logger.info(string.format("输出候选词 %d: text='%s', comment='%s', type='%s', preedit='%s'", count,
                cand.text or "", cand.comment or "", cand.type or "", cand.preedit or ""))
        end

        -- 首先应该确定什么时候进入到这个分支当中:应该是当input当中有奇数个字母的情况下, 才会进入到这个分支当中

        -- -- 但如配置中的 "speller/delimiter" 中的音节分隔符, 以该分隔符为准, 否则默认使用空格
        -- if #input % 2 == 1 then
        --     local preedit_text = cand.preedit
        --     local delimiter = config:get_string("speller/delimiter"):sub(1, 1)
        --     logger.debug("delimiter: " .. delimiter)
        --     -- 以分隔符中的第一个字符对preedit_text进行拆分
        --     -- local parts = split(preedit_text, delimiter)
        --     -- logger.debug("parts size: " .. #parts)
        --     -- 日志输出最后一个音节
        --     -- logger.debug("parts[#parts]: " .. parts[#parts])

        --     local last_letter
        --     -- 判断最后一个音节的长度,如果等于3,则拆分出最后一个字母, 
        --     if #parts[#parts] == 3 then
        --         -- 拆分出最后一个字母
        --         last_letter = parts[#parts]:sub(-1)
        --         -- 提取前两个字母
        --         local first_two_letters = parts[#parts]:sub(1, 2)
        --         -- 移除最后一个音节
        --         table.remove(parts, #parts)
        --         -- 将提取前两个字母添加进去
        --         table.insert(parts, first_two_letters)
        --         -- 拼接剩余的音节
        --         preedit_text = table.concat(parts, delimiter)
        --         env.natural_rules = load_xform_rules(config)

        --         for _, rule in ipairs(env.natural_rules) do
        --             preedit_text = rime_api.regex_replace(preedit_text, rule.pattern, rule.replacement)
        --         end
        --         -- 拼接上最后一个字母
        --         preedit_text = preedit_text .. " " .. last_letter
        --         logger.debug("preedit_text: " .. preedit_text)
        --         cand.preedit = preedit_text
        --     end
        -- end

        yield(cand)
    end

    -- logger.info("总共输出候选词数量: " .. count)
    -- logger.info("=" .. string.rep("=", 80))

    -- for cand in translation:iter() do
    --     yield(cand)
    -- end

    -- 读入配置
    -- local preedit_format = config:get_list("translator/preedit_format")
    -- -- logger.info("preedit_format: " .. preedit_format)
    -- logger.info("preedit_format size: " .. preedit_format.size)
    -- logger.info("preedit_format type: " .. type(preedit_format))
    -- for i = 0, preedit_format.size - 1 do
    --     logger.info("preedit_format[" .. i .. "]: " .. preedit_format:get_value_at(i):get_string())
    -- end

end

function filter.fini(env)
    logger.info("调试过滤器结束运行")
end

return filter
