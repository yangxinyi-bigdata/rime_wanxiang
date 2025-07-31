-- Rime HTTP 服务器插件 - 使用 socket 库
-- 提供 HTTP API 接口用于获取 Rime 状态和修改设置
-- 依赖：
-- - socket: 通常已内置在 LuaJIT 中
local logger_module = require("logger")

-- HTTP服务器模块
local RimeTcpServer = {}

-- 创建当前模块的日志记录器
local logger = logger_module.create("rime_socket_server", {
    enabled = true,
    unique_file_log = false -- 启用日志以便测试
})

-- 添加 ARM64 Homebrew 的 Lua 路径
local function setup_lua_paths()
    -- 保存原始路径
    local original_path = package.path
    local original_cpath = package.cpath

    -- 添加 ARM64 Homebrew 路径
    package.path = package.path .. ";/opt/homebrew/share/lua/5.4/?.lua;/opt/homebrew/share/lua/5.4/?/init.lua"
    package.cpath = package.cpath .. ";/opt/homebrew/lib/lua/5.4/?.so;/opt/homebrew/lib/lua/5.4/?/core.so"

    logger.info("已添加 ARM64 Homebrew Lua 路径")
    logger.info("package.path: " .. package.path)
    logger.info("package.cpath: " .. package.cpath)
end

setup_lua_paths()

local ok_socket, socket = pcall(require, "socket")
if not ok_socket then
    logger.error("无法加载 socket 模块: " .. tostring(socket))
    error("无法加载 socket 模块: " .. tostring(socket))
end

-- 获取当前文件的目录
local json = require("json")

-- 默认配置
local default_config = {
    host = "127.0.0.1",
    port = 8080,
    enabled = true
}

-- 服务器实例（单例状态）
local server = nil
local server_running = false
local initialized = false -- 初始化标志
local initialization_count = 0 -- 初始化计数器

-- Rime 上下文存储
local rime_context = {
    env = nil,
    engine = nil,
    context = nil,
    is_composing = false
}

-- 创建JSON响应
local function create_json_response(data, status_code)
    status_code = status_code or "200 OK"
    local response_body = json.encode(data)

    local response = "HTTP/1.1 " .. status_code .. "\r\n" .. "Content-Type: application/json; charset=utf-8\r\n" ..
                         "Content-Length: " .. #response_body .. "\r\n" .. "Access-Control-Allow-Origin: *\r\n" ..
                         "Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS\r\n" ..
                         "Access-Control-Allow-Headers: Content-Type\r\n" .. "Connection: close\r\n" .. "\r\n" ..
                         response_body

    return response
end

-- 创建文本响应
local function create_text_response(text, status_code)
    status_code = status_code or "200 OK"
    local response_body = text

    local response = "HTTP/1.1 " .. status_code .. "\r\n" .. "Content-Type: text/plain; charset=utf-8\r\n" ..
                         "Content-Length: " .. #response_body .. "\r\n" .. "Access-Control-Allow-Origin: *\r\n" ..
                         "Connection: close\r\n" .. "\r\n" .. response_body

    return response
end

-- 读取请求体
local function read_request_body(client, content_length)
    if not content_length or content_length == 0 then
        return ""
    end

    local body = ""
    local total_read = 0

    while total_read < content_length do
        local chunk = client:receive(content_length - total_read)
        if not chunk then
            break
        end
        body = body .. chunk
        total_read = total_read + #chunk
    end

    return body
end

-- API路由处理
local function handle_api_request(method, path, body)
    logger.info(string.format("API请求: %s %s", method, path))

    -- 健康检查
    if path == "/health" then
        return create_json_response({
            status = "ok",
            message = "HTTP服务器运行正常",
            rime_connected = rime_context.env ~= nil
        })
    end

    -- 获取Rime状态
    if path == "/rime/status" or path == "/api/status" then
        logger.info("/rime/status成功执行到这里")
        local status = {
            connected = false,
            schema_id = "未知",
            schema_name = "未知",
            ascii_mode = false,
            input_text = "",
            candidates = {},
            is_composing = false,
            full_shape = false,
            simplified = true
        }

        -- 检查是否有 Rime 上下文
        if rime_context.env then
            local env = rime_context.env
            logger.info("/rime/status成功执行到这里rime_context.env")
            status.connected = true

            -- 获取当前方案信息（带错误捕获）
            local ok, err = pcall(function()

                local engine = env.engine
                local schema = engine.schema
                local schema_id = schema.schema_id or "未知"
                local schema_name = schema.schema_name or "未知"
                logger.info("schema.schema_id: " .. tostring(schema_id))
                logger.info("schema.schema_name: " .. tostring(schema_name))

                local schema = rime_context.env.engine.schema
                if schema then
                    status.schema_id = schema.schema_id or "未知"
                    status.schema_name = schema.schema_name or "未知"
                    logger.info("schema.schema_id: " .. tostring(schema.schema_id))
                    logger.info("schema.schema_name: " .. tostring(schema.schema_name))
                end
            end)
            if not ok then
                logger.error("获取当前方案信息出错: " .. tostring(err))
            end

            -- 获取 ASCII 模式状态
            if rime_context.env.context then
                status.ascii_mode = rime_context.env.context:get_option("ascii_mode") or false
                status.full_shape = rime_context.env.context:get_option("full_shape") or false
                status.simplified = rime_context.env.context:get_option("simplification") or true
            end

            local context = rime_context.env.engine.context
            if context then
                status.is_composing = context:is_composing()
                status.input_text = context.input or ""
            end

        end

        return create_json_response({
            status = "running",
            message = "Rime输入法正在运行",
            data = status,
            server_info = {
                host = default_config.host,
                port = default_config.port,
                uptime = os.time()
            }
        })
    end

    -- 测试端点
    if path == "/test" then
        return create_json_response({
            status = "running",
            message = "Rime输入法正在运行",
            server_info = {
                host = default_config.host,
                port = default_config.port,
                uptime = os.time()
            }
        })
    end

    -- 获取当前输入方案
    if path == "/api/schema" then
        local schema_id = "未知"
        local schema_name = "未知"

        if rime_context.env and rime_context.env.engine.schema then
            schema_id = rime_context.env.engine.schema.schema_id or "未知"
            schema_name = rime_context.env.engine.schema.schema_name or "未知"
        end

        return create_json_response({
            status = "ok",
            data = {
                current_schema = schema_id,
                schema_name = schema_name
            }
        })
    end

    -- 获取候选词
    if path == "/api/candidates" then
        local candidates = {}

        if rime_context.env and rime_context.env.engine.context then
            local context = rime_context.env.engine.context
            local menu = context.menu
            if menu then
                for i = 1, menu.num_candidates do
                    local candidate = menu:get_candidate_at(i - 1)
                    if candidate then
                        table.insert(candidates, candidate.text)
                    end
                end
            end
        end

        return create_json_response({
            status = "ok",
            data = {
                candidates = candidates
            }
        })
    end

    -- 切换选项
    if path:match("/rime/option/") and method == "POST" then
        local option_name = path:match("^/rime/option/(.+)$")
        local result = {
            success = false,
            message = "未连接到 Rime"
        }

        if rime_context.env and rime_context.env.context and option_name then
            local data = body and json.decode(body) or {}
            local value = data.value

            if value ~= nil then
                -- 设置选项
                rime_context.env.context:set_option(option_name, value)
                result.success = true
                result.message = string.format("选项 %s 已设置为 %s", option_name, tostring(value))
            else
                -- 切换选项
                local current = rime_context.env.context:get_option(option_name)
                rime_context.env.context:set_option(option_name, not current)
                result.success = true
                result.message = string.format("选项 %s 已切换", option_name)
            end
        end

        return create_json_response(result)
    end

    -- 获取Rime配置
    if path == "/rime/config" and method == "GET" then
        return create_json_response({
            message = "获取Rime配置",
            config = {
                schema = rime_context.env and rime_context.env.engine.schema.schema_id or "未知",
                page_size = 9,
                ascii_mode = false
            }
        })
    end

    -- 更新Rime配置
    if path == "/rime/config" and method == "POST" then
        local config_data = nil
        if body and body ~= "" then
            config_data = json.decode(body)
        end

        logger.info("接收到配置更新请求: " .. (body or "空"))

        return create_json_response({
            message = "配置更新成功",
            received_config = config_data
        })
    end

    -- 重启Rime
    if path == "/rime/restart" and method == "POST" then
        logger.info("接收到重启请求")
        return create_json_response({
            message = "Rime重启指令已发送"
        })
    end

    -- 404 未找到
    return create_json_response({
        error = "API端点未找到",
        path = path,
        method = method
    }, "404 Not Found")
end

-- 请求处理函数
local function handle_request(client, request_line)
    if not request_line then
        return
    end

    local method, path, http_version = request_line:match("^(%u+)%s+(.-)%s+HTTP/(.+)$")
    if not method or not path then
        return
    end

    logger.info(string.format("收到请求: %s %s", method, path))

    -- 读取请求头
    local headers = {}
    local content_length = 0

    local line
    repeat
        line = client:receive("*l")
        if line and line ~= "" then
            local header_name, header_value = line:match("^([^:]+):%s*(.+)$")
            if header_name and header_value then
                headers[header_name:lower()] = header_value
                if header_name:lower() == "content-length" then
                    content_length = tonumber(header_value) or 0
                end
            end
        end
    until not line or line == ""

    -- 处理OPTIONS请求（CORS预检）
    if method == "OPTIONS" then
        local response = "HTTP/1.1 200 OK\r\n" .. "Access-Control-Allow-Origin: *\r\n" ..
                             "Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS\r\n" ..
                             "Access-Control-Allow-Headers: Content-Type\r\n" .. "Content-Length: 0\r\n" .. "\r\n"

        client:send(response)
        logger.info("OPTIONS响应发送成功")
        return
    end

    -- 读取请求体
    local body = ""
    if method == "POST" or method == "PUT" then
        body = read_request_body(client, content_length)
    end

    local response

    -- 根据路径分发请求
    if path ~= "/" or path ~= "" then
        response = handle_api_request(method, path, body)
    else
        -- 默认响应
        response = create_text_response("Rime HTTP Server\n" .. "API端点:\n" .. "  GET  /health - 健康检查\n" ..
                                            "  GET  /rime/status - 获取Rime状态\n" ..
                                            "  GET  /api/status - 获取Rime状态\n" ..
                                            "  GET  /api/schema - 获取当前方案\n" ..
                                            "  GET  /api/candidates - 获取候选词\n" ..
                                            "  GET  /rime/config - 获取Rime配置\n" ..
                                            "  POST /rime/config - 更新Rime配置\n" ..
                                            "  POST /rime/restart - 重启Rime\n" ..
                                            "  POST /rime/option/<name> - 切换选项\n")
    end

    -- 发送响应
    local success, err = pcall(function()
        client:send(response)
    end)

    if success then
        logger.info("响应发送成功")
    else
        logger.error("响应发送失败: " .. tostring(err))
    end
end

-- 启动服务器（单例模式）
function RimeTcpServer.start(env, config)
    if server_running then
        logger.info("TCP服务器已在运行")
        return true
    end

    if not default_config.enabled then
        logger.info("TCP服务器已禁用")
        return false
    end

    config = config or default_config
    for k, v in pairs(default_config) do
        if config[k] == nil then
            config[k] = v
        end
    end

    RimeTcpServer.set_rime_context(env)

    logger.info("正在启动TCP服务器...")

    local err
    server, err = socket.bind(config.host, config.port)

    if not server then
        logger.error("创建服务器失败: " .. (err or "未知错误"))
        return false
    end

    -- 设置为非阻塞模式，避免卡死输入法
    server:settimeout(0)

    logger.info(string.format("TCP服务器已启动在 http://%s:%d", config.host, config.port))
    server_running = true

    return true
end

-- 处理服务器事件（非阻塞）
function RimeTcpServer.process()
    if not server or not server_running then
        return
    end

    -- 使用 select 检查是否有连接可接受
    local readable, _, err = socket.select({server}, nil, 0)
    if #readable == 0 then
        return -- 没有待处理的连接
    end

    -- 非阻塞接受连接
    local client, err = server:accept()
    if client then
        -- 设置客户端超时
        client:settimeout(0.1) -- 100毫秒超时，而不是完全非阻塞

        -- 接收请求行
        local request_line, err = client:receive("*l")
        if request_line then
            -- 处理请求
            handle_request(client, request_line)
        end

        client:close()
    end
    -- 忽略timeout错误，这是正常的
end

-- 停止服务器
function RimeTcpServer.stop()
    if not server_running then
        logger.info("TCP服务器未在运行")
        return
    end

    if server then
        server:close()
        server = nil
    end

    server_running = false
    logger.info("TCP服务器已停止")
end

-- 获取服务器状态
function RimeTcpServer.is_running()
    return server_running
end

-- 获取服务器配置
function RimeTcpServer.get_config()
    return default_config
end

-- 更新服务器配置
function RimeTcpServer.update_config(new_config)
    for key, value in pairs(new_config) do
        if default_config[key] ~= nil then
            default_config[key] = value
        end
    end
end

-- 设置 Rime 上下文
function RimeTcpServer.set_rime_context(env)
    if env then
        rime_context.env = env
        logger.info("Rime 已更新 env")
    end
end

-- 更新Rime状态（由输入法主程序调用）
function RimeTcpServer.update_state(new_state)
    -- 这个函数用于外部更新状态，现在主要通过 rime_context 获取实时状态
    logger.info("更新Rime状态: " .. json.encode(new_state))
end

-- 初始化函数（单例模式）
function RimeTcpServer.init(env)
    initialization_count = initialization_count + 1

    if not initialized then
        logger.info("TCP Server: First initialization, starting server...")
        initialized = true
        return RimeTcpServer.start(env)
    else
        logger.info("TCP Server: Already initialized (" .. initialization_count .. " times)")
        return server_running
    end
end

-- 设置日志回调函数（可选）
function RimeTcpServer.set_log_callback(callback)
    if type(callback) == "function" then
        logger = callback
    end
end

-- 获取服务器端口
function RimeTcpServer.get_port()
    return default_config.port
end

-- 检测是否作为主程序运行
if arg and arg[0] and arg[0]:match("rime_socket_server%.lua$") then
    -- 作为独立脚本运行
    logger.info("Rime Socket Server 启动中...")

    -- 解析命令行参数
    local host = arg[1] or "127.0.0.1"
    local port = tonumber(arg[2]) or 8080

    -- 更新配置
    RimeTcpServer.update_config({
        host = host,
        port = port,
        enabled = true
    })

    -- 启动服务器
    if RimeTcpServer.start() then
        logger.info(string.format("服务器已启动在 http://%s:%d", host, port))
        logger.info("API端点:")
        logger.info("  GET  /health - 健康检查")
        logger.info("  GET  /rime/status - 获取Rime状态")
        logger.info("  GET  /api/status - 获取Rime状态")
        logger.info("  GET  /api/schema - 获取当前方案")
        logger.info("  GET  /api/candidates - 获取候选词")
        logger.info("  GET  /test - 测试端点")
        logger.info("  POST /rime/option/<name> - 切换选项")
        logger.info("  GET  /rime/config - 获取Rime配置")
        logger.info("  POST /rime/config - 更新Rime配置")
        logger.info("  POST /rime/restart - 重启Rime")
        logger.info("\n按 Ctrl+C 停止服务器")

        -- 保持主线程运行，处理请求
        local last_status_time = os.time()
        local request_count = 0

        -- 使用 pcall 来捕获 Ctrl+C 中断
        local function main_loop()
            while RimeTcpServer.is_running() do
                -- 处理服务器请求
                RimeTcpServer.process()

                -- 计数处理的请求
                request_count = request_count + 1

                -- 每30秒显示一次状态
                local current_time = os.time()
                if current_time - last_status_time >= 30 then
                    logger.info(string.format("[%s] 服务器运行中... 已处理 %d 次请求检查",
                        os.date("%Y-%m-%d %H:%M:%S"), request_count))
                    last_status_time = current_time
                end

                -- 使用 socket.sleep 代替 os.execute("sleep")，更容易被中断
                if socket.sleep then
                    socket.sleep(0.01)
                else
                    -- 如果没有 socket.sleep，使用简单的循环延迟
                    for i = 1, 10000 do
                        -- 简单的延迟循环
                    end
                end
            end
        end

        -- 运行主循环，捕获中断
        local success, err = pcall(main_loop)

        if not success then
            logger.info("\n服务器被中断或出现错误: " .. tostring(err))
        end

        logger.info("\n正在关闭服务器...")
        RimeTcpServer.stop()
        logger.info("服务器已关闭")
        os.exit(0)
    else
        logger.info("服务器启动失败")
        os.exit(1)
    end
else
    -- 作为模块被 require 时的初始化
    logger.info("作为模块加载 rime_socket_server")
end

return RimeTcpServer
