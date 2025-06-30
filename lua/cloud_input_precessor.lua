-- 引入日志工具模块
local logger_module = require("logger")

-- 创建当前模块的日志记录器
local logger = logger_module.create("cloud_input_precessor", {
    enabled = false  -- 可以通过这里控制日志开关
})

local cloud_input_precessor = {}
local delimiter = " "  -- 默认分隔符

function cloud_input_precessor.init(env)
    -- 获取输入法引擎和上下文   
    local config = env.engine.schema.config
    -- 初始化时清空日志文件
    logger:clear()
    logger:info("云输入处理器初始化完成")
    delimiter = config:get_string("speller/delimiter"):sub(1, 1) or " "
    logger:info("当前分隔符: " .. delimiter)
    --  fixed 设置一个变量
    -- context:set_property只能设置字符串类型
    env.engine.context:set_property("cloud_translate_flag", "0")

end

-- 检测输入中文的长度


-- 检测是否包含标点符号
local function has_punctuation(text)
    if not text or text == "" then
        return false
    end

    -- 简单检查是否包含常见标点符号
    local has_punct = false
    
    -- 检查中文标点
    if string.find(text, "[,。！？；：（）【】《》、]") then
        has_punct = true
    end
    
    -- 检查英文标点
    if string.find(text, "[,.!?;:()%[%]<>/_=+*&^%%$#@~`|\\-]") then
        has_punct = true
    end

    logger:info("has_punct: " .. tostring(has_punct))

    return has_punct

end

-- 按键处理器函数
-- 负责监听按键事件,判断是否应该触发翻译器
function cloud_input_precessor.func(key, env)
    -- 返回值常量定义
    local kRejected = 0  -- 表示按键被拒绝
    local kAccepted = 1  -- 表示按键已被处理
    local kNoop = 2      -- 表示按键未被处理,继续传递给下一个处理器
    
    -- 使用 pcall 捕获所有可能的错误
    local success, result = pcall(function()
        -- 获取输入法引擎和上下文
        local engine = env.engine        
        local context = engine.context
        local input = context.input
        
        -- 读取配置中的常规输入字符内容
        -- local config = engine.schema.config
        -- local regular_input = config:get_string("speller/alphabet")

        -- 检查按键是否有效
        if not key then
            error("按键对象为空")
        end

        logger:info("当前按键: " .. key:repr())

        -- -- 如果按键的值是Up 和 Down,则不进行处理
        -- if key:repr() == "Up" or key:repr() == "Down" then  -- or key:repr() == "space" 
        --     logger:info("按键为上下键或空格键, 不进行处理")
        --     return kNoop
        -- end

        -- 检查当前是否正在组词状态（即用户正在输入但还未确认）
        local is_composing = context:is_composing()
        local preedit = context:get_preedit()
        local preedit_text = preedit.text
         -- 移除光标符号和后续的prompt内容
        local clean_text = preedit_text:gsub("‸.*$", "")  -- 从光标符号开始删除到结尾
        logger:info("当前预编辑文本: " .. clean_text)
        local _, count = string.gsub(clean_text, delimiter, delimiter)
        logger:info("当前输入内容分隔符数量: " .. count)
        local has_punct = has_punctuation(input)

        if is_composing and (has_punct or count>=4) then
            logger:info("当前正在组词状态,检测到标点符号或分隔符数量达到4,触发云输入提示")
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

        -- 检查当前按键是否为预设的触发键
        if key:repr() == "Return" and context:get_property("cloud_translate_flag") == "1" then
            logger:info("触发云输入处理cloud_translate, 添加option")
            context:set_option("cloud_translate", true)

            -- 返回已处理,阻止其他处理器处理这个按键
            return kAccepted
        end

        return kNoop
    end)

    -- 处理错误情况
    if not success then
        local error_message = tostring(result)
        logger:error("云输入处理器发生错误: " .. error_message)
        
        -- 记录详细的错误信息用于调试
        logger:error("错误堆栈信息: " .. debug.traceback())
        
        -- 在发生错误时,安全地返回 kNoop,让其他处理器继续工作
        return kNoop
    end
    
    -- 成功执行,返回处理结果
    logger:info("云输入处理器执行成功, 返回值: " .. tostring(result))
    return result or kNoop
end

function cloud_input_precessor.fini(env)
    logger:info("云输入处理器结束运行")
end


return cloud_input_precessor