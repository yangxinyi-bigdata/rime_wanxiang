#!/usr/bin/env lua

-- 测试 tcp_socket_cached_sync.lua 模块的双向通信功能
-- 直接使用现有的TCP套接字缓存同步系统

print("=== 测试TCP套接字缓存同步系统 ===")

-- 添加项目lua目录到搜索路径
local function setup_lua_paths()
    package.path = package.path .. ";/Users/yangxinyi/Library/Rime/lua/?.lua;/Users/yangxinyi/Library/Rime/lua/?/init.lua"
    print("✅ Lua路径已配置")
end

setup_lua_paths()

-- 加载TCP套接字缓存同步模块
local tcp_sync = require("tcp_socket_cached_sync")

print("✅ TCP套接字缓存同步模块加载成功")

-- 初始化系统
print("🚀 初始化TCP套接字缓存系统...")
local init_success = tcp_sync.init()

if not init_success then
    print("❌ 初始化失败")
    os.exit(1)
end

print("✅ 初始化成功!")

-- 获取连接信息
local conn_info = tcp_sync.get_connection_info()
print(string.format("🔗 连接信息: %s:%d", conn_info.host, conn_info.port))
print(string.format("📡 连接状态: %s", conn_info.is_connected and "已连接" or "未连接"))

-- 模拟上下文对象（简化版本）
local mock_context = {
    _composing = false,
    _input = "",
    _ascii_mode = false,
    
    is_composing = function(self)
        return self._composing
    end,
    
    get_option = function(self, option)
        if option == "ascii_mode" then
            return self._ascii_mode
        end
        return false
    end
}

-- 设置mock_context的input属性
mock_context.input = ""

-- 定期测试函数
local function run_periodic_test()
    local test_count = 0
    local start_time = os.time()
    
    print("🎯 开始定期测试，每10秒发送一次状态更新")
    print("📊 同时会处理来自服务端的主动消息")
    print("⏹️  按Ctrl+C停止测试")
    
    while true do
        test_count = test_count + 1
        local current_time = os.time()
        
        -- 模拟不同的输入状态
        if test_count % 3 == 1 then
            mock_context._composing = true
            mock_context._ascii_mode = false
            mock_context.input = "测试输入" .. test_count
        elseif test_count % 3 == 2 then
            mock_context._composing = false
            mock_context._ascii_mode = false
            mock_context.input = ""
        else
            mock_context._composing = true
            mock_context._ascii_mode = true
            mock_context.input = "test" .. test_count
        end
        
        -- 发送状态更新
        print(string.format("\n📤 [%s] 发送状态更新 #%d", os.date("%H:%M:%S"), test_count))
        print(string.format("   输入中: %s", mock_context._composing))
        print(string.format("   模式: %s", mock_context._ascii_mode and "ASCII" or "中文"))
        print(string.format("   内容: '%s'", mock_context.input))
        
        local update_success = tcp_sync.update_state_cached(mock_context)
        if update_success then
            print("✅ 状态更新发送成功")
        else
            print("❌ 状态更新发送失败")
        end
        
        -- 手动处理来自服务端的数据
        print("📨 检查服务端消息...")
        
        -- 适度检查，避免过度频繁
        local received_count = 0
        local received_messages = {}
        for i = 1, 3 do  -- 减少到3次检查
            local received_data = tcp_sync.manual_process_socket_data()
            if received_data then
                received_count = received_count + 1
                table.insert(received_messages, string.format("消息#%d", received_count))
                print(string.format("📥 [%s] 收到并处理服务端消息 #%d", os.date("%H:%M:%S"), received_count))
            end
            -- 减少延时时间
            local start_delay = os.clock()
            while os.clock() - start_delay < 0.05 do -- 50ms
                -- 忙等待
            end
        end
        
        if received_count == 0 then
            print("📭 当前没有服务端消息")
        else
            print(string.format("📬 本次检查共处理 %d 条服务端消息: %s", 
                  received_count, table.concat(received_messages, ", ")))
        end
        
        -- 显示连接状态
        if tcp_sync.is_socket_ready() then
            print("🟢 TCP连接正常")
        else
            print("🔴 TCP连接异常")
        end
        
        -- 显示缓存统计
        local stats = tcp_sync.get_cache_stats()
        print(string.format("📊 缓存统计: 大小=%d, 连接=%s, 失败次数=%d", 
              stats.cache_size, 
              stats.is_connected and "是" or "否", 
              stats.write_failure_count))
        
        -- 等待10秒
        print("⏳ 等待10秒...")
        for i = 1, 50 do  -- 改为50次，每次200ms
            -- 每2秒检查一次服务端消息，避免过度频繁
            if i % 10 == 0 then  -- 每10次（即每2秒）检查一次
                tcp_sync.manual_process_socket_data()
            end
            -- 使用简单的延时替代socket.sleep
            local start_sleep = os.clock()
            while os.clock() - start_sleep < 0.2 do  -- 200ms
                -- 忙等待
            end
        end
    end
end

-- 信号处理
local function cleanup()
    print("\n🛑 收到停止信号，正在清理...")
    
    -- 清理TCP套接字缓存系统
    tcp_sync.fini()
    
    print("👋 测试结束，再见!")
    os.exit(0)
end

-- 设置退出处理
local original_exit = os.exit
os.exit = function(code)
    cleanup()
    original_exit(code or 0)
end

-- 运行主测试
print("\n" .. string.rep("=", 50))
print("开始双向通信测试")
print("服务端会每15秒发送主动消息")
print("客户端会每10秒发送状态更新")
print(string.rep("=", 50))

-- 检查TCP连接状态
if tcp_sync.is_socket_ready() then
    print("🎉 TCP连接就绪，开始测试")
    run_periodic_test()
else
    print("⚠️  TCP连接未就绪，但仍可测试离线模式")
    print("💡 请确保Python服务端正在运行: python3 tcp_continuous_test_server.py")
    run_periodic_test()
end
