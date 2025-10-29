--[[
双端口 ZeroMQ 实时同步系统（Lua 侧客户端）

设计概览（重要概念与约束）：
- Rime 状态通道 使用 ZeroMQ DEALER 套接字：单通道异步发送，始终保持非阻塞并容忍服务端延迟响应。
- AI 转换通道 使用 ZeroMQ DEALER 套接字：允许异步/多帧交互，更适合流式内容。
- 超时策略：通过 set_sndtimeo/set_rcvtimeo 控制毫秒级超时，小范围轮询避免阻塞。
- 接收队列：每个通道维护一个轻量队列，先读队列再读 socket，避免丢帧。

文件结构（只列关键函数）：
- ensure_zmq_context/close_zmq_socket/… 基础设施与超时配置
- connect_to_rime_server/connect_to_ai_server 建立 DEALER 连接
- write_to_rime_socket/read_from_rime_socket 发送/接收状态数据（异步、无阻塞）
- write_to_ai_socket/read_from_ai_socket/flush_ai_socket_buffer AI 通道 I/O
- read_latest_from_ai_socket 聚合最新一条消息
- parse_socket_data/handle_socket_command 上层协议解析与命令处理
--]] -- 添加 ARM64 Homebrew 的 Lua 路径和项目lua目录
-- local function setup_lua_paths()
--     -- 添加 ARM64 Homebrew 路径
--     package.path = package.path .. ";/opt/homebrew/share/lua/5.4/?.lua;/opt/homebrew/share/lua/5.4/?/init.lua"
--     package.cpath = package.cpath .. ";/opt/homebrew/lib/lua/5.4/?.so;/opt/homebrew/lib/lua/5.4/?/core.so"

--     -- 添加项目lua目录到搜索路径（使用绝对路径）
--     package.path = package.path ..
--                        ";/Users/yangxinyi/Library/Rime/lua/?.lua;/Users/yangxinyi/Library/Rime/lua/?/init.lua"
-- end


local function append_paths(current, entries)
  for _, entry in ipairs(entries) do
    if not current:find(entry, 1, true) then
      current = current .. ";" .. entry
    end
  end
  return current
end

local function setup_lua_paths()
  -- Homebrew 安装目录
  package.path  = append_paths(package.path, {
    "/opt/homebrew/share/lua/5.4/?.lua",
    "/opt/homebrew/share/lua/5.4/?/init.lua",
  })
  package.cpath = append_paths(package.cpath, {
    "/opt/homebrew/lib/lua/5.4/?.so",
    "/opt/homebrew/lib/lua/5.4/?/core.so",
  })

  -- 安装在 /opt/lzmq 的模块（含 lzmq.so、lzmq/timer.so 等）
  package.path  = append_paths(package.path, {
    "/opt/lzmq/lib/lua/?.lua",
    "/opt/lzmq/lib/lua/?/init.lua",
  })
  package.cpath = append_paths(package.cpath, {
    "/opt/lzmq/lib/lua/?.so",
    "/opt/lzmq/lib/lua/?/?.so",
  })

  -- 项目自身 Lua 脚本
  package.path  = append_paths(package.path, {
    "/Users/yangxinyi/Library/Rime/lua/?.lua",
    "/Users/yangxinyi/Library/Rime/lua/?/init.lua",
  })
end

setup_lua_paths()

local logger_module = require("logger")
local json = require("json") -- 项目中的json模块

-- 创建当前模块的日志记录器
local logger = logger_module.create("tcp_zmq", {
    enabled = true,
    unique_file_log = false, -- 启用日志以便测试
    log_level = "DEBUG"
    -- console_output = true -- 为特定实例启用控制台输出
})

local zmq_module_ok, zmq_module_or_err = pcall(require, "lzmq")
local zmq = nil
if zmq_module_ok then
    zmq = zmq_module_or_err -- 加载成功则保存模块引用
else
    -- 加载失败时记录错误日志（随后相关函数会做兜底判空）
    logger.error("无法加载 lzmq 模块: " .. tostring(zmq_module_or_err))
end

local ZMQ_DONTWAIT = zmq and zmq.DONTWAIT or nil

local tcp_zmq = {}

-- 存储更新函数的引用
tcp_zmq.update_all_modules_config = nil

-- 全局开关状态（仅内存，不落盘）。键为 option 名，值为 boolean。
tcp_zmq.global_option_state = {}
tcp_zmq.update_global_option_state = false

-- 记录一个全局开关值
function tcp_zmq.set_global_option(name, value)
    if type(name) ~= "string" then
        return
    end
    local bool_val = not not value
    if tcp_zmq.global_option_state[name] ~= bool_val then
        tcp_zmq.global_option_state[name] = bool_val
        logger.debug(string.format("记录全局开关: %s = %s", name, tostring(bool_val)))
    end
end

-- 将已记录的全局开关应用到当前 context，返回应用的数量
function tcp_zmq.apply_global_options_to_context(context)
    if not context then
        return 0
    end
    local applied = 0
    for name, val in pairs(tcp_zmq.global_option_state) do
        if context:get_option(name) ~= val then
            context:set_option(name, val)
            applied = applied + 1
            logger.debug(string.format("应用全局开关到context: %s = %s", name, tostring(val)))
        end
    end
    return applied
end

-- 设置配置更新处理器（由外部调用）, 可以由调用者传入一个函数handler, 将这个函数绑定到config_update_handler中.
function tcp_zmq.set_config_update_handler(config_update_function, property_update_function)
    tcp_zmq.update_all_modules_config = config_update_function
    tcp_zmq.property_update_function = property_update_function
end

-- 更新配置
function tcp_zmq.update_configs(config)
    if tcp_zmq.update_all_modules_config then
        tcp_zmq.update_all_modules_config(config)
    end
end

-- 更新context属性
function tcp_zmq.update_property(property_name, property_value)
    if tcp_zmq.property_update_function then
        tcp_zmq.property_update_function(property_name, property_value)
    end
end

-- 遍历表字段并根据类型更新配置，仅在值发生变化时写入
local function update_config_field(config, field_path, field_value)
    -- 根据不同类型调用对应的getter与setter
    local value_type = type(field_value)
    if value_type == "boolean" then
        local current = config:get_bool(field_path)
        if current ~= field_value then
            config:set_bool(field_path, field_value)
            logger.debug("表字段更新布尔值: " .. field_path .. " = " .. tostring(field_value))
            return true
        end
    elseif value_type == "number" then
        if field_value == math.floor(field_value) then
            local current = config:get_int(field_path)
            if current ~= field_value then
                config:set_int(field_path, field_value)
                logger.debug("表字段更新整数: " .. field_path .. " = " .. tostring(field_value))
                return true
            end
        else
            local current = config:get_double(field_path)
            if current ~= field_value then
                config:set_double(field_path, field_value)
                logger.debug("表字段更新浮点数: " .. field_path .. " = " .. tostring(field_value))
                return true
            end
        end
    elseif value_type == "string" then
        local current = config:get_string(field_path)
        if current ~= field_value then
            config:set_string(field_path, field_value)
            logger.debug("表字段更新字符串: " .. field_path .. " = " .. tostring(field_value))
            return true
        end
    else
        logger.warn("表字段类型暂不支持自动更新: " .. field_path .. " 类型: " .. value_type)
    end
    return false
end

-- 递归遍历table并更新有变化的配置项
local function update_config_table(config, base_path, value_table)
    -- 逐个字段检查差异，只有变化才写入
    local changed = false
    for key, field_value in pairs(value_table) do
        local child_path = base_path .. "/" .. tostring(key)
        if type(field_value) == "table" then
            if update_config_table(config, child_path, field_value) then
                changed = true
            end
        else
            if update_config_field(config, child_path, field_value) then
                changed = true
            end
        end
    end
    return changed
end

-- 获取当前时间戳（毫秒）
local function get_current_time_ms()
    return os.time() * 1000 + math.floor((os.clock() % 1) * 1000)
end

-- 双端口TCP套接字系统
local socket_system = {
    -- rime环境变量
    env = nil,
    engine = nil,
    context = nil,

    -- 服务器配置
    host = "127.0.0.1",
    zmq_context = nil,
    client_id = string.format("rime-lua-%d", get_current_time_ms()),

    -- Rime状态服务（快速响应）
    rime_state = {
        port = 10089,
        socket = nil,
        identity = nil,
        is_connected = false,
        last_connect_attempt = 0,
        connect_retry_interval = 5000, -- 5秒重连间隔
        connection_failures = 0,
        max_connection_failures = 3,
        write_failure_count = 0,
        max_failure_count = 3,
        timeout = 0, -- 与旧接口保持一致（秒）
        recv_queue = {},
        last_error = nil,
        default_rcv_timeout_ms = 0,
        default_snd_timeout_ms = 0,
        last_send_at = 0,
        last_recv_at = 0,
        suspended_until = 0,
        health_check_interval = 5000,
        last_health_check = 0
    },

    -- AI转换服务（长时间等待）
    ai_convert = {
        port = 10090,
        socket = nil,
        identity = nil,
        is_connected = false,
        last_connect_attempt = 0,
        connect_retry_interval = 5000, -- 5秒重连间隔
        connection_failures = 0,
        max_connection_failures = 3,
        write_failure_count = 0,
        max_failure_count = 3,
        timeout = 0, -- 与旧接口保持一致（秒）
        recv_queue = {},
        last_error = nil,
        default_rcv_timeout_ms = 100,
        default_snd_timeout_ms = 100
    },

    -- 系统状态
    is_initialized = false
}

local function ensure_zmq_context()
    -- 若 lzmq 未加载，直接返回错误标记
    if not zmq then
        return nil, "lzmq_not_available"
    end
    -- 单例化 ZeroMQ 上下文：全局只创建一次
    if not socket_system.zmq_context then
        -- pcall 确保异常被捕获
        local ok, ctx_or_err = pcall(zmq.context, zmq)
        if not ok or not ctx_or_err then
            -- 创建失败则返回错误（上层会记录并放弃连接）
            return nil, ok and ctx_or_err or "context_creation_failed"
        end
        socket_system.zmq_context = ctx_or_err
    end
    return socket_system.zmq_context
end

local function close_zmq_socket(sock)
    -- 安全关闭套接字：对 nil/已关闭状态都做容错
    if not sock then
        return
    end
    pcall(function()
        sock:close()
    end)
end

local function is_temporary_zmq_error(err)
    -- 判断是否为可重试/临时性错误（如超时/EAGAIN）
    if not err then
        return false
    end
    local err_lower = string.lower(tostring(err))
    return err_lower:find("timeout", 1, true) ~= nil or err_lower:find("eagain", 1, true) ~= nil or
               err_lower:find("resource temporarily unavailable", 1, true) ~= nil
end

local function to_milliseconds(timeout_seconds, fallback_ms)
    -- 秒 -> 毫秒 的统一转换（nil 时返回默认值）
    if timeout_seconds == nil then
        return fallback_ms
    end
    if timeout_seconds < 0 then
        timeout_seconds = 0
    end
    return math.floor(timeout_seconds * 1000)
end

local function configure_socket_defaults(sock, send_timeout_ms, recv_timeout_ms)
    -- 统一设置 socket 基本选项：立即关闭、不阻塞的发送/接收超时
    if not sock then
        return
    end
    pcall(function()
        sock:set_linger(0) -- 立即丢弃未发送数据，避免关闭阻塞
    end)
    if send_timeout_ms then
        pcall(function()
            sock:set_sndtimeo(send_timeout_ms)
        end)
    end
    if recv_timeout_ms then
        pcall(function()
            sock:set_rcvtimeo(recv_timeout_ms)
        end)
    end
end

local function queue_push(queue, value)
    queue[#queue + 1] = value
end

local function queue_pop(queue)
    if #queue == 0 then
        return nil
    end
    local first = queue[1]
    table.remove(queue, 1)
    return first
end

local function split_zmq_payload(payload)
    if not payload or payload == "" then
        return {}
    end

    if not payload:find("\n") and not payload:find("\r") then
        return {payload}
    end

    local results = {}
    for segment in payload:gmatch("([^\r\n]+)") do
        if segment ~= "" then
            results[#results + 1] = segment
        end
    end

    if #results == 0 then
        return {payload}
    end
    return results
end

local function receive_socket_payloads(sock, flags)
    if not sock then
        return nil, "no_socket"
    end

    local frames, err
    if sock.recv_all then
        frames, err = sock:recv_all(flags)
    else
        local first, recv_err = sock:recv(flags)
        if not first then
            return nil, recv_err
        end
        frames = {first}
        if sock.get_rcvmore then
            while sock:get_rcvmore() do
                local next_frame, next_err = sock:recv(flags or 0)
                if not next_frame then
                    return nil, next_err
                end
                frames[#frames + 1] = next_frame
            end
        end
    end

    if not frames then
        return nil, err
    end

    local payload = table.concat(frames)
    local messages = split_zmq_payload(payload)
    if not messages or #messages == 0 then
        return nil, "empty_payload"
    end
    return messages, nil
end

local function drain_socket_immediate(socket, queue)
    -- 非阻塞快速清空 socket 中当前可读的数据，放入队列
    if not zmq then
        return 0
    end
    if not socket then
        return 0
    end
    local drained = 0
    local fatal_err = nil
    while true do
        local messages, err = receive_socket_payloads(socket, ZMQ_DONTWAIT)
        if messages then
            if #messages > 1 then
                logger.debug("ZeroMQ消息拆分后得到 " .. tostring(#messages) .. " 条子消息")
            end
            for _, msg in ipairs(messages) do
                queue_push(queue, msg) -- 入队：上层可统一从队列消费
                drained = drained + #msg
            end
        else
            local err_str = err and tostring(err) or ""
            if err_str ~= "" and not is_temporary_zmq_error(err_str) then
                fatal_err = err
                -- 非临时性错误仅记录，不影响继续运行（交由上层决定是否断开）
                logger.debug("ZeroMQ非暂态错误(drain): " .. err_str)
            end
            break -- 没有更多数据
        end
    end
    return drained, fatal_err
end

local function ensure_ai_identity()
    local ai_convert = socket_system.ai_convert
    if not ai_convert.identity then
        local suffix = string.format("%06d", math.random(0, 999999))
        ai_convert.identity = string.format("%s-%s", socket_system.client_id or "rime-lua", suffix)
    end
    return ai_convert.identity
end

-- 连接到Rime状态服务端（快速响应）
function tcp_zmq.connect_to_rime_server()
    local rime_state = socket_system.rime_state
    if rime_state.socket and rime_state.is_connected then
        return true
    end

    if not zmq then
        logger.error("lzmq 模块不可用，无法建立 Rime 状态连接")
        return false
    end

    local current_time = get_current_time_ms()
    if rime_state.suspended_until and current_time < rime_state.suspended_until then
        return false
    end
    if (current_time - rime_state.last_connect_attempt) < rime_state.connect_retry_interval then
        return rime_state.socket ~= nil and rime_state.is_connected
    end
    rime_state.last_connect_attempt = current_time

    local ctx, ctx_err = ensure_zmq_context()
    if not ctx then
        rime_state.connection_failures = rime_state.connection_failures + 1
        logger.error("ZeroMQ 上下文不可用: " .. tostring(ctx_err))
        return false
    end

    if rime_state.socket then
        close_zmq_socket(rime_state.socket)
        rime_state.socket = nil
    end

    local ok, sock_or_err = pcall(function()
        return ctx:socket(zmq.DEALER)
    end)
    if not ok or not sock_or_err then
        rime_state.connection_failures = rime_state.connection_failures + 1
        logger.error("创建 Rime DEALER 套接字失败: " .. tostring(sock_or_err))
        return false
    end

    local sock = sock_or_err
    local identity = rime_state.identity or (socket_system.client_id .. "-state")
    rime_state.identity = identity
    pcall(function()
        sock:set_identity(identity)
        if sock.set_immediate then
            sock:set_immediate(1)
        end
        if sock.set_rcvhwm then
            sock:set_rcvhwm(200)
        end
        if sock.set_sndhwm then
            sock:set_sndhwm(200)
        end
        if sock.set_heartbeat_ivl then
            sock:set_heartbeat_ivl(2000)
        end
        if sock.set_heartbeat_timeout then
            sock:set_heartbeat_timeout(6000)
        end
        if sock.set_heartbeat_ttl then
            sock:set_heartbeat_ttl(4000)
        end
    end)
    configure_socket_defaults(sock, rime_state.default_snd_timeout_ms, rime_state.default_rcv_timeout_ms)

    local endpoint = string.format("tcp://%s:%d", socket_system.host, rime_state.port)
    local connect_ok, connect_err = pcall(function()
        sock:connect(endpoint)
    end)
    if not connect_ok then
        rime_state.connection_failures = rime_state.connection_failures + 1
        logger.warn("连接 Rime ZeroMQ 服务失败: " .. tostring(connect_err))
        close_zmq_socket(sock)
        rime_state.suspended_until = current_time + rime_state.connect_retry_interval
        return false
    end

    rime_state.socket = sock
    rime_state.is_connected = true
    rime_state.connection_failures = 0
    rime_state.write_failure_count = 0
    rime_state.recv_queue = {}
    rime_state.last_error = nil
    rime_state.last_send_at = 0
    rime_state.last_recv_at = 0
    rime_state.suspended_until = 0

    logger.debug("Rime状态ZeroMQ连接建立成功: " .. endpoint .. " identity=" .. tostring(identity))
    return true
end

-- 连接到AI转换服务端（长时间等待）
function tcp_zmq.connect_to_ai_server()
    -- 取出 AI 通道对象
    local ai_convert = socket_system.ai_convert
    -- 已连且标记有效：直接复用
    if ai_convert.socket and ai_convert.is_connected then
        return true
    end

    local current_time = get_current_time_ms()
    -- 简单防抖：连接重试间隔未到则跳过
    if (current_time - ai_convert.last_connect_attempt) < ai_convert.connect_retry_interval then
        return ai_convert.is_connected and ai_convert.socket ~= nil
    end
    ai_convert.last_connect_attempt = current_time -- 更新时间戳

    -- lzmq 未加载：无法建立连接
    if not zmq then
        logger.error("lzmq 模块不可用，无法建立 AI 转换连接")
        return false
    end

    local ctx, ctx_err = ensure_zmq_context()
    -- 确保 ZeroMQ 上下文可用
    if not ctx then
        ai_convert.connection_failures = ai_convert.connection_failures + 1
        logger.error("ZeroMQ 上下文不可用: " .. tostring(ctx_err))
        return false
    end

    -- 关闭遗留 socket（若有）
    if ai_convert.socket then
        close_zmq_socket(ai_convert.socket)
        ai_convert.socket = nil
    end

    -- 创建 DEALER 套接字（允许异步/流式）
    local ok, sock_or_err = pcall(function()
        return ctx:socket(zmq.DEALER)
    end)
    if not ok or not sock_or_err then
        ai_convert.connection_failures = ai_convert.connection_failures + 1
        logger.error("创建 AI DEALER 套接字失败: " .. tostring(sock_or_err))
        return false
    end

    local sock = sock_or_err
    local identity = ensure_ai_identity() -- 设置稳定的客户端 ID，便于服务端识别
    pcall(function()
        sock:set_identity(identity)
    end)
    -- 配置默认超时与 LINGER
    configure_socket_defaults(sock, ai_convert.default_snd_timeout_ms, ai_convert.default_rcv_timeout_ms)

    local endpoint = string.format("tcp://%s:%d", socket_system.host, ai_convert.port)
    local connect_ok, connect_err = pcall(function()
        sock:connect(endpoint)
    end)
    if not connect_ok then
        ai_convert.connection_failures = ai_convert.connection_failures + 1
        logger.warn("连接 AI ZeroMQ 服务失败: " .. tostring(connect_err))
        close_zmq_socket(sock)
        return false
    end

    -- 标记连接成功并重置状态
    ai_convert.socket = sock
    ai_convert.is_connected = true
    ai_convert.connection_failures = 0
    ai_convert.write_failure_count = 0
    ai_convert.recv_queue = {}
    ai_convert.last_error = nil

    logger.debug("AI转换ZeroMQ连接建立成功: " .. endpoint .. " identity=" .. tostring(identity))
    return true
end

-- 断开Rime状态服务连接
function tcp_zmq.disconnect_from_rime_server(retry_delay_ms)
    local rime_state = socket_system.rime_state
    close_zmq_socket(rime_state.socket)
    rime_state.socket = nil
    rime_state.is_connected = false
    rime_state.recv_queue = {}
    rime_state.last_error = nil
    rime_state.last_send_at = 0
    rime_state.last_recv_at = 0
    local delay = retry_delay_ms or rime_state.connect_retry_interval
    rime_state.suspended_until = get_current_time_ms() + delay
    logger.debug("Rime状态服务连接已断开")
end

-- 断开AI转换服务连接
function tcp_zmq.disconnect_from_ai_server()
    local ai_convert = socket_system.ai_convert
    close_zmq_socket(ai_convert.socket)
    ai_convert.socket = nil
    ai_convert.is_connected = false
    ai_convert.recv_queue = {}
    ai_convert.last_error = nil
    logger.debug("AI转换服务连接已断开")
end

-- 断开与所有服务端的连接
function tcp_zmq.disconnect_from_server()
    tcp_zmq.disconnect_from_rime_server()
    tcp_zmq.disconnect_from_ai_server()
    logger.debug("所有ZeroMQ连接已断开")
end

-- 检测AI转换服务连接状态
function tcp_zmq.check_ai_connection()
    local ai_convert = socket_system.ai_convert
    return ai_convert.socket ~= nil and ai_convert.is_connected
end

-- 检测Rime状态服务连接状态
function tcp_zmq.check_rime_connection()
    local rime_state = socket_system.rime_state
    return rime_state.socket ~= nil and rime_state.is_connected
end

-- 写入Rime状态服务TCP套接字
function tcp_zmq.write_to_rime_socket(data)
    -- 未初始化则不发送
    if not socket_system.is_initialized then
        return false
    end

    local rime_state = socket_system.rime_state
    -- 确保连接就绪
    if not tcp_zmq.connect_to_rime_server() then
        logger.warn("Rime状态服务连接不可用")
        return false
    end

    if rime_state.socket then
        local drained, fatal_err = drain_socket_immediate(rime_state.socket, rime_state.recv_queue)
        if fatal_err then
            local err_str = tostring(fatal_err)
            rime_state.last_error = err_str
            logger.warn("Rime状态通道在发送前检测到读取错误，准备重连: " .. err_str)
            tcp_zmq.disconnect_from_rime_server()
            return false
        end
        if drained > 0 then
            rime_state.last_recv_at = get_current_time_ms()
            logger.debug("Rime状态通道发送前收到了 " .. tostring(drained) .. " 字节积压数据")
        end
    end

    -- 确保 payload 是字符串
    local payload = type(data) == "string" and data or tostring(data)
    local ok, err
    if ZMQ_DONTWAIT then
        ok, err = rime_state.socket:send(payload, ZMQ_DONTWAIT)
    else
        ok, err = rime_state.socket:send(payload)
    end

    if ok then
        rime_state.write_failure_count = 0
        rime_state.last_error = nil
        rime_state.last_send_at = get_current_time_ms()
        -- logger.debug("write_to_rime_socket消息发送成功")

        if rime_state.socket then
            local drained_after, fatal_after = drain_socket_immediate(rime_state.socket, rime_state.recv_queue)
            if fatal_after then
                local err_str = tostring(fatal_after)
                rime_state.last_error = err_str
                logger.warn("Rime状态通道发送后检测到读取错误: " .. err_str)
                tcp_zmq.disconnect_from_rime_server()
            elseif drained_after > 0 then
                rime_state.last_recv_at = get_current_time_ms()
                logger.debug("Rime状态通道发送后立即收到了 " .. tostring(drained_after) .. " 字节数据")
            end
        end
        return true
    end

    local err_str = tostring(err)
    rime_state.write_failure_count = rime_state.write_failure_count + 1
    rime_state.last_error = err_str

    if is_temporary_zmq_error(err_str) then
        if rime_state.write_failure_count == 1 or rime_state.write_failure_count % rime_state.max_failure_count == 0 then
            logger.warn("Rime状态ZeroMQ发送被丢弃（连接忙碌），累计丢弃次数: " .. rime_state.write_failure_count)
        end
        if rime_state.write_failure_count >= rime_state.max_failure_count then
            logger.warn("Rime状态通道连续发送失败，暂停发送并等待重连")
            tcp_zmq.disconnect_from_rime_server(rime_state.connect_retry_interval * 2)
            rime_state.write_failure_count = 0
        end
        return false
    end

    logger.error("Rime状态ZeroMQ写入失败: " .. err_str .. " (失败次数: " ..
                     rime_state.write_failure_count .. ")")
    tcp_zmq.disconnect_from_rime_server(rime_state.connect_retry_interval * 2)
    return false
end

-- 写入AI转换服务TCP套接字
function tcp_zmq.write_to_ai_socket(data)
    -- 未初始化则不发送
    if not socket_system.is_initialized then
        return false
    end

    local ai_convert = socket_system.ai_convert
    -- 确保连接就绪
    if not tcp_zmq.connect_to_ai_server() then
        logger.warn("AI转换服务连接不可用")
        return false
    end

    -- 确保 payload 是字符串
    local payload = type(data) == "string" and data or tostring(data)
    logger.debug("将要发送给AI服务的JSON: " .. payload)

    local ok, err = pcall(function()
        ai_convert.socket:send(payload)
    end)

    if ok then
        ai_convert.write_failure_count = 0
        ai_convert.last_error = nil
        logger.debug("AI接口数据发送成功")
        return true
    end

    ai_convert.write_failure_count = ai_convert.write_failure_count + 1
    ai_convert.last_error = tostring(err)
    logger.error("AI转换服务ZeroMQ写入失败: " .. tostring(err) .. " (失败次数: " ..
                     ai_convert.write_failure_count .. ")")
    tcp_zmq.disconnect_from_ai_server()
    return false
end

-- 非阻塞读取Rime状态服务TCP套接字数据
function tcp_zmq.read_from_rime_socket(timeout_seconds)
    local rime_state = socket_system.rime_state
    rime_state.last_error = nil

    if not tcp_zmq.connect_to_rime_server() then
        rime_state.last_error = "connection_failed"
        return nil
    end

    local drained, fatal_err = 0, nil
    if rime_state.socket then
        drained, fatal_err = drain_socket_immediate(rime_state.socket, rime_state.recv_queue)
    end
    if fatal_err then
        local err_str = tostring(fatal_err)
        rime_state.last_error = err_str
        logger.warn("Rime状态通道读取失败，准备重连: " .. err_str)
        tcp_zmq.disconnect_from_rime_server()
        return nil
    end
    if drained > 0 then
        rime_state.last_recv_at = get_current_time_ms()
    end

    local queued = queue_pop(rime_state.recv_queue)
    if queued then
        rime_state.last_recv_at = get_current_time_ms()
        return queued
    end

    -- 兼容旧接口：若显式传入正超时时间，则允许一次极短暂的等待（最多5ms）
    if timeout_seconds and timeout_seconds > 0 then
        local sock = rime_state.socket
        if sock then
            local default_ms = rime_state.default_rcv_timeout_ms or 0
            local wait_ms = to_milliseconds(timeout_seconds, default_ms)
            wait_ms = math.max(0, math.min(wait_ms, 5))
            if wait_ms > 0 then
                pcall(function()
                    sock:set_rcvtimeo(wait_ms)
                end)
                local messages, err = receive_socket_payloads(sock, nil)
                if default_ms ~= wait_ms then
                    pcall(function()
                        sock:set_rcvtimeo(default_ms)
                    end)
                end
                if messages and #messages > 0 then
                    if #messages > 1 then
                        for i = 2, #messages do
                            queue_push(rime_state.recv_queue, messages[i])
                        end
                    end
                    rime_state.last_recv_at = get_current_time_ms()
                    return messages[1]
                end
                local err_str = tostring(err or "")
                if err_str ~= "" and not is_temporary_zmq_error(err_str) then
                    rime_state.last_error = err_str
                    logger.warn("Rime状态ZeroMQ读取失败: " .. err_str)
                    tcp_zmq.disconnect_from_rime_server()
                    return nil
                end
            end
        end
    end

    rime_state.last_error = "no_data"
    return nil
end

-- 带超时读取AI转换服务TCP套接字数据（按行读取，支持自定义超时）
function tcp_zmq.read_from_ai_socket(timeout_seconds)
    -- 统一读取入口：支持可选超时（秒）
    local ai_convert = socket_system.ai_convert
    ai_convert.last_error = nil
    -- 确保连接存在
    if not tcp_zmq.connect_to_ai_server() then
        ai_convert.last_error = "connection_failed"
        logger.warn("AI转换服务重连失败")
        return nil
    end

    local queued = queue_pop(ai_convert.recv_queue)
    if queued then
        ai_convert.last_error = nil
        return queued
    end

    -- 设置临时超时：若调用方传入了 timeout_seconds
    local sock = ai_convert.socket
    local default_ms = ai_convert.default_rcv_timeout_ms
    local custom_ms = nil
    if timeout_seconds ~= nil then
        custom_ms = to_milliseconds(timeout_seconds, default_ms)
        pcall(function()
            sock:set_rcvtimeo(custom_ms)
        end)
    end

    local messages, err = receive_socket_payloads(sock, nil)

    -- 读完后恢复默认超时
    if timeout_seconds ~= nil and default_ms and custom_ms ~= default_ms then
        pcall(function()
            sock:set_rcvtimeo(default_ms)
        end)
    end

    if messages and #messages > 0 then
        if #messages > 1 then
            for i = 2, #messages do
                queue_push(ai_convert.recv_queue, messages[i])
            end
        end
        ai_convert.last_error = nil
        return messages[1]
    end

    -- 临时性错误（超时/EAGAIN）：返回 nil 由上层轮询
    if is_temporary_zmq_error(err) then
        ai_convert.last_error = "timeout"
        return nil
    end

    -- 其他错误：断开并交由上层重连
    ai_convert.last_error = tostring(err)
    logger.warn("AI转换ZeroMQ读取失败: " .. tostring(err))
    tcp_zmq.disconnect_from_ai_server()
    return nil
end

-- 读取AI转换服务TCP套接字所有可用数据（支持自定义超时）
function tcp_zmq.read_all_from_ai_socket(timeout_seconds)
    local first_message = tcp_zmq.read_from_ai_socket(timeout_seconds)
    if not first_message then
        return nil
    end

    local messages = {first_message}
    while true do
        local next_message = tcp_zmq.read_from_ai_socket(0)
        if not next_message then
            break
        end
        messages[#messages + 1] = next_message
    end

    local combined = table.concat(messages, "\n")
    logger.debug("📥 累计读取AI消息数量: " .. tostring(#messages))
    return combined
end

-- 快速清理AI转换服务TCP套接字积压数据
function tcp_zmq.flush_ai_socket_buffer()
    -- 非阻塞清空 AI 套接字与本地队列，返回被丢弃的字节数
    local ai_convert = socket_system.ai_convert
    if not tcp_zmq.connect_to_ai_server() then
        logger.warn("AI转换服务重连失败，无法清理缓冲区")
        return 0
    end

    local flushed = 0

    -- 先统计并清空本地缓冲队列
    if ai_convert.recv_queue and #ai_convert.recv_queue > 0 then
        for _, message in ipairs(ai_convert.recv_queue) do
            flushed = flushed + #message
        end
    end
    ai_convert.recv_queue = {}

    -- 再从 socket 非阻塞拉取所有当前可读数据到队列统计
    local drained_bytes, fatal_err = drain_socket_immediate(ai_convert.socket, ai_convert.recv_queue)
    flushed = flushed + drained_bytes
    if fatal_err then
        logger.warn("AI转换服务在清理缓冲区时检测到错误: " .. tostring(fatal_err))
        tcp_zmq.disconnect_from_ai_server()
    end

    if ai_convert.recv_queue and #ai_convert.recv_queue > 0 then
        for _, message in ipairs(ai_convert.recv_queue) do
            flushed = flushed + #message
        end
    end
    ai_convert.recv_queue = {}

    if flushed > 0 then
        logger.debug("🗑️ 快速清理AI套接字积压数据: " .. flushed .. " 字节")
    end

    return flushed
end

-- 读取AI转换服务最新消息（丢弃旧消息，只返回最后一条）- 优化版本
-- 返回值格式: {data = parsed_data or nil, status = "success"|"timeout"|"no_data"|"error", raw_message = string or nil}
function tcp_zmq.read_latest_from_ai_socket(timeout_seconds)
    -- 连续读取 AI 通道并仅返回“最后一条”消息（丢弃旧消息）
    local ai_convert = socket_system.ai_convert
    if not tcp_zmq.connect_to_ai_server() then
        return {
            data = nil,
            status = "error",
            raw_message = nil,
            error_msg = "服务未连接且重连失败"
        }
    end

    timeout_seconds = timeout_seconds or 0.1 -- 默认 100ms

    -- 先按给定超时读取一条
    local latest_line = tcp_zmq.read_from_ai_socket(timeout_seconds)
    if not latest_line then
        local last_err = ai_convert.last_error
        if last_err and last_err ~= "timeout" then
            return {
                data = nil,
                status = "error",
                raw_message = nil,
                error_msg = last_err
            }
        end
        return {
            data = nil,
            status = "timeout",
            raw_message = nil
        }
    end

    -- 再以 0 超时快速追加读取，取最后一条
    local total_lines = 1
    while true do
        local next_line = tcp_zmq.read_from_ai_socket(0)
        if not next_line then
            break
        end
        latest_line = next_line
        total_lines = total_lines + 1
    end

    if total_lines > 1 then
        logger.debug("🎯 共读取了 " .. total_lines .. " 条消息，保留最后一条")
    else
        logger.debug("📥 从AI转换服务读取到1条最新消息")
    end

    logger.debug("🎯 返回最新消息: " .. latest_line)

    -- 尝试 JSON 解析
    local parsed_data = tcp_zmq.parse_socket_data(latest_line)
    return {
        data = parsed_data,
        status = "success",
        raw_message = latest_line
    }
end

-- 解析从Python端接收的数据
function tcp_zmq.parse_socket_data(data)
    if not data or #data == 0 then
        return nil
    end

    logger.debug("🔍 解析socket数据data: " .. tostring(data) .. " (类型: " .. type(data) .. ")")

    local success, parsed_data = pcall(json.decode, data)

    if success and parsed_data then
        logger.debug("🔍 解析TCP数据成功: " .. tostring(parsed_data))
        return parsed_data
    else
        logger.error("❌ 解析TCP数据失败: " .. tostring(data))
        return nil
    end
end

-- 处理从Python端接收的命令
function tcp_zmq.handle_socket_command(command_messege, env)
    -- 从 env 提取 context（可能为nil）
    local context = env.engine.context
    local config = env.engine.schema.config

    --[[ 接收到消息格式: 
    {"messege_type": "command_response", "response": "rime_state_received", "timestamp": 1753022593756, "client_id": "rime-127.0.0.1:57187", "command_messege": [{"command": "set_option", "command_type": "option", "option_name": "full_shape", "option_value": true, "timestamp": 1753022590433}]}
    
    注意：外层的 command_messege 是一个数组，但此函数处理的是数组中的单个命令对象
    ]]

    -- 🎯 处理TCP命令: set_option option_name: super_tips
    logger.debug("🎯 处理TCP命令: " .. command_messege.command)

    local command = command_messege.command
    if command == "ping" then
        -- 响应ping命令
        logger.debug("📞 收到ping命令")
        tcp_zmq.write_to_rime_socket('{"response": "pong"}')
        return true
    elseif command == "set_option" then
        -- 修改设置
        logger.debug("command_messege.option_value: " .. tostring(command_messege.option_value))
        if context then
            if context:get_option(command_messege.option_name) ~= command_messege.option_value then
                tcp_zmq.update_global_option_state = true
                -- 记录到模块级全局变量，供其他会话/模块读取与应用
                tcp_zmq.set_global_option(command_messege.option_name, command_messege.option_value)
                logger.debug("tcp_zmq.update_global_option_state = true")
                -- 更新一个上下文属性
                -- tcp_zmq.update_property("config_update_flag", "1")
            end
            -- local response = {
            --     response = "option_set",
            --     option_name = command_messege.option_name,
            --     success = true,
            --     timestamp = get_current_time_ms(),
            --     responding_to = "set_option"
            -- }
            -- tcp_zmq.write_to_rime_socket(json.encode(response))
        else
            -- logger.warn("context为nil，无法设置选项: " .. tostring(command_messege.option_name))
            -- local response = {
            --     response = "option_set",
            --     option_name = command_messege.option_name,
            --     success = false,
            --     error = "context is nil",
            --     timestamp = get_current_time_ms(),
            --     responding_to = "set_option"
            -- }
            -- tcp_zmq.write_to_rime_socket(json.encode(response))
        end
        return true
    elseif command == "set_config" then
        -- 配置变更通知
        local config_name = command_messege.config_name
        local config_path = command_messege.config_path
        local config_value = command_messege.config_value
        local description = command_messege.description
        local timestamp = command_messege.timestamp

        logger.info("🔧 收到配置变更通知:")
        logger.info("   配置名称: " .. tostring(config_name))
        logger.info("   配置路径: " .. tostring(config_path))
        logger.info("   配置值: " .. tostring(config_value))
        logger.info("   变更描述: " .. tostring(description))
        logger.info("   时间戳: " .. tostring(timestamp))

        -- 实际更新配置
        
        -- 将点分隔的路径转换为Rime配置路径（用斜杠分隔）
        local rime_config_path = string.gsub(config_path, "%.", "/")
        logger.debug("转换后的配置路径: " .. rime_config_path)

        local success = false
        local need_refresh = false
        if config_value ~= nil then
            local value_type = type(config_value)

            if value_type == "boolean" then
                config:set_bool(rime_config_path, config_value)
                success = true
                need_refresh = true
                logger.debug("设置布尔配置: " .. rime_config_path .. " = " .. tostring(config_value))
            elseif value_type == "number" then
                -- 尝试判断是整数还是浮点数
                if config_value == math.floor(config_value) then
                    config:set_int(rime_config_path, config_value)
                    logger.debug("设置整数配置: " .. rime_config_path .. " = " .. tostring(config_value))
                else
                    config:set_double(rime_config_path, config_value)
                    logger.debug("设置浮点数配置: " .. rime_config_path .. " = " .. tostring(config_value))
                end
                success = true
                need_refresh = true
            elseif value_type == "string" then
                config:set_string(rime_config_path, config_value)
                success = true
                need_refresh = true
                logger.debug("设置字符串配置: " .. rime_config_path .. " = " .. tostring(config_value))
            elseif value_type == "table" then
                -- 表配置按字段比对后再更新
                local changed = update_config_table(config, rime_config_path, config_value)
                success = true
                need_refresh = changed
                if changed then
                    logger.debug("表配置更新完成: " .. rime_config_path)
                else
                    logger.debug("表配置未发生变化: " .. rime_config_path)
                end
            else
                logger.warn("不支持的配置值类型: " .. value_type)
            end

        else
            success = true
            config:set_string(rime_config_path, "__DELETED__")
            need_refresh = true
            logger.debug("设置配置删除标记: " .. rime_config_path .. " = __DELETED__")
            -- logger.warn("配置值为空，跳过更新")
        end
        if success then
            if need_refresh then
                tcp_zmq.update_configs(config)
                logger.info("✅ update_all_modules_config配置更新成功")
                -- 更新一个上下文属性
                tcp_zmq.update_property("config_update_flag", "1")
            else
                logger.debug("表配置无变化，跳过模块刷新: " .. rime_config_path)
            end
        else
            logger.error("❌ 配置更新失败: " .. rime_config_path)
        end

        return true
    elseif command == "set_property" then
        -- 修改属性
        logger.debug("command_messege.property_name: " .. tostring(command_messege.property_name))
        logger.debug("command_messege.property_value: " .. tostring(command_messege.property_value))
        tcp_zmq.update_property(command_messege.property_name, command_messege.property_value)

        return true
    elseif command == "clipboard_data" then
        logger.debug("command_messege: clipboard_data")
        -- 处理获取剪贴板命令：将 clipboard.text 追加到 context.input
        local clipboard = command_messege.clipboard or {}
        local clipboard_text = clipboard.text
        local success_flag = command_messege.success

        if success_flag == false then
            local err_msg = (clipboard and clipboard.error) or command_messege.error or "unknown"
            logger.warn("get_clipboard 返回失败，错误信息: " .. tostring(err_msg))
            return true
        end

        if clipboard_text and clipboard_text ~= "" then
            local english_mode_symbol = config:get_string("translator/english_mode_symbol") or ""
            -- 将英文符号替换成空格.
            if english_mode_symbol ~= "" then
                if clipboard_text:find(english_mode_symbol, 1, true) then
                    clipboard_text = clipboard_text:gsub(
                        english_mode_symbol:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1"), " ")
                end
            end

            local rawenglish_prompt = context:get_property("rawenglish_prompt")
            if rawenglish_prompt == "1" then
                context.input = context.input .. clipboard_text
                logger.debug("get_clipboard 粘贴clipboard_text: " .. clipboard_text)
            else
                
                context.input = context.input .. english_mode_symbol .. clipboard_text .. english_mode_symbol
                logger.debug("get_clipboard 粘贴clipboard_text: " .. english_mode_symbol .. clipboard_text .. english_mode_symbol)
            end
            
            
        else
            logger.warn("get_clipboard 命令未提供有效的文本可追加")
            -- 在这个地方应该添加一个prompt通知用户, 应该是提取最后一个segment
            local segmentation = context.composition:toSegmentation()
            local last_segment = segmentation:back()
            last_segment.prompt = " [剪贴板为空] "
            
        end

        return true

    elseif command == "paste_executed" then
        -- 粘贴命令执行成功响应
        logger.info("✅ 服务端已成功执行粘贴操作")
        return true
    elseif command == "paste_failed" then
        -- 粘贴命令执行失败响应
        local error_msg = command_messege.error or "未知错误"
        logger.error("❌ 服务端执行粘贴操作失败: " .. tostring(error_msg))
        return true
    else
        logger.warn("❓ 未知的TCP命令: " .. command)
        return false
    end
end

-- 定期处理Rime状态服务TCP套接字数据
function tcp_zmq.process_rime_socket_data(env, timeout)
    local processed_any = false
    local processed_count = 0
    local max_messages = 5
    while true do
        if processed_count >= max_messages then
            logger.debug("⏹️ 已达到本次处理上限: " .. tostring(max_messages) .. " 条消息")
            break
        end
        local data = tcp_zmq.read_from_rime_socket(timeout)
        if not data then
            break
        end

        logger.debug("🎯 成功接收到Rime状态服务完整消息: " .. data)
        local parsed_data = tcp_zmq.parse_socket_data(data)
        if parsed_data then
            logger.debug("📨 Rime状态消息解析成功")
            if parsed_data.messege_type == "command_response" then
                logger.debug("📨 检测到嵌套命令 command_response 字段.")
                -- command_messege 现在是一个数组，可能包含多条命令
                if parsed_data.command_messege then
                    if #parsed_data.command_messege > 0 then
                        -- 如果是数组，遍历处理每个命令
                        for i, command_item in ipairs(parsed_data.command_messege) do
                            logger.debug("📨 处理第 " .. i .. " 条命令: " .. tostring(command_item.command))
                            tcp_zmq.handle_socket_command(command_item, env)
                        end
                    else
                        -- 如果是单个命令对象（向后兼容）
                        tcp_zmq.handle_socket_command(parsed_data.command_messege, env)
                    end
                end
            elseif parsed_data.messege_type == "command_executed" then
                -- 命令执行成功的通知消息
                logger.info("✅ 收到命令执行成功通知: paste_executed")
                logger.debug("命令执行成功响应内容: " .. data)
            end
            processed_any = true
            processed_count = processed_count + 1
        else
            logger.warn("⚠️  Rime状态消息解析失败")
            -- 解析失败，继续尝试读取下一条
            processed_count = processed_count + 1
        end
    end

    return processed_any -- 处理过至少一条消息则为true，否则false
end

-- 和Rime状态服务进行数据交换
function tcp_zmq.sync_with_server(env, option_info, send_commit_text, command_key, command_value, timeout, position, char)
    -- position 代表调用这个函数的位置, 用于标识
    send_commit_text = send_commit_text or false
    local success, error_msg = pcall(function()
        local current_time = get_current_time_ms()
        local context = env.engine.context

        -- 构建基础状态数据
        local state_data = {
            messege_type = "state",
            is_composing = context:is_composing(),
            timestamp = current_time,
            switches_option = {}, -- 初始化为空表
            properties = {} -- 初始化属性表
        }
        
        if command_key then
            -- 发送字符串命令,例如"enter",代表对端将会接收到之后发送一个回车按键
            -- 构建粘贴命令数据
            local command_message = {
                messege_type = "command",
                command = command_key,
                command_value = command_value,
                timestamp = current_time,
                client_id = "lua_tcp_client"
            }
            state_data.command_message = command_message
        end
        if send_commit_text then
            state_data.messege_type = "commit"
            state_data.current_app = context:get_property("client_app")
            -- 发送上屏内容
            state_data.commit_pinyin = context.input
            state_data.commit_text = context:get_commit_text()
        end

        if position == "unhandled_key_notifier" then
            state_data.messege_type = "commit"
            state_data.current_app = context:get_property("client_app")
            state_data.commit_pinyin = char
            state_data.commit_text = char
        end

        if option_info then
            -- 构建完整的带有option当前配置的状态数据
            local simple_switches = {"ascii_punct"}
            for _, switch_name in ipairs(simple_switches) do
                local switch_state = context:get_option(switch_name)
                table.insert(state_data.switches_option, {
                    name = switch_name,
                    type = "simple",
                    state = switch_state,
                    state_index = switch_state and 1 or 0
                })
            end
        end

        -- 构建属性数据（始终发送）
        local property_names = {"keepon_chat_trigger"}
        for _, property_name in ipairs(property_names) do
            local property_value = context:get_property(property_name)
            table.insert(state_data.properties, {
                name = property_name,
                type = "string",
                value = property_value
            })
        end

        -- 序列化状态数据
        local json_data = json.encode(state_data)

        -- logger.debug("json_data: " .. json_data)

        -- 写入Rime状态服务TCP套接字
        tcp_zmq.write_to_rime_socket(json_data)

        -- 处理来自Rime状态服务端的数据
        if socket_system.is_initialized and socket_system.rime_state.is_connected then
            tcp_zmq.process_rime_socket_data(env, timeout)
        end
    end)

    if not success then
        logger.error("状态更新失败: " .. tostring(error_msg))
        return false
    end

    return true
end

-- 统计信息
function tcp_zmq.get_stats()
    local stats = {
        is_initialized = socket_system.is_initialized,
        host = socket_system.host,

        -- Rime状态服务统计
        rime_state = {
            port = socket_system.rime_state.port,
            is_connected = socket_system.rime_state.is_connected,
            connection_failures = socket_system.rime_state.connection_failures,
            write_failure_count = socket_system.rime_state.write_failure_count,
            timeout = socket_system.rime_state.timeout
        },

        -- AI转换服务统计
        ai_convert = {
            port = socket_system.ai_convert.port,
            is_connected = socket_system.ai_convert.is_connected,
            connection_failures = socket_system.ai_convert.connection_failures,
            write_failure_count = socket_system.ai_convert.write_failure_count,
            timeout = socket_system.ai_convert.timeout
        }
    }

    return stats
end

-- 公开接口：获取连接信息
function tcp_zmq.get_connection_info()
    return {
        host = socket_system.host,
        rime_state = {
            port = socket_system.rime_state.port,
            is_connected = socket_system.rime_state.is_connected
        },
        ai_convert = {
            port = socket_system.ai_convert.port,
            is_connected = socket_system.ai_convert.is_connected
        }
    }
end

-- 公开接口：检查双端口系统是否就绪（任一服务可用即为就绪）
function tcp_zmq.is_system_ready()
    return socket_system.is_initialized and
               (socket_system.rime_state.is_connected or socket_system.ai_convert.is_connected)
end

-- 公开接口：检查Rime状态服务连接状态
function tcp_zmq.is_rime_socket_ready()
    return socket_system.is_initialized and socket_system.rime_state.is_connected
end

-- 公开接口：检查AI转换服务连接状态
function tcp_zmq.is_ai_socket_ready()
    return socket_system.is_initialized and socket_system.ai_convert.is_connected
end

-- 公开接口：强制重置连接状态（用于服务端重启后立即重连）
function tcp_zmq.force_reconnect()
    logger.info("强制重置所有TCP连接状态")

    -- 重置连接状态和重连计时器
    socket_system.rime_state.last_connect_attempt = 0
    socket_system.ai_convert.last_connect_attempt = 0
    socket_system.rime_state.connection_failures = 0
    socket_system.ai_convert.connection_failures = 0
    socket_system.rime_state.write_failure_count = 0
    socket_system.ai_convert.write_failure_count = 0

    -- 断开现有连接
    tcp_zmq.disconnect_from_server()

    -- 尝试重新连接
    local rime_connected = tcp_zmq.connect_to_rime_server()
    local ai_connected = tcp_zmq.connect_to_ai_server()

    logger.info("强制重连结果 - Rime:" .. tostring(rime_connected) .. " AI:" .. tostring(ai_connected))

    return rime_connected or ai_connected
end

-- 公开接口：设置连接参数
function tcp_zmq.set_connection_params(host, rime_port, ai_port)
    if host then
        socket_system.host = host
    end
    if rime_port then
        socket_system.rime_state.port = rime_port
    end
    if ai_port then
        socket_system.ai_convert.port = ai_port
    end
    logger.debug(
        "连接参数已更新: " .. socket_system.host .. " Rime:" .. socket_system.rime_state.port .. " AI:" ..
            socket_system.ai_convert.port)
end

-- 公开接口：发送转换请求（仅发送，不等待响应）
function tcp_zmq.send_convert_request(schema_name, shuru_schema, confirmed_pos_input, long_candidates_table,
    timeout_seconds)
    local timeout = timeout_seconds or socket_system.ai_convert.timeout -- 默认使用AI服务超时时间
    local success, result_or_error = pcall(function()
        local current_time = get_current_time_ms()

        -- 构建要转换的拼音字符串
        local convert_data = {
            messege_type = "convert",
            confirmed_pos_input = confirmed_pos_input,
            schema_name = schema_name,
            shuru_schema = shuru_schema,
            stream_mode = true,
            timestamp = current_time,
            timeout = timeout -- 告知服务端预期的超时时间
        }

        -- 提取long_candidates_table中每个元素的text属性，组成数组
        if long_candidates_table then
            convert_data.candidates_text = {}
            for _, candidate in ipairs(long_candidates_table) do
                table.insert(convert_data.candidates_text, candidate.text)
            end
        end

        -- 序列化状态数据
        local json_data = json.encode(convert_data)
        logger.debug("发送转换请求json_data: " .. tostring(json_data))

        if json_data then
            -- 写入AI转换服务TCP套接字
            local result = tcp_zmq.write_to_ai_socket(json_data)
            if result then
                logger.debug("转换请求发送成功")
                return true
            else
                logger.debug("转换请求发送失败")
                return false
            end
        else
            logger.debug("convert_data序列化失败,请排查错误: " .. tostring(convert_data))
            return false
        end
    end)

    if not success then
        logger.error("发送转换请求失败: " .. tostring(result_or_error))
        return false
    end

    return result_or_error
end

-- 公开接口：读取转换结果（流式读取，类似AI助手的读取方式）
function tcp_zmq.read_convert_result(timeout_seconds)
    local timeout = timeout_seconds or 0.1 -- 默认100ms超时，适合流式读取

    -- 使用现有的read_latest_from_ai_socket函数
    local stream_result = tcp_zmq.read_latest_from_ai_socket(timeout)

    if stream_result and stream_result.status == "success" and stream_result.data then
        local parsed_data = stream_result.data

        -- 检查是否是转换结果
        if parsed_data.messege_type == "convert_result_stream" then
            logger.debug("读取到转换结果数据")

            -- 从服务端数据中获取 is_final 状态
            local is_final = parsed_data.is_final or false
            local is_partial = parsed_data.is_partial or false
            local is_timeout = parsed_data.is_timeout or false
            local is_error = parsed_data.is_error or false

            logger.debug("转换结果状态 - is_final: " .. tostring(is_final) .. ", is_partial: " ..
                             tostring(is_partial) .. ", is_timeout: " .. tostring(is_timeout) .. ", is_error: " ..
                             tostring(is_error))

            return {
                status = "success",
                data = parsed_data,
                is_final = is_final,
                is_partial = is_partial,
                is_timeout = is_timeout,
                is_error = is_error
            }
        else
            logger.debug("收到非转换结果数据，类型: " .. tostring(parsed_data.messege_type))
            return {
                status = "no_data",
                data = nil,
                is_final = false
            }
        end
    elseif stream_result and stream_result.status == "timeout" then
        logger.debug("转换结果读取超时(正常) - 服务端可能还没处理完成")
        return {
            status = "timeout",
            data = nil,
            is_final = false
        }
    elseif stream_result and stream_result.status == "error" then
        logger.error("转换结果读取错误: " .. tostring(stream_result.error_msg))
        return {
            status = "error",
            data = nil,
            is_final = true,
            error_msg = stream_result.error_msg
        }
    else
        logger.debug("未知的转换结果读取状态")
        return {
            status = "no_data",
            data = nil,
            is_final = false
        }
    end
end

-- 公开接口：发送粘贴命令到服务端（跨平台通用）
function tcp_zmq.send_paste_command(env)
    local success, error_msg = pcall(function()
        local current_time = get_current_time_ms()

        -- 构建粘贴命令数据
        local paste_command = {
            messege_type = "command", -- 使用state类型以兼容现有处理逻辑
            command = "paste", -- 粘贴命令
            timestamp = current_time,
            client_id = "lua_tcp_client"
        }

        -- 序列化命令数据
        local json_data = json.encode(paste_command)
        logger.debug("发送粘贴命令json_data: " .. tostring(json_data))

        if json_data then
            -- 写入Rime状态服务TCP套接字
            local send_success = tcp_zmq.write_to_rime_socket(json_data)
            if send_success then
                logger.info("🍴 粘贴命令发送成功，等待服务端执行")

                -- 可选：等待服务端响应
                local response = tcp_zmq.process_rime_socket_data(env)
                if response then
                    logger.info("📥 收到粘贴命令执行响应")
                    return true
                else
                    logger.warn("⚠️ 未收到粘贴命令执行响应")
                    return true -- 命令已发送，视为成功
                end
            else
                logger.error("❌ 粘贴命令发送失败")
                return false
            end
        else
            logger.error("粘贴命令序列化失败: " .. tostring(paste_command))
            return false
        end
    end)

    if not success then
        logger.error("发送粘贴命令失败: " .. tostring(error_msg))
        return false
    end

    return true
end

-- 公开接口：发送对话消息到AI服务（仅发送）
function tcp_zmq.send_chat_message(commit_text, assistant_id, response_key)
    local success, error_msg = pcall(function()
        local current_time = get_current_time_ms()

        -- 构建对话消息数据
        local chat_data = {
            messege_type = "chat",
            commit_text = commit_text, -- 对话内容
            assistant_id = assistant_id, -- AI对话类型
            -- response_key = response_key,
            timestamp = current_time
        }

        if response_key then
            chat_data.response_key = response_key
        end

        -- 序列化聊天数据
        local json_data = json.encode(chat_data)
        logger.debug("发送对话消息json_data: " .. tostring(json_data))

        if json_data then
            -- 写入AI转换服务TCP套接字
            tcp_zmq.write_to_ai_socket(json_data)
            logger.debug("对话消息发送成功，类型: " .. tostring(assistant_id))
        else
            logger.error("对话消息序列化失败: " .. tostring(chat_data))
            return false
        end
    end)

    if not success then
        logger.error("发送对话消息失败: " .. tostring(error_msg))
        return false
    end

    return true
end

-- 初始化系统
function tcp_zmq.init()
    logger.info("双端口TCP套接字状态同步系统初始化")

    -- 检查是否已经初始化
    logger.info("socket_system.is_initialized: " .. tostring(socket_system.is_initialized))
    if socket_system.is_initialized then
        return true
    end

    logger.clear()

    -- 尝试连接到Rime状态服务
    local rime_connected = tcp_zmq.connect_to_rime_server()
    -- 尝试连接到AI转换服务
    local ai_connected = tcp_zmq.connect_to_ai_server()

    if rime_connected or ai_connected then
        socket_system.is_initialized = true
        logger.info("双端口TCP套接字系统初始化成功")
        if rime_connected then
            logger.info("Rime状态服务连接成功")
        end
        if ai_connected then
            logger.info("AI转换服务连接成功")
        end
        logger.info("双端口TCP套接字系统初始化完成")
        return true
    end

    logger.info("双端口TCP套接字系统初始化失败，但系统仍可工作（离线模式）")
    socket_system.is_initialized = true -- 允许离线工作
    logger.info("双端口TCP套接字系统初始化完成")
    return true
end

-- 清理资源
function tcp_zmq.fini()
    logger.info("双端口ZeroMQ套接字系统清理")

    -- 断开所有ZeroMQ连接
    tcp_zmq.disconnect_from_server()

    if socket_system.zmq_context then
        pcall(function()
            socket_system.zmq_context:term()
        end)
        socket_system.zmq_context = nil
    end

    logger.info("双端口ZeroMQ套接字系统清理完成")
end

return tcp_zmq
