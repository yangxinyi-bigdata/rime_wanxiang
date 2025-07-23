#!/usr/bin/env lua

-- 持续双向TCP通信测试脚本
-- 与服务端保持连接，定期发送消息并接收响应

-- 添加项目lua目录到搜索路径
local function setup_lua_paths()
    -- 直接添加绝对路径
    package.path = package.path .. ";/Users/yangxinyi/Library/Rime/lua/?.lua;/Users/yangxinyi/Library/Rime/lua/?/init.lua"
    print("当前package.path:", package.path)
end

setup_lua_paths()

local socket = require("socket")
local json = require("json")

print("=== 持续TCP双向通信测试 ===")

-- 全局变量
local client = nil
local connected = false
local message_count = 0
local start_time = os.time()

-- 获取当前时间戳
local function get_timestamp()
    return os.time() * 1000
end

-- 格式化时间显示
local function format_time()
    return os.date("%H:%M:%S")
end

-- 连接到服务端
local function connect_to_server(host, port)
    print(string.format("🔗 [%s] 尝试连接到 %s:%d", format_time(), host, port))
    
    local new_client, err = socket.connect(host, port)
    if not new_client then
        print(string.format("❌ [%s] 连接失败: %s", format_time(), err))
        return false
    end
    
    client = new_client
    connected = true
    
    -- 设置超时时间（1秒），用于非阻塞读取
    client:settimeout(1.0)
    
    print(string.format("✅ [%s] 连接成功!", format_time()))
    return true
end

-- 断开连接
local function disconnect()
    if client then
        client:close()
        client = nil
    end
    connected = false
    print(string.format("📤 [%s] 连接已断开", format_time()))
end

-- 发送消息到服务端
local function send_message(data)
    if not connected or not client then
        print(string.format("⚠️  [%s] 未连接，无法发送消息", format_time()))
        return false
    end
    
    local json_str = json.encode(data)
    
    local success, err = pcall(function()
        client:send(json_str .. "\n")
    end)
    
    if success then
        message_count = message_count + 1
        print(string.format("📤 [%s] 发送消息 #%d: %s", format_time(), message_count, json_str))
        return true
    else
        print(string.format("❌ [%s] 发送失败: %s", format_time(), err))
        connected = false
        return false
    end
end

-- 接收消息从服务端
local function receive_messages()
    if not connected or not client then
        return
    end
    
    -- 尝试读取所有可用的消息
    while connected do
        local line, err = client:receive("*l")
        
        if line then
            print(string.format("📨 [%s] 收到响应: %s", format_time(), line))
            
            -- 尝试解析JSON响应
            local success, parsed = pcall(json.decode, line)
            if success and parsed then
                if parsed.response then
                    print(string.format("🎯 [%s] 解析响应类型: %s", format_time(), parsed.response))
                end
                if parsed.command then
                    print(string.format("⚡ [%s] 收到服务端命令: %s", format_time(), parsed.command))
                    
                    -- 响应服务端的命令
                    if parsed.command == "ping" or parsed.command == "server_ping" then
                        local pong_response = {
                            response = "pong",
                            timestamp = get_timestamp(),
                            client_id = "lua_test_client",
                            responding_to = parsed.command
                        }
                        send_message(pong_response)
                    elseif parsed.command == "server_status_check" then
                        local status_response = {
                            response = "client_status",
                            client_info = {
                                runtime = os.time() - start_time,
                                messages_sent = message_count,
                                client_type = "lua_test_client"
                            },
                            timestamp = get_timestamp(),
                            responding_to = "server_status_check"
                        }
                        send_message(status_response)
                    elseif parsed.command == "server_broadcast" then
                        print(string.format("📢 [%s] 服务端广播: %s", format_time(), parsed.message or "无消息内容"))
                        local broadcast_response = {
                            response = "broadcast_received",
                            timestamp = get_timestamp(),
                            client_id = "lua_test_client",
                            broadcast_id = parsed.broadcast_id
                        }
                        send_message(broadcast_response)
                    end
                end
            end
            
        elseif err == "timeout" then
            -- 超时是正常的，表示当前没有数据
            break
        elseif err == "closed" then
            print(string.format("🔌 [%s] 服务端关闭连接", format_time()))
            connected = false
            break
        else
            print(string.format("❌ [%s] 读取错误: %s", format_time(), err))
            break
        end
    end
end

-- 发送不同类型的测试消息
local function send_test_messages()
    local current_time = get_timestamp()
    local runtime = os.time() - start_time
    
    -- 模拟不同类型的Rime状态数据
    local message_types = {
        {
            type = "rime_state",
            data = {
                is_composing = true,
                input_mode = "chinese",
                input_text = "测试输入" .. message_count,
                timestamp = current_time,
                message_id = message_count
            }
        },
        {
            type = "command",
            data = {
                command = "get_status",
                timestamp = current_time,
                client_runtime = runtime
            }
        },
        {
            type = "ping",
            data = {
                command = "ping",
                timestamp = current_time,
                message_count = message_count
            }
        }
    }
    
    -- 轮换发送不同类型的消息
    local msg_type = message_types[(message_count % #message_types) + 1]
    print(string.format("📋 [%s] 发送消息类型: %s", format_time(), msg_type.type))
    
    return send_message(msg_type.data)
end

-- 主循环
local function run_continuous_test(host, port)
    -- 首次连接
    if not connect_to_server(host, port) then
        return false
    end
    
    print(string.format("🎯 [%s] 开始持续双向通信测试", format_time()))
    print(string.format("📊 [%s] 每10秒发送一次消息，按Ctrl+C停止", format_time()))
    
    local last_send_time = 0
    local send_interval = 10 -- 10秒发送间隔
    
    while connected do
        local current_time = os.time()
        
        -- 持续接收消息
        receive_messages()
        
        -- 检查是否需要发送消息
        if current_time - last_send_time >= send_interval then
            if send_test_messages() then
                last_send_time = current_time
            else
                -- 发送失败，尝试重连
                print(string.format("🔄 [%s] 发送失败，尝试重连...", format_time()))
                disconnect()
                socket.sleep(2) -- 等待2秒后重连
                
                if connect_to_server(host, port) then
                    last_send_time = current_time
                else
                    print(string.format("💔 [%s] 重连失败，退出测试", format_time()))
                    break
                end
            end
        end
        
        -- 短暂休眠，避免CPU占用过高
        socket.sleep(0.1)
    end
    
    disconnect()
    return true
end

-- 信号处理（简单实现）
local function setup_signal_handler()
    -- 注册退出处理
    local original_exit = os.exit
    os.exit = function(code)
        print(string.format("\n🛑 [%s] 收到退出信号，正在清理...", format_time()))
        
        if connected then
            -- 发送断开消息
            local goodbye_msg = {
                command = "goodbye",
                timestamp = get_timestamp(),
                total_messages = message_count,
                runtime_seconds = os.time() - start_time
            }
            send_message(goodbye_msg)
            socket.sleep(0.5) -- 等待消息发送完成
        end
        
        disconnect()
        
        local runtime = os.time() - start_time
        print(string.format("📊 [%s] 测试统计:", format_time()))
        print(string.format("   - 运行时长: %d秒", runtime))
        print(string.format("   - 发送消息数: %d", message_count))
        print(string.format("   - 平均发送频率: %.2f消息/分钟", (message_count * 60) / math.max(runtime, 1)))
        print("👋 再见!")
        
        original_exit(code or 0)
    end
end

-- 主函数
local function main()
    setup_signal_handler()
    
    print("LuaSocket版本:", socket._VERSION or "未知")
    print("JSON模块: 可用")
    print("开始时间:", format_time())
    
    -- 运行持续测试
    local success = run_continuous_test("127.0.0.1", 12345)
    
    if success then
        print(string.format("✅ [%s] 测试完成", format_time()))
    else
        print(string.format("❌ [%s] 测试失败", format_time()))
    end
end

-- 启动主程序
main()
