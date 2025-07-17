-- 测试Rime TCP服务器
local RimeTcpServer = require("rime_tcp_server")

print("=== Rime TCP服务器测试 ===")

-- 启动服务器
if RimeTcpServer.init(8080) then
    print("服务器启动成功！")
    
    -- 模拟输入法状态更新
    local test_states = {
        {
            current_schema = "wanxiang_pro",
            input_text = "nihao",
            candidates = {"你好", "ni", "hao"},
            is_composing = true,
            ascii_mode = false
        },
        {
            current_schema = "wanxiang_pro", 
            input_text = "shijie",
            candidates = {"世界", "shi", "jie"},
            is_composing = true,
            ascii_mode = false
        },
        {
            current_schema = "wanxiang_pro",
            input_text = "",
            candidates = {},
            is_composing = false,
            ascii_mode = false
        }
    }
    
    local state_index = 1
    local last_update = os.time()
    
    print("服务器运行中... 按 Ctrl+C 停止")
    print("可以访问以下API:")
    print("  GET http://localhost:8080/api/status")
    print("  GET http://localhost:8080/api/schema")
    print("  GET http://localhost:8080/api/candidates")
    print()
    
    -- 主循环
    while true do
        -- 处理TCP请求（非阻塞）
        RimeTcpServer.process()
        
        -- 每3秒更新一次状态（模拟输入法状态变化）
        if os.time() - last_update >= 3 then
            RimeTcpServer.update_state(test_states[state_index])
            print("状态更新:", test_states[state_index].input_text)
            
            state_index = state_index + 1
            if state_index > #test_states then
                state_index = 1
            end
            last_update = os.time()
        end
        
        -- 短暂休眠，避免CPU占用过高
        os.execute("sleep 0.01")
    end
else
    print("服务器启动失败!")
end
