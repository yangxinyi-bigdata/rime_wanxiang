-- Rime输入法TCP服务器插件
-- 用于提供输入法状态API
local socket = require("socket")

local RimeTcpServer = {}

-- 服务器实例
local server = nil
local server_port = 8080
local is_running = false

-- 模拟的Rime状态数据
local rime_state = {
    current_schema = "wanxiang_pro",
    input_text = "",
    candidates = {},
    is_composing = false,
    ascii_mode = false,
    full_shape = false,
    simplified = true
}

-- 初始化服务器
function RimeTcpServer.init(port)
    if server then
        print("TCP服务器已经在运行")
        return false
    end
    
    server_port = port or 8080
    server = socket.bind("localhost", server_port)
    
    if not server then
        print("无法绑定端口:", server_port)
        return false
    end
    
    -- 设置为非阻塞模式，避免卡死输入法
    server:settimeout(0)
    is_running = true
    
    print("Rime TCP服务器启动成功，端口:", server_port)
    print("API端点: http://localhost:" .. server_port .. "/api/status")
    return true
end

-- 更新Rime状态（由输入法主程序调用）
function RimeTcpServer.update_state(new_state)
    for key, value in pairs(new_state) do
        rime_state[key] = value
    end
end

-- 处理HTTP请求
local function handle_request(client, request_line)
    if not request_line then
        return
    end
    
    local method, path = request_line:match("^(%u+)%s+(.-)%s+HTTP/")
    if not method or not path then
        return
    end
    
    local response_body = ""
    local status_code = "200 OK"
    
    -- 路由处理
    if path == "/api/status" then
        -- 返回当前输入法状态
        local candidates_json = "[]"
        if rime_state.candidates and #rime_state.candidates > 0 then
            candidates_json = '["' .. table.concat(rime_state.candidates, '","') .. '"]'
        end
        
        response_body = string.format([[{
    "status": "ok",
    "data": {
        "current_schema": "%s",
        "input_text": "%s",
        "candidates": %s,
        "is_composing": %s,
        "ascii_mode": %s,
        "full_shape": %s,
        "simplified": %s
    }
}]], 
            rime_state.current_schema,
            rime_state.input_text,
            candidates_json,
            rime_state.is_composing and "true" or "false",
            rime_state.ascii_mode and "true" or "false",
            rime_state.full_shape and "true" or "false",
            rime_state.simplified and "true" or "false"
        )
    elseif path == "/api/schema" then
        -- 返回当前输入方案
        response_body = string.format([[{
    "status": "ok",
    "data": {
        "current_schema": "%s"
    }
}]], rime_state.current_schema)
    elseif path == "/api/candidates" then
        -- 返回候选词
        local candidates_json = "[]"
        if rime_state.candidates and #rime_state.candidates > 0 then
            candidates_json = '["' .. table.concat(rime_state.candidates, '","') .. '"]'
        end
        response_body = string.format([[{
    "status": "ok",
    "data": {
        "candidates": %s
    }
}]], candidates_json)
    else
        status_code = "404 Not Found"
        response_body = '{"status": "error", "message": "API endpoint not found"}'
    end
    
    -- 发送HTTP响应
    local response = "HTTP/1.1 " .. status_code .. "\r\n"
          .. "Content-Type: application/json; charset=utf-8\r\n"
          .. "Content-Length: " .. #response_body .. "\r\n"
          .. "Access-Control-Allow-Origin: *\r\n"
          .. "Connection: close\r\n"
          .. "\r\n"
          .. response_body
    
    client:send(response)
end

-- 处理服务器事件（非阻塞）
function RimeTcpServer.process()
    if not server or not is_running then
        return
    end
    
    -- 非阻塞接受连接
    local client, err = server:accept()
    if client then
        -- 设置客户端超时
        client:settimeout(0.1)
        
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

-- 关闭服务器
function RimeTcpServer.shutdown()
    if server then
        server:close()
        server = nil
        is_running = false
        print("Rime TCP服务器已关闭")
    end
end

-- 获取服务器状态
function RimeTcpServer.is_running()
    return is_running
end

-- 获取服务器端口
function RimeTcpServer.get_port()
    return server_port
end

return RimeTcpServer
