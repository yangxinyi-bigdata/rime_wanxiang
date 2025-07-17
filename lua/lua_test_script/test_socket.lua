local socket = require("socket")

-- 创建 TCP 服务器
local server = socket.bind("localhost", 8080)
if not server then
    print("Failed to bind to localhost:8080")
    return
end

-- 设置服务器超时
-- 0 = 非阻塞模式（立即返回）
-- nil = 完全阻塞模式（一直等待）
-- 数字 = 超时模式（等待指定秒数）
server:settimeout(2)  -- 2秒超时，减少循环频率
print("Server started on localhost:8080")
print("Press Ctrl+C to stop the server")
print("Server timeout set to 2 seconds")

while true do
    local client, err = server:accept()
    if client then
        print("Client connected!")
        client:settimeout(5)  -- 客户端连接5秒超时
        
        -- 接收HTTP请求头
        local headers = {}
        local first_line = nil
        
        while true do
            local line, err = client:receive("*l")
            if not line then
                if err == "timeout" then
                    print("Client timeout")
                else
                    print("Receive error:", err)
                end
                break
            end
            
            if not first_line then
                first_line = line
                print("Request line:", line)
            end
            
            -- 空行表示头部结束
            if line == "" then
                break
            end
            
            table.insert(headers, line)
        end
        
        if first_line then
            -- 解析请求方法和路径
            local method, path, version = first_line:match("^(%u+)%s+(.-)%s+(HTTP/%d%.%d)")
            if method then
                print("Method:", method)
                print("Path:", path)
                print("Version:", version)
                
                -- 解析GET参数
                if method == "GET" then
                    local query_start = path:find("?")
                    if query_start then
                        local query_string = path:sub(query_start + 1)
                        print("Query string:", query_string)
                        
                        -- 解析参数
                        for k, v in query_string:gmatch("([^&=]+)=([^&=]*)") do
                            print("Parameter:", k, "=", v)
                        end
                    end
                end
            end
            
            -- 打印所有头部信息
            print("Headers:")
            for i, header in ipairs(headers) do
                print("  " .. header)
            end
            
            -- 发送HTTP响应
            local response_body = '{"status": "ok", "message": "Request received successfully"}'
            local response = "HTTP/1.1 200 OK\r\n"
                  .. "Content-Type: application/json\r\n"
                  .. "Content-Length: " .. #response_body .. "\r\n"
                  .. "Connection: close\r\n"
                  .. "\r\n"
                  .. response_body
            
            client:send(response)
            print("Response sent")
        end
        
        client:close()
        print("Connection closed")
        print("---")
    elseif err ~= "timeout" then
        -- 只有非超时错误才打印
        print("Accept error:", err)
    end
    
    -- 由于设置了2秒超时，这里可以减少或去掉sleep
    -- 如果使用非阻塞模式(timeout=0)，则需要sleep避免CPU占用过高
    -- socket.sleep(0.01)  -- 注释掉，因为我们使用了超时模式
end
