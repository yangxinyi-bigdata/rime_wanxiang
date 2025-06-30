-- 打印消息,进行测试
local logger_module = require("logger")

-- 创建当前模块的日志记录器
local logger = logger_module.create("print_info_precessor", {
    enabled = true  -- 可以通过这里控制日志开关
})

local print_info_precessor = {}
local delimiter = " "  -- 默认分隔符

function print_info_precessor.init(env)
    -- 获取输入法引擎和上下文
    local engine = env.engine        
    local config = engine.schema.config
    -- 初始化时清空日志文件
    logger:clear()
    logger:info("云输入处理器初始化完成")
    delimiter = config:get_string("speller/delimiter"):sub(1, 1) or " "
    logger:info("当前分隔符:" .. delimiter)

end

-- 检测输入中文的长度

-- 按键处理器函数
-- 负责监听按键事件,判断是否应该触发翻译器
function print_info_precessor.func(key, env)
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

        -- 如果按键的值是Up 和 Down,则不进行处理
        if key:repr() == "space" then
            logger:info("打印出这行,说明空格键走到这里了")
            return kNoop
        end

        -- 如果不是触发键或不在组词状态,则不处理
        logger:info("发送kNoop,交给下一个处理")
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

function print_info_precessor.fini(env)
    logger:info("云输入处理器结束运行")
end


return print_info_precessor