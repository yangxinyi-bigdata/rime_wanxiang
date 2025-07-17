local socket = require("socket")

print("=== Socket 模式演示 ===")
print()

-- 创建服务器
local server = socket.bind("localhost", 8081)
if not server then
    print("Failed to bind to localhost:8081")
    return
end

print("选择运行模式：")
print("1. 完全阻塞模式 (settimeout(nil))")
print("2. 非阻塞模式 (settimeout(0))")
print("3. 超时模式 (settimeout(2))")
print()

io.write("请输入选择 (1-3): ")
local choice = io.read()

if choice == "1" then
    print("\n=== 完全阻塞模式 ===")
    print("程序会一直等待连接，直到有客户端连接为止")
    print("优点：CPU占用极低")
    print("缺点：程序会卡住，无法处理其他事情")
    
    server:settimeout(nil)  -- 完全阻塞
    
    while true do
        print("等待连接中... (程序会卡在这里)")
        local client, err = server:accept()
        if client then
            print("客户端连接成功!")
            client:send("HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\n\r\n阻塞模式响应")
            client:close()
        else
            print("错误:", err)
        end
    end

elseif choice == "2" then
    print("\n=== 非阻塞模式 ===")
    print("程序不会等待，立即返回")
    print("优点：程序不会卡住")
    print("缺点：需要不断循环，CPU占用高")
    
    server:settimeout(0)  -- 非阻塞
    
    local loop_count = 0
    while true do
        loop_count = loop_count + 1
        if loop_count % 1000 == 0 then
            print(string.format("已循环 %d 次 (每秒约10000次)", loop_count))
        end
        
        local client, err = server:accept()
        if client then
            print("客户端连接成功!")
            client:send("HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\n\r\n非阻塞模式响应")
            client:close()
        elseif err ~= "timeout" then
            print("错误:", err)
        end
        
        socket.sleep(0.0001)  -- 100微秒，避免CPU占用过高
    end

elseif choice == "3" then
    print("\n=== 超时模式 ===")
    print("程序会等待指定时间，然后继续")
    print("优点：平衡了CPU使用和响应性")
    print("缺点：有轻微的延迟")
    
    server:settimeout(2)  -- 2秒超时
    
    local timeout_count = 0
    while true do
        local client, err = server:accept()
        if client then
            print("客户端连接成功!")
            client:send("HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\n\r\n超时模式响应")
            client:close()
        elseif err == "timeout" then
            timeout_count = timeout_count + 1
            print(string.format("超时 %d 次 (每2秒一次)", timeout_count))
        else
            print("错误:", err)
        end
        
        -- 不需要sleep，因为超时本身就提供了延迟
    end

else
    print("无效选择")
end

server:close()
