-- Rime输入法日志工具模块
-- 提供统一的日志记录功能

local logger = {}

-- 默认配置
local default_config = {
    enabled = true,
    log_dir = "/Users/yangxinyi/Library/Rime/log/",
    timestamp_format = "%Y-%m-%d %H:%M:%S"
}

-- 创建日志记录器
function logger.create(module_name, config)
    config = config or {}
    
    -- 合并配置
    local log_config = {}
    for k, v in pairs(default_config) do
        log_config[k] = config[k] or v
    end
    
    -- 生成日志文件路径
    local log_file_path = log_config.log_dir .. module_name .. ".log"
    
    -- 返回日志记录器对象
    local log_instance = {
        enabled = log_config.enabled,
        module_name = module_name,
        log_file_path = log_file_path,
        timestamp_format = log_config.timestamp_format
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
        -- 如果日志功能未开启，直接返回
        if not self.enabled then
            return
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
