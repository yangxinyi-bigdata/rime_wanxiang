-- Rime输入法日志工具模块
-- 提供统一的日志记录功能
--
-- 使用方法：
-- 1. 分离模式（默认）：每个模块使用独立的日志文件
--    将 default_config.unique_file_log 设置为 false
-- 2. 统一模式：所有模块输出到同一个日志文件
--    将 default_config.unique_file_log 设置为 true
--    可通过 default_config.unique_file_log_file 自定义文件名

local logger = {}

-- 默认配置
local default_config = {
    enabled = true,
    log_dir = "/Users/yangxinyi/Library/Rime/log/",
    timestamp_format = "%Y-%m-%d %H:%M:%S",
    unique_file_log = true,  -- 是否统一输出到同一个日志文件
    unique_file_log_file = "all_modules.log"  -- 统一日志文件名
}

-- 配置管理函数
function logger.set_unified_mode(enabled, filename)
    default_config.unique_file_log = enabled
    if filename then
        default_config.unique_file_log_file = filename
    end
end

function logger.get_config()
    return default_config
end

-- 创建日志记录器
function logger.create(module_name, config)
    config = config or {}
    
    -- 合并配置
    local log_config = {}
    for k, v in pairs(default_config) do
        if config[k] ~= nil then
            log_config[k] = config[k]
        else
            log_config[k] = v
        end
    end
    
    -- 生成日志文件路径
    local log_file_path
    if log_config.unique_file_log then
        -- 统一模式：所有模块使用同一个日志文件
        log_file_path = log_config.log_dir .. log_config.unique_file_log_file
    else
        -- 分离模式：每个模块使用独立的日志文件
        log_file_path = log_config.log_dir .. module_name .. ".log"
    end
    
    -- 返回日志记录器对象
    local log_instance = {
        enabled = log_config.enabled,
        module_name = module_name,
        log_file_path = log_file_path,
        timestamp_format = log_config.timestamp_format,
        unique_file_log = log_config.unique_file_log
    }
    
    -- 清空日志文件函数
    function log_instance:clear()
        if not self.enabled then
            return true
        end
        
        local success, error_msg = pcall(function()
            local file = io.open(self.log_file_path, "w")
            if file then
                file:close()
                return true
            else
                error("无法打开文件进行写入: " .. self.log_file_path)
            end
        end)
        
        if success then
            print("日志文件已清空: " .. self.log_file_path)
            return true
        else
            print("清空日志文件失败: " .. tostring(error_msg))
            return false
        end
    end
    
    -- 写入日志函数
    function log_instance:write(message, level)
        -- -- 打印log_instance中的属性值到日志文件: 
        -- -- 为了避免无限递归，先检查是否已经在记录属性
        -- if not self._logging_properties then
        --     self._logging_properties = true
            
        --     -- 写入属性到日志文件
        --     local properties_info = string.format("log_instance属性: enabled=%s, module_name=%s, log_file_path=%s, timestamp_format=%s",
        --         tostring(self.enabled), tostring(self.module_name), 
        --         tostring(self.log_file_path), tostring(self.timestamp_format))
            
        --     -- 直接写入文件，避免递归调用
        --     local timestamp = os.date(self.timestamp_format)
        --     local property_log_message = string.format("[%s] [DEBUG] [%s] %s\n", 
        --         timestamp, self.module_name, properties_info)
            
        --     local file = io.open(self.log_file_path, "a")
        --     if file then
        --         file:write(property_log_message)
        --         file:close()
        --     end
            
        --     self._logging_properties = false
        -- end
        
        -- 如果日志功能未开启，直接返回
        if not self.enabled then
            return
        end
        
        -- 如果message是nil，替换成空字符串
        if message == nil then
            message = ""
        end
        
        level = level or "INFO"
        local timestamp = os.date(self.timestamp_format)
        local log_message = string.format("[%s] [%s] [%s] %s\n", 
            timestamp, level, self.module_name, message)
        
        local success, error_msg = pcall(function()
            local file = io.open(self.log_file_path, "a")
            if file then
                file:write(log_message)
                file:close()
            else
                error("无法打开日志文件: " .. self.log_file_path)
            end
        end)
        
        if not success then
            print("写入日志失败: " .. tostring(error_msg))
        end
    end
    
    -- 便捷的日志级别函数
    function log_instance:info(message)
        self:write(message, "INFO")
    end
    
    function log_instance:debug(message)
        self:write(message, "DEBUG")
    end
    
    function log_instance:warn(message)
        self:write(message, "WARN")
    end
    
    function log_instance:error(message)
        self:write(message, "ERROR")
    end
    
    return log_instance
end

return logger
