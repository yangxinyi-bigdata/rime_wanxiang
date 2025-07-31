--[[
命名管道缓存实时状态同步系统
结合应用层缓存和内核缓存，实现高效的实时同步
--]]

local logger_module = require("logger")


-- 创建当前模块的日志记录器
local logger = logger_module.create("named_pipe_cached_sync", {
    enabled = true,
    unique_file_log = false -- 启用日志以便测试
})

local json_ok, json = pcall(require, "json")  -- 这个处理json
if not json_ok then
    logger.error("无法加载 json 模块")
end

-- 添加 ARM64 Homebrew 的 Lua 路径
local function setup_lua_paths()
    -- 保存原始路径
    local original_path = package.path
    local original_cpath = package.cpath

    -- 添加 ARM64 Homebrew 路径
    package.path = package.path .. ";/opt/homebrew/share/lua/5.4/?.lua;/opt/homebrew/share/lua/5.4/?/init.lua"
    package.cpath = package.cpath .. ";/opt/homebrew/lib/lua/5.4/?.so;/opt/homebrew/lib/lua/5.4/?/core.so"

    logger.info("已添加 ARM64 Homebrew Lua 路径")
end

setup_lua_paths()

local socket_ok, socket = pcall(require, "socket")   -- 只需要 select 功能
if not socket_ok then
    logger.error("无法加载 socket 模块")
end

local M = {}

-- 获取当前时间戳（毫秒）
local function get_current_time_ms()
    return os.time() * 1000 + math.floor((os.clock() % 1) * 1000)
end

-- 命名管道缓存系统
local pipe_cache_system = {
    -- 原有管道：Lua写入，Python读取
    pipe_name = "/tmp/rime_state_pipe",
    pipe_handle = nil,
    
    -- 反向管道：Python写入，Lua读取
    reverse_pipe_name = "/tmp/rime_reverse_pipe",
    reverse_pipe_handle = nil,
    reverse_pipe_fd = nil,  -- socket select使用的文件描述符
    reverse_read_buffer = "",  -- 累积残留字节缓冲区
    
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
    
    -- 反向管道相关
    has_python_writer = nil,
    last_writer_check = 0,
    last_reverse_read = 0,
    reverse_read_interval = 100,  -- 100ms读取间隔
    
    -- 状态
    is_initialized = false,
    reverse_initialized = false
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

-- 初始化反向管道（Python写入，Lua读取）
function M.init_reverse_pipe()
    logger.info("pipe_cache_system.reverse_initialized: " .. tostring(pipe_cache_system.reverse_initialized))
    if pipe_cache_system.reverse_initialized then
        return true
    end
    
    -- 创建反向命名管道
    local success = os.execute("mkfifo " .. pipe_cache_system.reverse_pipe_name .. " 2>/dev/null")
    
    -- 初始化成功，实际的文件打开在首次读取时进行
    pipe_cache_system.reverse_initialized = true
    logger.info("反向管道初始化成功 (luasocket select模式)")
    return true
end

-- 打开FIFO（仅一次）
local function open_fifo()
    if pipe_cache_system.reverse_pipe_fd then 
        return true 
    end

    -- 以 "r" 打开，非阻塞标志由 select 完成
    pipe_cache_system.reverse_pipe_fd = io.open(pipe_cache_system.reverse_pipe_name, "r")
    if not pipe_cache_system.reverse_pipe_fd then
        logger.error("无法打开 FIFO: " .. pipe_cache_system.reverse_pipe_name)
        return false
    end
    pipe_cache_system.reverse_pipe_fd:setvbuf("no")   -- 关闭缓冲，实时读到数据
    logger.info("FIFO 已打开: " .. pipe_cache_system.reverse_pipe_name)
    return true
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
        "pgrep python | xargs -I {} lsof -p {} 2>/dev/null | grep -c %s",
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

-- 检查反向管道的Python写入端
function M.has_reverse_pipe_writer()
    local current_time = get_current_time_ms()
    
    -- 使用缓存的检测结果
    if pipe_cache_system.has_python_writer ~= nil and 
       (current_time - pipe_cache_system.last_writer_check) < pipe_cache_system.reader_check_interval then
        return pipe_cache_system.has_python_writer
    end
    
    -- 检查Python进程是否在写入反向管道
    local cmd = string.format(
        "pgrep python | xargs -I {} lsof -p {} 2>/dev/null | grep -c %s",
        -- pipe_cache_system.reverse_pipe_name
        pipe_cache_system.pipe_name
    )
    local handle = io.popen(cmd)
    local result = handle:read("*a")
    handle:close()
    
    local writer_count = tonumber(result) or 0
    -- 更新缓存
    pipe_cache_system.has_python_writer = writer_count > 0
    pipe_cache_system.last_writer_check = current_time
    logger.warn("是否进程是否在写入反向管道pipe_cache_system.has_python_writer: " .. tostring(pipe_cache_system.has_python_writer))
    
    return pipe_cache_system.has_python_writer
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

-- 非阻塞读取一行（带缓冲）
local function read_fifo_nb()
    if not pipe_cache_system.reverse_pipe_fd then
        if not open_fifo() then 
            return nil 
        end
    end

    -- 1. 利用 select 检查 FIFO 是否可读（超时 0 => 立即返回）
    logger.info("socket.select检查: ")
    local can_read = socket.select({pipe_cache_system.reverse_pipe_fd}, nil, 0)
    logger.info("socket.select检查结果can_read: " .. tostring(can_read))
    if not can_read[1] then
        logger.info("当前无数据, read_fifo_nb返回空")
        return nil   -- 当前无数据
    else
        logger.info("当前有数据, 开始读取管道数据.")
    end

    -- 2. 读尽量多的字节（非阻塞，因为 select 告诉我们有数据）
    local chunk = pipe_cache_system.reverse_pipe_fd:read("*a")
    if not chunk or chunk == "" then
        -- 对端关闭；关闭 fd，下次重新 open
        pipe_cache_system.reverse_pipe_fd:close()
        pipe_cache_system.reverse_pipe_fd = nil
        return nil
    end

    -- 3. 拼到缓冲区，按行切分
    pipe_cache_system.reverse_read_buffer = pipe_cache_system.reverse_read_buffer .. chunk
    local line, rest = pipe_cache_system.reverse_read_buffer:match("([^\n\r]*)\r?\n(.*)")
    if line then
        pipe_cache_system.reverse_read_buffer = rest or ""
        logger.info("rest: " .. tostring(line))
        return line
    end
    logger.info("没有完整行，先返回 nil，下次继续")
    -- 4. 没有完整行，先返回 nil，下次继续
    return nil
end

-- 从反向管道读取数据（使用luasocket select非阻塞方法）
function M.read_from_reverse_pipe()
    if not pipe_cache_system.reverse_initialized then
        return nil
    end
    
    -- 检查是否有写入端
    if not M.has_reverse_pipe_writer() then
        logger.info("没有反向python写入端")
        return nil
    end
    
    local line = read_fifo_nb()
    if line and #line > 0 then
        logger.info("从反向管道读取到数据 (luasocket select): " .. line)
        return line
    end
    
    return nil
end

-- 解析从Python端接收的数据
function M.parse_reverse_data(data)
    if not data or #data == 0 then
        return nil
    end
    
    local success, parsed_data = pcall(json.decode, data)
    
    if success and parsed_data then
        logger.info("解析反向数据成功: " .. tostring(parsed_data.command or "unknown"))
        return parsed_data
    else
        logger.error("解析反向数据失败: " .. tostring(data))
        return nil
    end
end

-- 处理从Python端接收的命令
function M.handle_reverse_command(parsed_data)
    if not parsed_data or not parsed_data.command then
        return false
    end
    
    local command = parsed_data.command
    logger.info("处理反向命令: " .. command)
    
    if command == "ping" then
        -- 响应ping命令
        logger.info("收到ping命令")
        return true
    elseif command == "get_status" then
        -- 返回当前状态
        logger.info("收到状态查询命令")
        return true
    elseif command == "clear_cache" then
        -- 清理缓存
        M.force_flush_cache()
        logger.info("收到清理缓存命令")
        return true
    else
        logger.warn("未知的反向命令: " .. command)
        return false
    end
end

-- 定期处理反向管道数据
function M.process_reverse_pipe()
    logger.info("开始处理反向管道数据")
    local data = M.read_from_reverse_pipe()
    if data then
        local parsed_data = M.parse_reverse_data(data)
        if parsed_data then
            M.handle_reverse_command(parsed_data)
        end
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
        
        -- 只有在反向管道初始化成功时才处理反向管道数据
        if pipe_cache_system.reverse_initialized then
            M.process_reverse_pipe()
        end
        
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
    -- local json_str = "{\n"
    -- json_str = json_str .. '  "is_composing": ' .. tostring(state.is_composing) .. ',\n'
    -- json_str = json_str .. '  "input_mode": "' .. state.input_mode .. '",\n'
    -- json_str = json_str .. '  "input_text": "' .. state.input_text .. '",\n'
    -- json_str = json_str .. '  "timestamp": ' .. state.timestamp .. '\n'
    -- json_str = json_str .. "}"
    -- logger.debug("手工处理json_str: " .. tostring(json_str))
    local success, json_str = pcall(json.encode, state)
    if success then
        logger.debug("JSON序列化成功")
        logger.debug("json_str: " .. tostring(json_str))
        return json_str
    else
        logger.error("JSON序列化失败")
        logger.debug("json_str: " .. tostring(json_str))
        return nil
    end
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
        is_initialized = pipe_cache_system.is_initialized,
        reverse_initialized = pipe_cache_system.reverse_initialized,
        has_python_reader = pipe_cache_system.has_python_reader,
        has_python_writer = pipe_cache_system.has_python_writer
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
    
    -- 初始化反向管道
    if not M.init_reverse_pipe() then
        logger.warn("反向管道初始化失败，但不影响主要功能")
    end

    logger.info("命名管道缓存系统初始化完成")
    return true
end


-- 清理资源
function M.fini(env)
    logger.info("命名管道缓存系统清理")
    
    -- 强制刷新缓存
    M.force_flush_cache()
    
    -- 关闭原有管道
    if pipe_cache_system.pipe_handle then
        pipe_cache_system.pipe_handle:close()
    end
    
    -- 关闭反向管道文件描述符
    if pipe_cache_system.reverse_pipe_fd then
        pipe_cache_system.reverse_pipe_fd:close()
        pipe_cache_system.reverse_pipe_fd = nil
    end
    
    -- 关闭反向管道（传统方式，兼容）
    if pipe_cache_system.reverse_pipe_handle then
        pipe_cache_system.reverse_pipe_handle:close()
    end
    
    -- 清理管道文件
    os.remove(pipe_cache_system.pipe_name)
    os.remove(pipe_cache_system.reverse_pipe_name)
    
    logger.info("命名管道缓存系统清理完成")
end

-- 公开接口：手动处理反向管道数据
function M.manual_process_reverse_pipe()
    return M.process_reverse_pipe()
end

-- 公开接口：获取反向管道名称
function M.get_reverse_pipe_name()
    return pipe_cache_system.reverse_pipe_name
end

-- 公开接口：检查反向管道状态
function M.is_reverse_pipe_ready()
    return pipe_cache_system.reverse_initialized and M.has_reverse_pipe_writer()
end

return M
