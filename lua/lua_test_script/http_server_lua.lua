--[[
Rime HTTP 服务器插件 - 使用 lua-http 库
提供 HTTP API 接口用于获取 Rime 状态和修改设置

依赖：
- lua-http: luarocks install http

功能：
1. 获取当前输入状态
3. 修改方案设置
5. 获取统计信息
--]] 

-- 引入日志工具模块
local logger_module = require("logger")

-- HTTP服务器模块
local HttpServer = {}

-- 创建当前模块的日志记录器
local logger = logger_module.create("http_server_lua", {
    enabled = true,
    unique_file_log = false -- 启用日志以便测试
})

logger.info("开始导入http.server")

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

local ok_server, server = pcall(require, "http.server")
if not ok_server then
    logger.error("无法加载 http.server 模块: " .. tostring(server))
    error("无法加载 http.server 模块: " .. tostring(server))
end

local ok_headers, headers = pcall(require, "http.headers")
if not ok_headers then
    logger.error("无法加载 http.headers 模块: " .. tostring(headers))
    error("无法加载 http.headers 模块: " .. tostring(headers))
end
-- local util = require ("http.util")

logger.info("导入http.server完成")

-- 获取当前文件的目录
-- print(debug.getinfo(1))
-- local current_dir = debug.getinfo(1).source:match("@?(.*/)")
-- package.path = package.path .. ";" .. current_dir .. "?.lua"
local json = require("json")



-- 默认配置
local default_config = {
    host = "127.0.0.1",
    port = 8080,
    tls = false,
    enabled = true
}



-- 服务器实例（单例状态）
local srv = nil
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
    status_code = status_code or "200"
    local response_body = json.encode(data)

    local response_headers = headers.new()
    response_headers:append(":status", status_code)
    response_headers:append("content-type", "application/json")
    response_headers:append("content-length", tostring(#response_body))
    response_headers:append("access-control-allow-origin", "*") -- 允许跨域
    response_headers:append("access-control-allow-methods", "GET, POST, PUT, DELETE, OPTIONS")
    response_headers:append("access-control-allow-headers", "Content-Type")

    return response_headers, response_body
end

-- 创建文本响应
local function create_text_response(text, status_code)
    status_code = status_code or "200"
    local response_body = text

    local response_headers = headers.new()
    response_headers:append(":status", status_code)
    response_headers:append("content-type", "text/plain")
    response_headers:append("content-length", tostring(#response_body))
    response_headers:append("access-control-allow-origin", "*")

    return response_headers, response_body
end

-- 读取请求体
local function read_request_body(stream)
    local body = ""
    local chunk
    repeat
        chunk = stream:get_body_as_string()
        if chunk then
            body = body .. chunk
        end
    until not chunk
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
    if path == "/rime/status" then
        local status = {
            connected = false,
            schema_id = "未知",
            schema_name = "未知",
            ascii_mode = false
        }

        -- 检查是否有 Rime 上下文
        if rime_context.env then
            status.connected = true

            -- 获取当前方案信息
            local schema = rime_context.env.engine.schema
            if schema then
                status.schema_id = schema.schema_id or "未知"
                status.schema_name = schema.schema_name or "未知"
            end

            -- 获取 ASCII 模式状态
            if rime_context.env.context then
                status.ascii_mode = rime_context.env.context:get_option("ascii_mode") or false
            end

            local context = rime_context.env.engine.context
            rime_context.is_composing = context:is_composing()
            logger("当前输入状态is_composing: " .. rime_context.is_composin)
        end

        return create_json_response({
            status = "running",
            message = "Rime输入法正在运行",
            rime_status = status,
            server_info = {
                host = default_config.host,
                port = default_config.port,
                uptime = os.time()
            }
        })
        -- -- 这里可以调用Rime的API获取状态
        -- return create_json_response({
        --     status = "running",
        --     message = "Rime输入法正在运行",
        --     server_info = {
        --         host = default_config.host,
        --         port = default_config.port,
        --         uptime = os.time() -- 简单的运行时间
        --     }
        -- })
    end

        -- 获取Rime状态
    if path == "/test" then
        -- 这里可以调用Rime的API获取状态
        return create_json_response({
            status = "running",
            message = "Rime输入法正在运行",
            server_info = {
                host = default_config.host,
                port = default_config.port,
                uptime = os.time() -- 简单的运行时间
            }
        })
    end

    -- 切换选项
    if path:match("/rime/option/") and method == "POST" then
        local option_name = path:match("^/rime/option/(.+)$")
        local result = {success = false, message = "未连接到 Rime"}
        
        if rime_context.env.context and option_name then
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
        -- 这里可以读取Rime配置文件
        return create_json_response({
            message = "获取Rime配置",
            config = {
                -- 示例配置，实际使用时应该读取真实的配置
                schema = "wanxiang_pro",
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

        -- 这里应该实际更新Rime配置
        logger.info("接收到配置更新请求: " .. (body or "空"))

        return create_json_response({
            message = "配置更新成功",
            received_config = config_data
        })
    end

    -- 重启Rime
    if path == "/rime/restart" and method == "POST" then
        -- 这里可以调用Rime的重启API
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
    }, "404")
end

-- 请求处理函数
local function handle_request(srv, stream)
    local req_headers = stream:get_headers()
    if not req_headers then
        logger.error("无法获取请求头")
        return
    end

    local method = req_headers:get(":method") or "UNKNOWN"
    local path = req_headers:get(":path") or "/"

    logger.info(string.format("收到请求: %s %s", method, path))

    -- 处理OPTIONS请求（CORS预检）
    if method == "OPTIONS" then
        local response_headers = headers.new()
        response_headers:append(":status", "200")
        response_headers:append("access-control-allow-origin", "*")
        response_headers:append("access-control-allow-methods", "GET, POST, PUT, DELETE, OPTIONS")
        response_headers:append("access-control-allow-headers", "Content-Type")
        response_headers:append("content-length", "0")

        local success, err = pcall(function()
            stream:write_headers(response_headers, false)
            stream:write_body_from_string("")
        end)

        if success then
            logger.info("OPTIONS响应发送成功")
        else
            logger.error("OPTIONS响应发送失败: " .. err)
        end
        return
    end

    -- 读取请求体
    local body = ""
    if method == "POST" or method == "PUT" then
        body = read_request_body(stream)
    end

    local response_headers, response_body

    -- 根据路径分发请求
    if path:match("^/api/") or path:match("^/rime/") or path == "/status" then
        response_headers, response_body = handle_api_request(method, path, body)
    else
        -- 默认响应
        response_headers, response_body = create_text_response(
            "Rime HTTP Server\n" .. "API端点:\n" .. "  GET  /health - 健康检查\n" ..
                "  GET  /rime/status - 获取Rime状态\n" .. "  GET  /rime/config - 获取Rime配置\n" ..
                "  POST /rime/config - 更新Rime配置\n" .. "  POST /rime/restart - 重启Rime\n")
    end

    -- 发送响应
    local success, err = pcall(function()
        stream:write_headers(response_headers, false)
        stream:write_body_from_string(response_body)
    end)

    if success then
        logger.info("响应发送成功")
    else
        logger.error("响应发送失败: " .. err)
    end
end

-- 启动服务器（单例模式）
function HttpServer.start(env, config)
    if server_running then
        logger.info("HTTP服务器已在运行")
        return true
    end

    if not default_config.enabled then
        logger.info("HTTP服务器已禁用")
        return false
    end

    config = config or default_config
    for k, v in pairs(default_config) do
        if config[k] == nil then
            config[k] = v
        end
    end

    HttpServer.set_rime_context(env)

    logger.info("正在启动HTTP服务器...")

    local err
    srv, err = server.listen({
        host = config.host,
        port = config.port,
        tls = config.tls,
        onstream = handle_request
    })

    if not srv then
        logger.error("创建服务器失败: " .. (err or "未知错误"))
        return false
    end

    logger.info(string.format("HTTP服务器已启动在 http://%s:%d", config.host, config.port))
    server_running = true

    -- 在后台运行服务器
    local function run_server()
        local success, err = pcall(function()
            srv:loop(10)
        end)

        if not success then
            logger.error("服务器循环出错: " .. err)
            server_running = false
        end
    end

    -- 使用协程运行服务器，避免阻塞主线程
    local co = coroutine.create(run_server)
    coroutine.resume(co)

    return true
end

-- 停止服务器
function HttpServer.stop()
    if not server_running then
        logger.info("HTTP服务器未在运行")
        return
    end

    if srv then
        srv:close()
        srv = nil
    end

    server_running = false
    logger.info("HTTP服务器已停止")
end

-- 获取服务器状态
function HttpServer.is_running()
    return server_running
end

-- 获取服务器配置
function HttpServer.get_config()
    return default_config
end

-- 更新服务器配置
function HttpServer.update_config(new_config)
    for key, value in pairs(new_config) do
        if default_config[key] ~= nil then
            default_config[key] = value
        end
    end
end

-- 设置 Rime 上下文
function HttpServer.set_rime_context(env)
    if env then
        rime_context.env = env
        logger.info("Rime 已更新 env")
    end
end

-- 初始化函数（单例模式）
function HttpServer.init(env)
    initialization_count = initialization_count + 1

    if not initialized then
        logger.info("HTTP Server: First initialization, starting server...")
        initialized = true
        return HttpServer.start(env)
    else
        logger.info("HTTP Server: Already initialized (" .. initialization_count .. " times)")
        return server_running
    end
end

-- 设置日志回调函数（可选）
function HttpServer.set_log_callback(callback)
    if type(callback) == "function" then
        logger = callback
    end
end

-- 检测是否作为主程序运行
-- if arg and arg[0] and arg[0]:match("http_server_lua%.lua$") then
--     -- 作为独立脚本运行
--     print("Rime HTTP Server 启动中...")

--     -- 解析命令行参数
--     local host = arg[1] or "127.0.0.1"
--     local port = tonumber(arg[2]) or 8080

--     -- 更新配置
--     HttpServer.update_config({
--         host = host,
--         port = port,
--         enabled = true
--     })

--     -- 启动服务器
--     if HttpServer.start() then
--         print(string.format("服务器已启动在 http://%s:%d", host, port))
--         print("按 Ctrl+C 停止服务器")

--         -- 保持主线程运行
--         while true do
--             os.execute("sleep 1")  -- macOS 系统命令
--         end
--     else
--         print("服务器启动失败")
--         os.exit(1)
--     end
-- else
--     -- 作为模块被 require 时
--     HttpServer.init()
-- end

-- HttpServer.init(env)

return HttpServer
