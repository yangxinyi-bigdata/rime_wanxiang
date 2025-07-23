--[[
TCP套接字缓存实时状态同步系统
结合应用层缓存和TCP套接字，实现高效的实时双向通信
--]] -- 添加 ARM64 Homebrew 的 Lua 路径和项目lua目录
local function setup_lua_paths()
    -- 添加 ARM64 Homebrew 路径
    package.path = package.path .. ";/opt/homebrew/share/lua/5.4/?.lua;/opt/homebrew/share/lua/5.4/?/init.lua"
    package.cpath = package.cpath .. ";/opt/homebrew/lib/lua/5.4/?.so;/opt/homebrew/lib/lua/5.4/?/core.so"

    -- 添加项目lua目录到搜索路径（使用绝对路径）
    package.path = package.path ..
                       ";/Users/yangxinyi/Library/Rime/lua/?.lua;/Users/yangxinyi/Library/Rime/lua/?/init.lua"
end

setup_lua_paths()

local logger_module = require("logger")
local json = require("json") -- 项目中的json模块

-- 创建当前模块的日志记录器
local logger = logger_module.create("tcp_socket_cached_sync", {
    enabled = true,
    unified_log = false, -- 启用日志以便测试
    -- console_output = true -- 为特定实例启用控制台输出
})

local socket_ok, socket = pcall(require, "socket") -- TCP套接字通信
if not socket_ok then
    logger.error("无法加载 socket 模块")
end

local M = {}

-- 获取当前时间戳（毫秒）
local function get_current_time_ms()
    return os.time() * 1000 + math.floor((os.clock() % 1) * 1000)
end

-- TCP套接字缓存系统
local socket_cache_system = {
    -- rime环境变量
    env = nil,
    engine = nil,
    context = nil,

    -- TCP连接配置
    host = "127.0.0.1",
    port = 10086, -- Python服务端监听的端口
    client = nil, -- TCP客户端连接

    -- 连接状态管理
    is_connected = false,
    last_connect_attempt = 0,
    connect_retry_interval = 5000, -- 5秒重连间隔
    connection_failures = 0,
    max_connection_failures = 3,

    -- 应用层缓存
    state_cache = {},
    cache_ttl = 50, -- 50ms缓存有效期
    last_cache_time = 0,

    -- 缓存策略
    dedup_enabled = true, -- 启用去重
    batch_enabled = false, -- 启用批处理
    batch_size = 10,
    batch_buffer = {},

    -- 服务端检测缓存
    has_python_server = nil,
    server_check_interval = 10000, -- 10秒检查一次
    last_server_check = 0,

    -- 写入失败计数
    write_failure_count = 0,
    max_failure_count = 3,

    -- 读取相关
    last_read_attempt = 0,
    read_interval = 100, -- 100ms读取间隔

    -- 状态
    is_initialized = false
}

-- 初始化TCP套接字缓存系统
function M.init_socket_cache()
    logger.debug("socket_cache_system.is_initialized: " .. tostring(socket_cache_system.is_initialized))
    if socket_cache_system.is_initialized then
        return true
    end

    -- 尝试连接到Python服务端
    if M.connect_to_server() then
        socket_cache_system.is_initialized = true
        logger.debug("TCP套接字缓存系统初始化成功")
        return true
    end

    logger.warn("TCP套接字缓存系统初始化失败，但系统仍可工作（离线模式）")
    socket_cache_system.is_initialized = true -- 允许离线工作
    return true
end

-- 连接到Python服务端
function M.connect_to_server()
    local current_time = get_current_time_ms()

    -- 检查重连间隔
    if (current_time - socket_cache_system.last_connect_attempt) < socket_cache_system.connect_retry_interval then
        return socket_cache_system.is_connected
    end

    socket_cache_system.last_connect_attempt = current_time

    -- 如果已连接，检查连接状态
    if socket_cache_system.client and socket_cache_system.is_connected then
        -- 尝试发送ping来检查连接
        local success = pcall(function()
            socket_cache_system.client:send("ping\n")
        end)
        if success then
            return true
        else
            -- 连接已断开，关闭并重连
            M.disconnect_from_server()
        end
    end

    -- 尝试新连接
    logger.debug("尝试连接到Python服务端: " .. socket_cache_system.host .. ":" .. socket_cache_system.port)

    local client, err = socket.connect(socket_cache_system.host, socket_cache_system.port)
    if client then
        socket_cache_system.client = client
        socket_cache_system.is_connected = true
        socket_cache_system.connection_failures = 0

        -- 设置非阻塞模式
        client:settimeout(0.1)

        logger.debug("TCP连接建立成功")
        return true
    else
        socket_cache_system.connection_failures = socket_cache_system.connection_failures + 1
        logger.warn("TCP连接失败: " .. tostring(err) .. " (失败次数: " ..
                        socket_cache_system.connection_failures .. ")")
        return false
    end
end

-- 断开与服务端的连接
function M.disconnect_from_server()
    if socket_cache_system.client then
        pcall(function()
            socket_cache_system.client:close()
        end)
        socket_cache_system.client = nil
    end
    socket_cache_system.is_connected = false
    logger.debug("TCP连接已断开")
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
    local cache_entry = socket_cache_system.state_cache[data_hash]

    if cache_entry then
        return (current_time - cache_entry.timestamp) < socket_cache_system.cache_ttl
    end

    return false
end

-- 更新应用层缓存
function M.update_cache(data_hash, data)
    socket_cache_system.state_cache[data_hash] = {
        data = data,
        timestamp = get_current_time_ms()
    }

    -- 缓存大小控制
    local cache_size = 0
    for _ in pairs(socket_cache_system.state_cache) do
        cache_size = cache_size + 1
    end

    if cache_size > 100 then
        M.evict_old_cache()
    end
end

-- 清理过期缓存
function M.evict_old_cache()
    local current_time = get_current_time_ms()

    for hash, entry in pairs(socket_cache_system.state_cache) do
        if (current_time - entry.timestamp) > socket_cache_system.cache_ttl * 2 then
            socket_cache_system.state_cache[hash] = nil
        end
    end
end

-- 写入TCP套接字（带缓存）
function M.write_to_socket_cached(data)
    if not socket_cache_system.is_initialized then
        return false
    end

    local data_hash = M.calculate_hash(data)

    -- 检查去重缓存
    if socket_cache_system.dedup_enabled and M.is_cache_valid(data_hash) then
        return true -- 缓存命中，跳过写入
    end

    -- 批处理模式
    if socket_cache_system.batch_enabled then
        table.insert(socket_cache_system.batch_buffer, data)

        if #socket_cache_system.batch_buffer >= socket_cache_system.batch_size then
            M.flush_batch_to_socket()
        end
    else
        -- 直接写入（减少冗余日志）
        M.safe_write_to_socket(data)
    end

    -- 更新缓存
    M.update_cache(data_hash, data)

    return true
end

-- 检查Python服务端是否可用
function M.has_python_server()
    local current_time = get_current_time_ms()

    -- 使用缓存的检测结果
    if socket_cache_system.has_python_server ~= nil and (current_time - socket_cache_system.last_server_check) <
        socket_cache_system.server_check_interval then
        return socket_cache_system.has_python_server
    end

    -- 尝试连接检查服务端可用性
    local is_available = M.connect_to_server()

    -- 更新缓存
    socket_cache_system.has_python_server = is_available
    socket_cache_system.last_server_check = current_time

    return socket_cache_system.has_python_server
end

-- 安全写入TCP套接字
function M.safe_write_to_socket(data)
    if not M.has_python_server() then
        logger.warn("Python服务端不可用，跳过写入")
        return false
    end

    return M.write_to_socket_direct(data)
end

-- 直接写入TCP套接字
function M.write_to_socket_direct(data)
    if not socket_cache_system.client or not socket_cache_system.is_connected then
        logger.warn("TCP连接不可用")
        return false
    end

    local success, err = pcall(function()
        -- 发送JSON数据，以换行符结尾
        socket_cache_system.client:send(data .. "\n")
    end)

    if success then
        socket_cache_system.write_failure_count = 0
        return true
    else
        socket_cache_system.write_failure_count = socket_cache_system.write_failure_count + 1
        logger.error("TCP写入失败: " .. tostring(err) .. " (失败次数: " ..
                         socket_cache_system.write_failure_count .. ")")

        -- 如果失败次数过多，断开连接
        if socket_cache_system.write_failure_count >= socket_cache_system.max_failure_count then
            M.disconnect_from_server()
        end

        return false
    end
end

-- 批量刷新到TCP套接字
function M.flush_batch_to_socket()
    if #socket_cache_system.batch_buffer > 0 then
        for _, data in ipairs(socket_cache_system.batch_buffer) do
            M.write_to_socket_direct(data)
        end
        socket_cache_system.batch_buffer = {}
    end
end

-- 非阻塞读取TCP套接字数据
function M.read_from_socket()
    if not socket_cache_system.client or not socket_cache_system.is_connected then
        return nil
    end

    local line, err = socket_cache_system.client:receive("*l")

    if line then
        logger.debug("📥 从TCP套接字读取到原始数据: " .. line)
        return line
    elseif err == "timeout" then
        -- 超时表示当前无数据可读，这是正常情况
        return nil
    else
        -- 其他错误，可能是连接断开
        logger.warn("TCP读取错误: " .. tostring(err))
        M.disconnect_from_server()
        return nil
    end
end

-- 解析从Python端接收的数据
function M.parse_socket_data(data)
    if not data or #data == 0 then
        return nil
    end

    local success, parsed_data = pcall(json.decode, data)

    if success and parsed_data then
        logger.debug("🔍 解析TCP数据成功，命令类型: " .. tostring(parsed_data.command or "unknown"))
        return parsed_data
    else
        logger.error("❌ 解析TCP数据失败: " .. tostring(data))
        return nil
    end
end

-- 处理从Python端接收的命令
function M.handle_socket_command(parsed_data)
    if not parsed_data or not parsed_data.command then
        return false
    end

    local command = parsed_data.command
    logger.debug("🎯 处理TCP命令: " .. command)

    if command == "ping" then
        -- 响应ping命令
        logger.debug("📞 收到ping命令")
        M.write_to_socket_direct('{"response": "pong"}')
        return true
    elseif command == "set_option" then

        -- 修改设置
        logger.debug("parsed_data.option_value: " .. tostring(parsed_data.option_value))
        if socket_cache_system.context then
            if socket_cache_system.context:get_option(parsed_data.option_name) ~= parsed_data.option_value  then
                socket_cache_system.context:set_option(parsed_data.option_name, parsed_data.option_value)
                logger.debug("已设置选项: " .. tostring(parsed_data.option_name) .. " = " .. tostring(parsed_data.option_value))
            end
            -- local response = {
            --     response = "option_set",
            --     option_name = parsed_data.option_name,
            --     option_value = option_value,
            --     success = true,
            --     timestamp = get_current_time_ms(),
            --     responding_to = "set_option"
            -- }
            local response = {
                response = "option_set",
                option_name = parsed_data.option_name,
                option_value = option_value,
                success = true,
                timestamp = get_current_time_ms(),
                responding_to = "set_option"
            }
            M.write_to_socket_direct(M.serialize_state(response))
        else
            logger.warn("context为nil，无法设置选项: " .. tostring(parsed_data.option_name))
            local response = {
                response = "option_set",
                option_name = parsed_data.option_name,
                option_value = option_value,
                success = false,
                error = "context is nil",
                timestamp = get_current_time_ms(),
                responding_to = "set_option"
            }
            M.write_to_socket_direct(M.serialize_state(response))
        end
        return true

    elseif command == "server_ping" then
        -- 响应服务端ping命令
        logger.debug("📞 收到服务端ping命令")
        local response = {
            response = "pong",
            client_id = "lua_tcp_cache_client",
            timestamp = get_current_time_ms(),
            responding_to = "server_ping"
        }
        M.write_to_socket_direct(M.serialize_state(response))
        return true
    elseif command == "server_status_check" then
        -- 响应服务端状态检查
        logger.debug("📊 收到服务端状态检查命令")
        if parsed_data.server_info then
            logger.debug("   🔍 服务端信息: 运行时长=" ..
                             tostring(parsed_data.server_info.uptime or "unknown") .. "s")
            logger.debug("   📈 服务端统计: 总消息=" ..
                             tostring(parsed_data.server_info.total_messages or "unknown"))
            logger.debug("   👥 活跃客户端: " .. tostring(parsed_data.server_info.active_clients or "unknown"))
        end
        local stats = M.get_cache_stats()
        local response = {
            response = "client_status",
            client_info = {
                cache_size = stats.cache_size,
                connection_failures = stats.connection_failures,
                write_failures = stats.write_failure_count,
                is_connected = stats.is_connected,
                client_type = "lua_tcp_cache_sync"
            },
            timestamp = get_current_time_ms(),
            responding_to = "server_status_check"
        }
        M.write_to_socket_direct(M.serialize_state(response))
        return true
    elseif command == "server_broadcast" then
        -- 处理服务端广播消息
        local message = parsed_data.message or "无消息内容"
        local broadcast_id = parsed_data.broadcast_id or "unknown"
        local timestamp = parsed_data.timestamp or "unknown"
        logger.debug("📢 收到服务端广播消息:")
        logger.debug("   📝 内容: " .. message)
        logger.debug("   🆔 广播ID: " .. tostring(broadcast_id))
        logger.debug("   ⏰ 时间戳: " .. tostring(timestamp))

        local response = {
            response = "broadcast_received",
            client_id = "lua_tcp_cache_client",
            broadcast_id = broadcast_id,
            timestamp = get_current_time_ms(),
            responding_to = "server_broadcast"
        }
        M.write_to_socket_direct(M.serialize_state(response))
        return true
    elseif command == "get_status" then
        -- 返回当前状态
        logger.debug("📊 收到状态查询命令")
        local stats = M.get_cache_stats()
        local response = {
            response = "status",
            data = stats
        }
        M.write_to_socket_direct(M.serialize_state(response))
        return true
    elseif command == "clear_cache" then
        -- 清理缓存
        M.force_flush_cache()
        logger.debug("🧹 收到清理缓存命令")
        M.write_to_socket_direct('{"response": "cache_cleared"}')
        return true
    else
        logger.warn("❓ 未知的TCP命令: " .. command)
        return false
    end
end

-- 定期处理TCP套接字数据
function M.process_socket_data()
    -- 减少冗余日志，只在有数据时输出
    local data = M.read_from_socket()
    if data then
        logger.debug("🎯 成功接收到服务端完整消息: " .. data)
        local parsed_data = M.parse_socket_data(data)
        if parsed_data then
            logger.debug("📨 消息解析成功，开始处理命令")
            M.handle_socket_command(parsed_data)
            return true -- 返回成功标志
        else
            logger.warn("⚠️  消息解析失败")
            return false
        end
    else
        return false -- 没有接收到数据
    end
end

-- 和管理端进行数据交换
function M.sync_with_server()
    local success, error_msg = pcall(function()
        local current_time = get_current_time_ms()

        local context = socket_cache_system.context
        -- 构建状态数据
        local state_data = {
            is_composing = context:is_composing(),
            input_mode = context:get_option("ascii_punct"),
            -- input_text = context.input or "",
            timestamp = current_time
        }

        -- 序列化状态数据
        local json_data = M.serialize_state(state_data)

        -- 写入TCP套接字缓存
        M.write_to_socket_cached(json_data)

        -- 处理来自Python端的数据
        if socket_cache_system.is_initialized and socket_cache_system.is_connected then
            M.process_socket_data()
        end

        -- logger.debug("状态更新成功: " .. tostring(json_data))
    end)

    if not success then
        logger.error("状态更新失败: " .. tostring(error_msg))
        return false
    end

    return true
end

-- 序列化状态数据
function M.serialize_state(state)
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
    M.flush_batch_to_socket()

    -- 清空应用层缓存
    socket_cache_system.state_cache = {}

    logger.debug("TCP套接字缓存已强制刷新")
end

-- 缓存统计信息
function M.get_cache_stats()
    local stats = {
        cache_size = 0,
        batch_size = #socket_cache_system.batch_buffer,
        hit_ratio = 0,
        is_initialized = socket_cache_system.is_initialized,
        is_connected = socket_cache_system.is_connected,
        has_python_server = socket_cache_system.has_python_server,
        connection_failures = socket_cache_system.connection_failures,
        write_failure_count = socket_cache_system.write_failure_count,
        host = socket_cache_system.host,
        port = socket_cache_system.port
    }

    for _ in pairs(socket_cache_system.state_cache) do
        stats.cache_size = stats.cache_size + 1
    end

    return stats
end

-- 初始化系统
function M.init(env)
    logger.debug("TCP套接字缓存状态同步系统初始化")
    if env then
        socket_cache_system.engine = env.engine
        socket_cache_system.context = socket_cache_system.engine.context
        socket_cache_system.config = socket_cache_system.engine.schema.config
    else
        socket_cache_system.engine = nil
        socket_cache_system.context = nil
        socket_cache_system.config = nil
        logger.debug("未传入env, context,engine,config全部设置为空.")
    end

    -- 初始化TCP套接字缓存
    if not M.init_socket_cache() then
        logger.error("TCP套接字缓存初始化失败")
        return false
    end

    logger.debug("TCP套接字缓存系统初始化完成")
    return true
end

-- 清理资源
function M.fini(env)
    logger.debug("TCP套接字缓存系统清理")

    -- 强制刷新缓存
    M.force_flush_cache()

    -- 断开TCP连接
    M.disconnect_from_server()

    logger.debug("TCP套接字缓存系统清理完成")
end

-- 公开接口：手动处理TCP套接字数据
function M.manual_process_socket_data()
    return M.process_socket_data()
end

-- 公开接口：获取连接信息
function M.get_connection_info()
    return {
        host = socket_cache_system.host,
        port = socket_cache_system.port,
        is_connected = socket_cache_system.is_connected
    }
end

-- 公开接口：检查TCP连接状态
function M.is_socket_ready()
    return socket_cache_system.is_initialized and socket_cache_system.is_connected
end

-- 公开接口：设置连接参数
function M.set_connection_params(host, port)
    if host then
        socket_cache_system.host = host
    end
    if port then
        socket_cache_system.port = port
    end
    logger.debug("连接参数已更新: " .. socket_cache_system.host .. ":" .. socket_cache_system.port)
end

return M
