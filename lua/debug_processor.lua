-- 调试处理器 - 用于输出当前上下文信息和按键信息
-- 引入日志工具模块
local logger_module = require("logger")
-- 引入调试工具模块
local debug_utils = require("debug_utils")

-- 创建当前模块的日志记录器
local logger = logger_module.create("debug_processor", {
    enabled = true, -- 启用日志以便测试
    unique_file_log = false, -- 启用日志以便测试
    log_level = "DEBUG"
})

local debug_precessor = {}

function debug_precessor.init(env)
    -- 获取输入法引擎和上下文   
    local config = env.engine.schema.config
    -- 初始化时清空日志文件
    logger.clear()
    logger.info("调试处理器初始化完成")
    
    -- 获取分隔符配置
    local delimiter = config:get_string("speller/delimiter"):sub(1, 1) or " "
    logger.info("当前分隔符: " .. delimiter)
    
end

-- 按键处理器函数
-- 负责监听按键事件，输出调试信息
function debug_precessor.func(key, env)
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
        
        -- 检查按键是否有效
        if not key then
            logger.error("按键对象为空")
            return kNoop
        end

        logger.info("")
        logger.info("=== 开始调试处理器分析 ===")
        
        -- 输出按键信息
        logger.info("接收到按键: " .. key:repr())
        
        -- 输出基本输入信息
        logger.info("当前输入内容: " .. input)
        logger.info("输入长度: " .. #input)
        
        -- 输出上下文状态信息
        local is_composing = context:is_composing()
        logger.info("是否正在组词: " .. tostring(is_composing))
        
        -- 获取并输出预编辑文本
        local preedit = context:get_preedit()
        local preedit_text = preedit.text
        logger.info("预编辑文本: " .. preedit_text)
        
        -- 清理预编辑文本（移除光标符号）
        local clean_text = preedit_text:gsub("‸.*$", "")
        logger.info("清理后的预编辑文本: " .. clean_text)
        
        -- 使用debug_utils输出详细的分段信息
        local segmentation = context.composition:toSegmentation()
        debug_utils.print_segmentation_info(segmentation, logger)
        
        -- 输出当前光标位置信息
        local current_start = segmentation:get_current_start_position()
        local current_end = segmentation:get_current_end_position()
        logger.info("当前分段开始位置: " .. current_start)
        logger.info("当前分段结束位置: " .. current_end)
        local caret_pos = context.caret_pos
        logger.info("当前光标位置: " .. caret_pos)
        
        -- 输出当前分段的输入内容
        if #input > 0 then
            local segmente_input = input:sub(current_start + 1, current_end)
            logger.info("当前分段输入: " .. segmente_input)
        end
        
        -- 输出一些常用的上下文属性
        local properties = {
            "ascii_mode",
            "full_shape",
            "ascii_punct",
            "simplification",
            "extended_charset",
            "emoji",
            "cloud_translate_flag",
            "backtick_prompt"
        }
        
        -- logger.info("--- 上下文属性状态 ---")
        -- for _, prop in ipairs(properties) do
        --     local value = context:get_property(prop) or "未设置"
        --     logger.info(prop .. ": " .. value)
        -- end
        
        -- 输出一些常用的选项状态
        local options = {
            "ascii_mode",
            "full_shape", 
            "ascii_punct",
            "simplification",
            "extended_charset",
            "emoji",
            "cloud_translate"
        }
        
        -- logger.info("--- 选项状态 ---")
        -- for _, opt in ipairs(options) do
        --     local value = context:get_option(opt)
        --     logger.info(opt .. ": " .. tostring(value))
        -- end
        
        -- -- 输出配置信息
        -- local config = engine.schema.config
        -- logger.info("--- 配置信息 ---")
        -- logger.info("方案ID: " .. (config:get_string("schema/schema_id") or "未知"))
        -- logger.info("方案名称: " .. (config:get_string("schema/name") or "未知"))
        -- logger.info("字母表: " .. (config:get_string("speller/alphabet") or "未设置"))
        -- logger.info("分隔符: " .. (config:get_string("speller/delimiter") or "未设置"))
        
        -- 如果是特殊按键，输出额外信息
        local special_keys = {
            "Return", "space", "BackSpace", "Delete", "Escape", "Tab",
            "Up", "Down", "Left", "Right", "Home", "End", "Page_Up", "Page_Down"
        }
        
        local key_repr = key:repr()
        for _, special_key in ipairs(special_keys) do
            if key_repr == special_key then
                logger.info("检测到特殊按键: " .. special_key)
                break
            end
        end
        
        -- 检测修饰键
        if key_repr:find("Control") then
            logger.info("检测到Control修饰键")
        end
        if key_repr:find("Shift") then
            logger.info("检测到Shift修饰键")
        end
        if key_repr:find("Alt") then
            logger.info("检测到Alt修饰键")
        end
        
        logger.info("=== 结束调试处理器分析 ===")
        logger.info("")
        
        -- 调试处理器不处理任何按键，只是记录信息
        return kNoop
    end)
    
    -- 处理错误情况
    if not success then
        local error_message = tostring(result)
        logger.error("调试处理器发生错误: " .. error_message)
        
        -- 记录详细的错误信息用于调试
        logger.error("错误堆栈信息: " .. debug.traceback())
        
        -- 在发生错误时,安全地返回 kNoop,让其他处理器继续工作
        return kNoop
    end
    
    -- 成功执行,返回处理结果
    return result or kNoop
end

function debug_precessor.fini(env)
    logger.info("调试处理器结束运行")
end

return debug_precessor
