-- logger 配置示例
-- 在使用 logger 模块之前，可以通过以下方式配置日志输出模式

local logger = require("logger")

-- 方式1: 使用配置函数切换到统一模式
-- logger.set_unified_mode(true, "all_modules.log")

-- 方式2: 直接修改 logger.lua 文件中的 default_config
-- 将 default_config.unique_file_log 设置为 true

-- 示例使用：
-- 
-- 分离模式（默认）：
-- smart_cursor_processor.log  - 智能光标处理器的日志
-- baidu_translator.log        - 百度翻译器的日志
-- debug_filter.log            - 调试过滤器的日志
-- 
-- 统一模式：
-- unified.log                 - 所有模块的日志都输出到这里
-- 或者自定义文件名如 all_modules.log

-- 使用示例：
local logger_instance = logger.create("test_module")
logger_instance:info("这是一条测试日志")

-- 在统一模式下，日志格式依然保留模块名，方便区分：
-- [2025-07-12 10:30:15] [INFO] [test_module] 这是一条测试日志
-- [2025-07-12 10:30:16] [INFO] [smart_cursor_processor] 智能光标移动处理器初始化完成
-- [2025-07-12 10:30:17] [DEBUG] [baidu_translator] 开始翻译请求
