--[[
命名管道缓存实时状态同步系统
结合应用层缓存和内核缓存，实现高效的实时同步

20250718 暂存版本
--]]

local logger_module = require("logger")
local json = require("json")  -- 如果可用

-- 创建当前模块的日志记录器
local logger = logger_module.create("named_pipe_cached_sync", {
    enabled = true,
    unified_log = false -- 启用日志以便测试
})

local M = {}

-- 获取当前时间戳（毫秒）
local function get_current_time_ms()
    return os.time() * 1000 + math.floor((os.clock() % 1) * 1000)
end

-- 命名管道缓存系统
local pipe_cache_system = {
    pipe_name = "/tmp/rime_state_pipe",
    pipe_handle = nil,
    
    -- 应用层缓存
    state_cache = {},
    cache_ttl = 50,  -- 50ms缓存有效期
    last_cache_time = 0,
    
    -- 缓存策略,
    dedup_enabled = true,  -- 启用去重
    batch_enabled = false,  -- 启用批处理
    batch_size = 10,
    batch_buffer = {},

    -- 读取端检测缓存
    has_python_reader = nil,
    reader_check_interval = 10000,  -- 1秒检查一次
    last_reader_check = 0,
    -- 添加写入失败计数
    write_failure_count = 0,
    max_failure_count = 3,
    -- 状态
    is_initialized = false
}



-- 初始化命名管道缓存系统
function M.init_pipe_cache()
    logger.info("pipe_cache_system.is_initialized: " .. tostring(pipe_cache_system.is_initialized))
    if pipe_cache_system.is_initialized then
        return true
    end
    
    -- 创建命名管道
    local success = os.execute("mkfifo " .. pipe_cache_system.pipe_name .. " 2>/dev/null")
    
    -- 以非阻塞模式打开管道
    pipe_cache_system.pipe_handle = io.open(pipe_cache_system.pipe_name, "w+")
    if pipe_cache_system.pipe_handle then
        -- 设置内核缓存策略
        pipe_cache_system.pipe_handle:setvbuf("line", 1024)  -- 1KB行缓存
        pipe_cache_system.is_initialized = true
        logger.info("命名管道缓存系统初始化成功")
        return true
    end
    
    logger.error("命名管道缓存系统初始化失败")
    return false
end

-- 计算数据哈希（简单实现）
function M.calculate_hash(data)
    local hash = 0
    for i = 1, #data do
        hash = hash + string.byte(data, i)
    end
    return hash % 10000
end

-- 检查缓存是否有效
function M.is_cache_valid(data_hash)
    local current_time = get_current_time_ms()
    local cache_entry = pipe_cache_system.state_cache[data_hash]
    
    if cache_entry then
        return (current_time - cache_entry.timestamp) < pipe_cache_system.cache_ttl
    end
    
    return false
end

-- 更新应用层缓存
function M.update_cache(data_hash, data)
    pipe_cache_system.state_cache[data_hash] = {
        data = data,
        timestamp = get_current_time_ms()
    }
    
    -- 缓存大小控制
    local cache_size = 0
    for _ in pairs(pipe_cache_system.state_cache) do
        cache_size = cache_size + 1
    end
    
    if cache_size > 100 then
        M.evict_old_cache()
    end
end

-- 清理过期缓存
function M.evict_old_cache()
    local current_time = get_current_time_ms()
    
    for hash, entry in pairs(pipe_cache_system.state_cache) do
        if (current_time - entry.timestamp) > pipe_cache_system.cache_ttl * 2 then
            pipe_cache_system.state_cache[hash] = nil
        end
    end
end

-- 写入命名管道（带缓存）
function M.write_to_pipe_cached(data)
    if not pipe_cache_system.is_initialized then
        return false
    end
    
    local data_hash = M.calculate_hash(data)
    
    -- 检查去重缓存
    if pipe_cache_system.dedup_enabled and M.is_cache_valid(data_hash) then
        return true  -- 缓存命中，跳过写入
    end
    
    -- 批处理模式
    if pipe_cache_system.batch_enabled then
        table.insert(pipe_cache_system.batch_buffer, data)
        
        if #pipe_cache_system.batch_buffer >= pipe_cache_system.batch_size then
            M.flush_batch_to_pipe()
        end
    else
        -- 直接写入
        logger.info("M.write_to_pipe_direct(data) 写入数据")
        -- M.write_to_pipe_direct(data)
        logger.info("M.safe_write_to_pipe(data) 安全写入数据")
        M.safe_write_to_pipe(data)
    end
    
    -- 更新缓存
    M.update_cache(data_hash, data)
    
    return true
end

-- 优化的读取端检查
function M.has_pipe_reader()
    local current_time = get_current_time_ms()
    -- 使用缓存的检测结果
    -- logger.debug("pipe_cache_system.has_python_reader 当前: " .. tostring(pipe_cache_system.has_python_reader) )
    -- logger.debug("current_time当前: " .. tostring(current_time) .. "  pipe_cache_system.last_reader_check: " .. tostring(pipe_cache_system.last_reader_check))
    
    if pipe_cache_system.has_python_reader ~= nil and 
       (current_time - pipe_cache_system.last_reader_check) < pipe_cache_system.reader_check_interval then
        -- logger.warn("条件不满足直接返回缓存")
        return pipe_cache_system.has_python_reader
    end
    
    -- 构建命令，使用 grep -c 直接返回计数
    local cmd = string.format(
        "lsof -p $(pgrep -f python3) 2>/dev/null | grep -c '%s'",
        pipe_cache_system.pipe_name
    )
    local handle = io.popen(cmd)
    local result = handle:read("*a")
    handle:close()
    
    local reader_count = tonumber(result) or 0
    -- 更新缓存
    -- logger.warn("pipe_cache_system.has_python_reader更新后: " .. tostring(pipe_cache_system.has_python_reader))
    pipe_cache_system.has_python_reader = reader_count > 0
    pipe_cache_system.last_reader_check = current_time
    
    return pipe_cache_system.has_python_reader
end

-- 安全写入
function M.safe_write_to_pipe(data)
    if not M.has_pipe_reader() then
        logger.warn("管道无读取端，跳过写入")
        return false
    end
    
    return M.write_to_pipe_direct(data)
end

-- 直接写入管道
function M.write_to_pipe_direct(data)
    if pipe_cache_system.pipe_handle then
        pipe_cache_system.pipe_handle:write(data .. "\n")
        pipe_cache_system.pipe_handle:flush()
        
    end
    return true
end

-- 批量刷新到管道
function M.flush_batch_to_pipe()
    if #pipe_cache_system.batch_buffer > 0 then
        local batch_data = table.concat(pipe_cache_system.batch_buffer, "\n")
        M.write_to_pipe_direct(batch_data)
        pipe_cache_system.batch_buffer = {}
    end
end

-- 状态更新（集成缓存）
function M.update_state_cached(context)
    local success, error_msg = pcall(function()
        local current_time = get_current_time_ms()
        
        -- 构建状态数据
        local state_data = {
            is_composing = context:is_composing(),
            input_mode = context:get_option("ascii_mode") and "ascii" or "chinese",
            input_text = context.input or "",
            timestamp = current_time
        }
        
        -- 序列化状态数据
        local json_data = M.serialize_state(state_data)
        
        -- 写入缓存管道
        M.write_to_pipe_cached(json_data)
        -- logger.info("状态更新成功: " .. tostring(json_data))
    end)
    
    if not success then
        logger.error("状态更新失败: " .. tostring(error_msg))
        return false
    end
    
    return true
end

-- 序列化状态数据
function M.serialize_state(state)
    local json_str = "{\n"
    json_str = json_str .. '  "is_composing": ' .. tostring(state.is_composing) .. ',\n'
    json_str = json_str .. '  "input_mode": "' .. state.input_mode .. '",\n'
    json_str = json_str .. '  "input_text": "' .. state.input_text .. '",\n'
    json_str = json_str .. '  "timestamp": ' .. state.timestamp .. '\n'
    json_str = json_str .. "}"
    
    return json_str
end

-- 强制刷新缓存
function M.force_flush_cache()
    -- 刷新批处理缓存
    M.flush_batch_to_pipe()
    
    -- 清空应用层缓存
    pipe_cache_system.state_cache = {}
    
    -- 强制刷新内核缓存
    if pipe_cache_system.pipe_handle then
        pipe_cache_system.pipe_handle:flush()
    end
end

-- 缓存统计信息
function M.get_cache_stats()
    local stats = {
        cache_size = 0,
        batch_size = #pipe_cache_system.batch_buffer,
        hit_ratio = 0,
        is_initialized = pipe_cache_system.is_initialized
    }
    
    for _ in pairs(pipe_cache_system.state_cache) do
        stats.cache_size = stats.cache_size + 1
    end
    
    return stats
end


-- 独立的初始化方式
-- 初始化系统
function M.init()
    logger.info("命名管道缓存状态同步系统初始化")
    
    -- 初始化管道缓存
    if not M.init_pipe_cache() then
        logger.error("管道缓存初始化失败")
        return false
    end

    logger.info("命名管道缓存系统初始化完成")
    return true
end


-- 清理资源
function M.fini(env)
    logger.info("命名管道缓存系统清理")
    
    -- 强制刷新缓存
    M.force_flush_cache()
    
    -- 关闭管道
    if pipe_cache_system.pipe_handle then
        pipe_cache_system.pipe_handle:close()
    end
    
    -- 清理管道文件
    os.remove(pipe_cache_system.pipe_name)
    
    logger.info("命名管道缓存系统清理完成")
end

return M
