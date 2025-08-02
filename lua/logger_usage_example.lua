-- logger.lua 使用示例
-- 演示新的配置优先级机制

local logger = require("logger")

-- 示例1：使用默认配置
print("=== 示例1：使用默认配置 ===")
local log1 = logger.create("module1")
log1.info("使用默认配置的日志")

-- 示例2：调用文件自定义配置
print("\n=== 示例2：调用文件自定义配置 ===")
local log2 = logger.create("module2", {
    enabled = true,
    unique_file_log = true,
    console_output = true
})
log2.info("使用自定义配置的日志")

-- 示例3：设置全局超级开关
print("\n=== 示例3：设置全局超级开关 ===")

-- 设置全局日志开关为关闭
logger.set_global_enabled(false)
local log3 = logger.create("module3", {
    enabled = true  -- 这个设置会被全局开关覆盖
})
log3.info("这条日志不会被记录，因为全局开关关闭了")

-- 重置全局日志开关
logger.set_global_enabled(nil)  -- 恢复为不强制

-- 设置全局统一文件开关
logger.set_global_unique_file_log(true, "global_unified.log")
local log4 = logger.create("module4", {
    unique_file_log = false  -- 这个设置会被全局开关覆盖
})
log4.info("这条日志会输出到统一文件，因为全局开关强制统一")

-- 示例4：展示配置优先级
print("\n=== 示例4：配置优先级演示 ===")
print("当前全局开关状态:")
local overrides = logger.get_global_overrides()
print("force_enabled:", overrides.force_enabled)
print("force_unique_file_log:", overrides.force_unique_file_log)

-- 重置所有全局开关
print("\n=== 重置全局开关 ===")
logger.set_global_enabled(nil)
logger.set_global_unique_file_log(nil)

local log5 = logger.create("module5", {
    enabled = true,
    unique_file_log = false,
    console_output = true
})
log5.info("重置后使用各自文件配置的日志")

print("\n示例运行完成！")
