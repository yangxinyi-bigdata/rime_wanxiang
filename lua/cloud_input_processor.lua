-- 引入日志工具模块
local logger_module = require("logger")
-- 引入文本切分模块
-- local text_splitter = require("text_splitter")
local debug_utils = require("debug_utils")

-- 创建当前模块的日志记录器
local logger = logger_module.create("cloud_input_processor", {
    enabled = true, -- 可以通过这里控制日志开关
    unified_log = false -- 启用日志以便测试
})

local cloud_input_processor = {}
local delimiter = " " -- 默认分隔符

function cloud_input_processor.init(env)
    -- 获取输入法引擎和上下文   
    local config = env.engine.schema.config
    -- 初始化时清空日志文件
    logger.clear()
    logger.info("云输入处理器初始化完成")
    delimiter = config:get_string("speller/delimiter"):sub(1, 1) or " "
    logger.info("当前分隔符: " .. delimiter)
    --  fixed 设置一个变量
    -- context:set_property只能设置字符串类型
    env.engine.context:set_property("cloud_translate_flag", "0")
    env.engine.context:set_property("backtick_prompt", "0")

end

local function set_cloud_translate_flag(context)
    -- 这部分代码时检测输入的字符长度，通过检测中间有几个分隔符实现
    -- 检查当前是否正在组词状态（即用户正在输入但还未确认）
    local is_composing = context:is_composing()
    local preedit = context:get_preedit()
    local preedit_text = preedit.text
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

-- 按键处理器函数
-- 负责监听按键事件,判断是否应该触发翻译器
function cloud_input_processor.func(key, env)
    local engine = env.engine
    local context = engine.context
    logger.info("测试虚拟按键: " .. key:repr())
    -- 返回值常量定义
    local kRejected = 0 -- 表示按键被拒绝
    local kAccepted = 1 -- 表示按键已被处理
    local kNoop = 2 -- 表示按键未被处理,继续传递给下一个处理器
    local is_composing = context:is_composing()
    if not key or not context:is_composing() then
        return kNoop
    end

    -- 使用 pcall 捕获所有可能的错误
    local success, result = pcall(function()
        -- 获取输入法引擎和上下文
        local engine = env.engine
        local context = engine.context
        local input = context.input
        

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
        logger.info("当前按键: " .. key:repr())
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
        local key_repr = key:repr()
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

        -- -- 定义需要跳过处理的按键
        -- local skip_keys = {
        --     ["Up"] = true,
        --     ["Down"] = true,
        --     ["space"] = true,
        --     ["1"] = true,
        --     ["2"] = true,
        --     ["3"] = true,
        --     ["4"] = true,
        --     ["5"] = true,
        --     ["6"] = true,
        --     ["7"] = true,
        --     ["8"] = true,
        --     ["9"] = true,
        --     ["0"] = true
        -- }
        -- -- 如果按键需要跳过,则不进行处理
        -- local key_repr = key:repr()
        -- if skip_keys[key_repr] then
        --     logger.info("按键为上下键、空格键或数字键, 不进行处理")
        --     return kNoop
        -- end

        -- 设置云输入法表示标
        set_cloud_translate_flag(context)

        -- 检查当前按键是否为预设的触发键
        if key:repr() == "Return" and context:get_property("cloud_translate_flag") == "1" then
            logger.info("触发云输入处理cloud_translate, 添加option")
            context:set_option("cloud_translate", true)

            -- 返回已处理,阻止其他处理器处理这个按键
            return kAccepted
        end

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
