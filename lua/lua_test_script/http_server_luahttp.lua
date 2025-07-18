--[[
Rime HTTP 服务器插件 - 使用 lua-http 库
提供 HTTP API 接口用于获取 Rime 状态和修改设置

依赖：
- lua-http: luarocks install http

功能：
1. 获取当前输入状态
3. 修改方案设置
5. 获取统计信息

使用方法：
在 rime.lua 中添加：
--]] 

local server = require "http.server"
local headers = require "http.headers"
local util = require "http.util"

-- 使用本地 JSON 库
local json = require "json"
-- 引入日志工具模块
local logger_module = require("logger")
-- 创建当前模块的日志记录器
local logger = logger_module.create("http_server_luahttp", {
    enabled = true,
    unified_log = false -- 启用日志以便测试
})
-- 单例模式的 HTTP 服务器
local HttpServer = {}

-- 配置
local config = {
    host = "127.0.0.1",
    port = 8080,
    enabled = true,
    tls = false
}

-- 单例状态
local srv = nil
local current_engine = nil
local server_thread = nil
local running = false
local initialized = false -- 初始化标志
local initialization_count = 0 -- 初始化计数器

-- 创建JSON响应
local function json_response(data, status_code)
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

-- 创建 HTTP 响应
local function create_response(status, body, content_type)
    content_type = content_type or "application/json"

    local headers = http_headers.new()
    headers:upsert("content-type", content_type)
    headers:upsert("content-length", tostring(#body))
    headers:upsert("access-control-allow-origin", "*")
    headers:upsert("access-control-allow-methods", "GET, POST, PUT, DELETE, OPTIONS")
    headers:upsert("access-control-allow-headers", "Content-Type, Authorization")
    headers:upsert("server", "Rime-Lua-HTTP/1.0")

    return status, headers, body
end

-- -- 创建 JSON 响应
-- local function json_response(status, data)
--     local body = json.encode(data)
--     return create_response(status, body, "application/json")
-- end

-- 创建错误响应
local function error_response(status, message)
    return json_response(status, {
        error = true,
        message = message,
        timestamp = os.time()
    })
end

-- 解析请求体
local function parse_request_body(body)
    if not body or body == "" then
        return {}
    end

    local ok, data = pcall(json.decode, body)
    if ok then
        return data
    else
        return {}
    end
end

-- todo 获取 Rime 状态
-- local function get_rime_status()
--     if not current_engine then
--         return {
--             error = "Engine not available",
--             status = "inactive",
--             timestamp = os.time()
--         }
--     end

--     local context = current_engine.context
--     local schema = current_engine.schema

--     local status_data = {
--         is_composing = context:is_composing()
--     }

--     return status_data
-- end

local function get_rime_status()
    -- if not current_engine then
    --     return {
    --         error = "Engine not available",
    --         status = "inactive",
    --         timestamp = os.time()
    --     }
    -- end

    local status_data = {
        is_composing = true,
        status = "inactive",
        timestamp = os.time()
    }

    return status_data
end

-- 更新配置
local function update_config(config_data)
    if not current_engine then
        return {
            error = "Engine not available",
            success = false,
            timestamp = os.time()
        }
    end

    local context = current_engine.context
    if not context then
        return {
            error = "Context not available",
            success = false,
            timestamp = os.time()
        }
    end

    local updated_options = {}

    -- 更新选项
    for key, value in pairs(config_data) do
        context:set_option(key, value)
        updated_options[key] = value
    end

    return {
        success = true,
        message = "Configuration updated",
        updated_options = updated_options,
        timestamp = os.time()
    }
end

-- 请求处理器
local function handle_request(stream)
    local request_headers = stream:get_headers()
    if not request_headers then
        logger.error("无法获取请求头")
        return
    end

    local method = request_headers:get(":method") or "GET"
    local path = request_headers:get(":path") or "/"

    logger.info(string.format("API请求: %s %s", method, path))

       
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

    -- 路由处理
    local response_data = {}
    local status_code = 200

    if method == "GET" then
        if path == "/status" then
            logger.info("/status 开始执行:", method, path)
            response_data = get_rime_status()
        else
            status_code = 404
            response_data = {
                error = "Endpoint not found",
                path = path,
                timestamp = os.time()
            }
        end
    elseif method == "POST" then
        if path == "/config" then
            response_data = update_config()
        else
            status_code = 404
            response_data = {
                error = "Endpoint not found",
                path = path,
                timestamp = os.time()
            }
        end
    else
        status_code = 405
        response_data = {
            error = "Method not allowed",
            method = method,
            timestamp = os.time()
        }
    end

    -- 发送响应
    local status, headers, response_body = json_response(status_code, response_data)
    stream:write_headers(headers, false)
    stream:write_chunk(response_body, true)

    logger.info("Response sent successfully for:", method, path)


end

-- 启动服务器（单例模式）
function HttpServer.start_server()
    -- 检查是否已经运行
    if running then
        logger.info("HTTP Server already running on " .. config.host .. ":" .. config.port)
        return true
    end

    if not config.enabled then
        logger.info("HTTP Server is disabled")
        return false
    end

    logger.info("Starting HTTP Server on " .. config.host .. ":" .. config.port)

    -- 创建服务器
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

    running = true
    logger.info(string.format("HTTP服务器已启动在 http://%s:%d", config.host, config.port))

    -- 在后台运行服务器
    local function run_server()
        local success, err = pcall(function()
            srv:loop()
        end)
        
        if not success then
            logger.error("服务器循环出错: " .. err)
            running = false
        end
    end
    
    -- 使用协程运行服务器，避免阻塞主线程
    local co = coroutine.create(run_server)
    coroutine.resume(co)
    
    return true
end

-- 停止服务器
function HttpServer.stop_server()
    if not running then
        logger.info("HTTP Server is not running")
        return
    end

    running = false
    if server then
        server:close()
        server = nil
    end
    if server_thread then
        server_thread = nil
    end
    logger.info("HTTP Server stopped")
end

-- 服务器循环 tick（需要在适当的地方调用）
--[[ 用于维护服务器的运行状态。：
主要功能
协程管理：这个函数负责推进服务器协程的执行,
状态检查：检查服务器是否正在运行以及服务器线程是否存在,
错误处理：捕获协程执行中的错误并进行相应处理
使用场景
这个函数需要在适当的地方定期调用，比如：
- 在 Rime 的事件循环中
- 定时器回调中
- 其他需要维护服务器状态的地方 ]]
function HttpServer.tick()
    if running and server_thread then -- 检查服务器是否运行且线程存在
        local status = coroutine.status(server_thread)
        if status == "suspended" then
            local ok, err = coroutine.resume(server_thread) -- 恢复协程执行
            if not ok then -- 如果协程执行失败
                logger.info("HTTP Server thread error:", err) -- 打印错误信息
                HttpServer.stop_server() -- 停止服务器
            end
        elseif status == "dead" then
            logger.info("HTTP Server thread is dead, stopping server")
            HttpServer.stop_server()
        end
    end
end

-- 初始化函数（单例模式）
function HttpServer.init()
    initialization_count = initialization_count + 1

    if not initialized then
        logger.info("HTTP Server: First initialization, starting server...")
        initialized = true
        return HttpServer.start_server()
    else
        logger.info("HTTP Server: Already initialized (" .. initialization_count .. " times)")
        return running
    end
end

-- 获取服务器状态
function HttpServer.is_running()
    return running
end

-- 获取服务器配置
function HttpServer.get_config()
    return config
end

-- 更新服务器配置
function HttpServer.update_config(new_config)
    for key, value in pairs(new_config) do
        if config[key] ~= nil then
            config[key] = value
        end
    end
end

-- 这个是没用的函数: 处理器：在输入过程中更新引擎引用（单例模式）
local function http_processor(key, env)
    if env and env.engine then
        HttpServer.set_engine(env.engine)
    end
    -- 定期调用服务器 tick
    HttpServer.tick()
    return 2 -- 不处理按键，继续传递
end

-- 这个是没用的函数: 过滤器：在候选词生成时更新引擎引用（单例模式）
local function http_filter(input, env)
    if env and env.engine then
        HttpServer.set_engine(env.engine)
    end
    return input
end

function HttpServer.set_engine(env)
    if env and env.engine then
        return true
    end
end

-- 模块初始化（当模块被 require 时自动调用）
HttpServer.init()

-- return HttpServer
