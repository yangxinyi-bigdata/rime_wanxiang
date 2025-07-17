local server = require("http.server")
local headers = require("http.headers")

print("正在启动HTTP服务器...")

-- 使用正确的 server.listen 方法
local srv, err = server.listen({
    host = "127.0.0.1",
    port = 8080,
    tls = false,  -- 禁用TLS，使用纯HTTP
    onstream = function(srv, stream)
        print("收到新的HTTP请求连接")
        
        -- 读取请求头
        local req_headers = stream:get_headers()
        if req_headers then
            local method = req_headers:get(":method") or "UNKNOWN"
            local path = req_headers:get(":path") or "/"
            print(string.format("请求: %s %s", method, path))
        end
        
        -- 创建响应
        local response_body = "Hello from Lua HTTP Server!\n"
        
        -- 创建正确的响应头对象
        local response_headers = headers.new()
        response_headers:append(":status", "200")
        response_headers:append("content-type", "text/plain")
        response_headers:append("content-length", tostring(#response_body))
        
        -- 发送响应
        local success, err = pcall(function()
            stream:write_headers(response_headers, false)
            stream:write_body_from_string(response_body)
        end)
        
        if success then
            print("响应发送成功")
        else
            print("响应发送失败:", err)
        end
    end
})

if not srv then
    print("创建服务器失败:", err)
    return
end

print("HTTP服务器已启动在 http://127.0.0.1:8080")
print("按 Ctrl+C 停止服务器")

-- 启动服务器循环
local success, err = pcall(function()
    srv:loop()
end)

if not success then
    print("服务器循环出错:", err)
end
