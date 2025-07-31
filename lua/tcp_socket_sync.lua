--[[
双端口TCP套接字实时状态同步系统
使用双端口TCP套接字实现不同类型的双向通信：
1. Rime状态交互服务（端口10086）- 快速状态响应，0.1秒超时
2. AI翻译服务（端口10087）- 智能拼音转中文，5秒超时
--]] -- 添加 ARM64 Homebrew 的 Lua 路径和项目lua目录
local function setup_lua_paths()
    -- 添加 ARM64 Homebrew 路径
    package.path = package.path .. ";/opt/homebrew/share/lua/5.4/?.lua;/opt/homebrew/share/lua/5.4/?/init.lua"
    package.cpath = package.cpath .. ";/opt/homebrew/lib/lua/5.4/?.so;/opt/homebrew/lib/lua/5.4/?/core.so"

    -- 添加项目lua目录到搜索路径（使用绝对路径）
    package.path = package.path ..
                       ";/Users/yangxinyi/Library/Rime/lua/?.lua;/Users/yangxinyi/Library/Rime/lua/?/init.lua"
end

setup_lua_paths()

local logger_module = require("logger")
local json = require("json") -- 项目中的json模块

-- 创建当前模块的日志记录器
local logger = logger_module.create("tcp_socket_sync", {
    enabled = false,
    unique_file_log = false, -- 启用日志以便测试
    log_level = "DEBUG"
    -- console_output = true -- 为特定实例启用控制台输出
})

local socket_ok, socket = pcall(require, "socket") -- TCP套接字通信
if not socket_ok then
    logger.error("无法加载 socket 模块")
end

local M = {}

-- 获取当前时间戳（毫秒）
local function get_current_time_ms()
    return os.time() * 1000 + math.floor((os.clock() % 1) * 1000)
end

-- 双端口TCP套接字系统
local socket_system = {
    -- rime环境变量
    env = nil,
    engine = nil,
    context = nil,

    -- 服务器配置
    host = "127.0.0.1",

    -- Rime状态服务（快速响应）
    rime_state = {
        port = 10086,
        client = nil,
        is_connected = false,
        last_connect_attempt = 0,
        connect_retry_interval = 5000, -- 5秒重连间隔
        connection_failures = 0,
        max_connection_failures = 3,
        write_failure_count = 0,
        max_failure_count = 3,
        timeout = 0.01 -- 快速响应超时时间
    },

    -- AI翻译服务（长时间等待）
    ai_translate = {
        port = 10087,
        client = nil,
        is_connected = false,
        last_connect_attempt = 0,
        connect_retry_interval = 5000, -- 5秒重连间隔
        connection_failures = 0,
        max_connection_failures = 3,
        write_failure_count = 0,
        max_failure_count = 3,
        timeout = 5.0 -- AI翻译超时时间
    },

    -- 系统状态
    is_initialized = false
}

-- 连接到Rime状态服务端（快速响应）
function M.connect_to_rime_server()
    local current_time = get_current_time_ms()
    local rime_state = socket_system.rime_state

    -- 如果已连接，先检测连接是否真的可用
    if rime_state.client and rime_state.is_connected then
        -- 使用我们的连接检测函数来验证
        if M.check_rime_connection() then
            logger.debug("Rime状态服务连接检测通过，无需重连")
            return true
        else
            logger.debug("Rime状态服务连接检测失败，需要重连")
            -- 连接已断开，先断开再重连
            M.disconnect_from_rime_server()
        end
    end

    -- 检查重连间隔（仅在需要新连接时检查）
    if (current_time - rime_state.last_connect_attempt) < rime_state.connect_retry_interval then
        logger.debug("Rime状态服务重连间隔未到，跳过连接尝试")
        return false
    end

    rime_state.last_connect_attempt = current_time

    -- 确保之前的连接已经完全断开
    if rime_state.client then
        logger.debug("发现残留的Rime客户端连接，强制关闭")
        M.disconnect_from_rime_server()
    end

    -- 尝试新连接
    logger.debug("尝试连接到Rime状态服务端: " .. socket_system.host .. ":" .. rime_state.port)

    local client, err = socket.connect(socket_system.host, rime_state.port)
    if client then
        rime_state.client = client
        rime_state.is_connected = true
        rime_state.connection_failures = 0

        -- 设置快速响应超时
        client:settimeout(rime_state.timeout)

        logger.debug("Rime状态服务连接建立成功")
        return true
    else
        rime_state.connection_failures = rime_state.connection_failures + 1
        logger.warn("Rime状态服务连接失败: " .. tostring(err) .. " (失败次数: " ..
                        rime_state.connection_failures .. ")")
        return false
    end
end

-- 连接到AI翻译服务端（长时间等待）
function M.connect_to_ai_server()
    local current_time = get_current_time_ms()
    local ai_translate = socket_system.ai_translate

    -- 如果已连接，先检测连接是否真的可用
    if ai_translate.client and ai_translate.is_connected then
        -- 使用我们的连接检测函数来验证
        if M.check_ai_connection() then
            logger.debug("AI翻译服务连接检测通过，无需重连")
            return true
        else
            logger.debug("AI翻译服务连接检测失败，需要重连")
            -- 连接已断开，先断开再重连
            M.disconnect_from_ai_server()
        end
    end

    -- 检查重连间隔（仅在需要新连接时检查）
    if (current_time - ai_translate.last_connect_attempt) < ai_translate.connect_retry_interval then
        logger.debug("AI翻译服务重连间隔未到，跳过连接尝试")
        return false
    end

    ai_translate.last_connect_attempt = current_time

    -- 确保之前的连接已经完全断开
    if ai_translate.client then
        logger.debug("发现残留的AI客户端连接，强制关闭")
        M.disconnect_from_ai_server()
    end

    -- 尝试新连接
    logger.debug("尝试连接到AI翻译服务端: " .. socket_system.host .. ":" .. ai_translate.port)

    local client, err = socket.connect(socket_system.host, ai_translate.port)
    if client then
        ai_translate.client = client
        ai_translate.is_connected = true
        ai_translate.connection_failures = 0

        -- 设置AI翻译超时
        client:settimeout(ai_translate.timeout)

        logger.debug("AI翻译服务连接建立成功")
        return true
    else
        ai_translate.connection_failures = ai_translate.connection_failures + 1
        logger.warn("AI翻译服务连接失败: " .. tostring(err) .. " (失败次数: " ..
                        ai_translate.connection_failures .. ")")
        return false
    end
end

-- 断开Rime状态服务连接
function M.disconnect_from_rime_server()
    local rime_state = socket_system.rime_state
    if rime_state.client then
        pcall(function()
            rime_state.client:close()
        end)
        rime_state.client = nil
    end
    rime_state.is_connected = false
    logger.debug("Rime状态服务连接已断开")
end

-- 断开AI翻译服务连接
function M.disconnect_from_ai_server()
    local ai_translate = socket_system.ai_translate
    if ai_translate.client then
        pcall(function()
            ai_translate.client:close()
        end)
        ai_translate.client = nil
    end
    ai_translate.is_connected = false
    logger.debug("AI翻译服务连接已断开")
end

-- 断开与所有服务端的连接
function M.disconnect_from_server()
    M.disconnect_from_rime_server()
    M.disconnect_from_ai_server()
    logger.debug("所有TCP连接已断开")
end

-- 检测AI翻译服务连接状态
function M.check_ai_connection()
    local ai_translate = socket_system.ai_translate
    if not ai_translate.client or not ai_translate.is_connected then
        logger.debug("AI翻译服务未连接")
        return false
    end

    -- 使用非阻塞读取来检测连接状态
    local original_timeout = ai_translate.client:gettimeout()
    ai_translate.client:settimeout(0.001) -- 1毫秒超时，快速检测
    
    local test_data, test_err = ai_translate.client:receive("*l")
    
    -- 恢复原始超时设置
    ai_translate.client:settimeout(original_timeout)
    
    logger.debug("AI连接检测 test_data = " .. tostring(test_data) .. ", test_err = " .. tostring(test_err))
    
    if test_err == "closed" then
        logger.warn("检测到AI翻译服务连接已断开")
        M.disconnect_from_ai_server()
        return false
    elseif test_err == "timeout" then
        -- 超时是正常的，说明连接正常但没有数据
        logger.debug("AI连接检测正常（超时）")
        return true
    else
        -- 其他错误
        if test_err then
            logger.warn("AI连接检测出现错误: " .. tostring(test_err))
            return false
        else
            -- test_data有内容，连接正常
            logger.debug("AI连接检测正常（有数据）")
            return true
        end
    end
end

-- 检测Rime状态服务连接状态
function M.check_rime_connection()
    local rime_state = socket_system.rime_state
    if not rime_state.client or not rime_state.is_connected then
        logger.debug("Rime状态服务未连接")
        return false
    end

    -- 使用非阻塞读取来检测连接状态
    local original_timeout = rime_state.client:gettimeout()
    rime_state.client:settimeout(0.001) -- 1毫秒超时，快速检测
    
    local test_data, test_err = rime_state.client:receive("*l")
    
    -- 恢复原始超时设置
    rime_state.client:settimeout(original_timeout)
    
    logger.debug("Rime连接检测 test_data = " .. tostring(test_data) .. ", test_err = " .. tostring(test_err))
    
    if test_err == "closed" then
        logger.warn("检测到Rime状态服务连接已断开")
        M.disconnect_from_rime_server()
        return false
    elseif test_err == "timeout" then
        -- 超时是正常的，说明连接正常但没有数据
        logger.debug("Rime连接检测正常（超时）")
        return true
    else
        -- 其他错误
        if test_err then
            logger.warn("Rime连接检测出现错误: " .. tostring(test_err))
            return false
        else
            -- test_data有内容，连接正常
            logger.debug("Rime连接检测正常（有数据）")
            return true
        end
    end
end

-- 写入Rime状态服务TCP套接字
function M.write_to_rime_socket(data)
    if not socket_system.is_initialized then
        return false
    end

    local rime_state = socket_system.rime_state
    
    -- 首先检查连接状态
    if not rime_state.client or not rime_state.is_connected then
        logger.debug("Rime状态服务未连接，尝试连接...")
        if not M.connect_to_rime_server() then
            logger.warn("Rime状态服务连接不可用")
            return false
        end
    end
    
    -- 在发送数据前，先检测连接是否真的可用
    if not M.check_rime_connection() then
        logger.warn("Rime连接检测失败，尝试重新连接...")
        -- 尝试重新连接
        if not M.connect_to_rime_server() then
            logger.error("Rime状态服务重连失败，放弃数据发送")
            return false
        end
        
        -- 重连后再次检测
        if not M.check_rime_connection() then
            logger.error("Rime状态服务重连后连接检测仍然失败，放弃数据发送")
            return false
        end
    end

    local success, err = pcall(function()
        -- 发送JSON数据，以换行符结尾
        rime_state.client:send(data .. "\n")
    end)

    if success then
        logger.debug("write_to_rime_socket消息发送成功")
        rime_state.write_failure_count = 0
        return true
    else
        -- send()调用失败，说明连接确实有问题
        rime_state.write_failure_count = rime_state.write_failure_count + 1
        logger.error("Rime状态服务TCP写入失败: " .. tostring(err) .. " (失败次数: " ..
                         rime_state.write_failure_count .. ")")

        -- 连接已断开，立即断开
        M.disconnect_from_rime_server()
        return false
    end
end

-- 写入AI翻译服务TCP套接字
function M.write_to_ai_socket(data)
    if not socket_system.is_initialized then
        return false
    end

    local ai_translate = socket_system.ai_translate
    
    -- 首先检查连接状态
    if not ai_translate.client or not ai_translate.is_connected then
        logger.debug("AI翻译服务未连接，尝试连接...")
        if not M.connect_to_ai_server() then
            logger.warn("AI翻译服务连接不可用")
            return false
        end
    end
    
    -- 在发送数据前，先检测连接是否真的可用
    if not M.check_ai_connection() then
        logger.warn("AI连接检测失败，尝试重新连接...")
        -- 尝试重新连接
        if not M.connect_to_ai_server() then
            logger.error("AI翻译服务重连失败，放弃数据发送")
            return false
        end
        
        -- 重连后再次检测
        if not M.check_ai_connection() then
            logger.error("AI翻译服务重连后连接检测仍然失败，放弃数据发送")
            return false
        end
    end

    local success, err = pcall(function()
        -- 发送JSON数据，以换行符结尾
        logger.debug("将要发送给客户端的ai接口json:  " .. tostring(data))
        ai_translate.client:send(data .. "\n")
    end)

    if success then
        logger.debug("ai接口数据发送成功")
        ai_translate.write_failure_count = 0
        return true
    else
        -- send()调用失败，说明连接确实有问题
        ai_translate.write_failure_count = ai_translate.write_failure_count + 1
        logger.error("AI翻译服务TCP写入失败: " .. tostring(err) .. " (失败次数: " ..
                         ai_translate.write_failure_count .. ")")

        -- 连接已断开，立即断开
        M.disconnect_from_ai_server()
        return false
    end
end

-- 非阻塞读取Rime状态服务TCP套接字数据
function M.read_from_rime_socket()
    local rime_state = socket_system.rime_state
    if not rime_state.client or not rime_state.is_connected then
        logger.debug("Rime状态服务未连接，尝试重新连接...")
        if not M.connect_to_rime_server() then
            logger.warn("Rime状态服务重连失败")
            return nil
        end
        logger.debug("Rime状态服务重连成功，继续读取数据")
    end

    local line, err = rime_state.client:receive("*l")

    if line then
        logger.debug("📥 从Rime状态服务读取到原始数据: " .. line)
        return line
    elseif err == "timeout" then
        -- 超时表示当前无数据可读，这是正常情况
        return nil
    else
        -- 其他错误，可能是连接断开
        logger.warn("Rime socket服务没有读取到数据: " .. tostring(err))
        -- M.disconnect_from_rime_server()
        return nil
    end
end

-- 带超时读取AI翻译服务TCP套接字数据（按行读取，支持自定义超时）
function M.read_from_ai_socket(timeout_seconds)
    local ai_translate = socket_system.ai_translate
    if not ai_translate.client or not ai_translate.is_connected then
        logger.debug("AI翻译服务未连接，尝试重新连接...")
        if not M.connect_to_ai_server() then
            logger.warn("AI翻译服务重连失败")
            return nil
        end
        logger.debug("AI翻译服务重连成功，继续读取数据")
    end

    -- 设置自定义超时时间
    local original_timeout = ai_translate.timeout
    if timeout_seconds then
        ai_translate.client:settimeout(timeout_seconds)
        logger.debug("🕐 临时设置AI翻译服务按行读取超时时间为: " .. timeout_seconds .. "秒")
    end

    local line, err = ai_translate.client:receive("*l")

    -- 恢复原始超时设置
    if timeout_seconds and ai_translate.client then
        ai_translate.client:settimeout(original_timeout)
        logger.debug("🔄 恢复AI翻译服务原始超时时间: " .. original_timeout .. "秒")
    end

    if line then
        logger.debug("📥 从AI翻译服务读取到原始数据: " .. line)
        return line
    elseif err == "timeout" then
        -- 超时表示等待时间内无数据可读
        logger.warn("⏰ AI翻译服务等待超时 (" .. (timeout_seconds or ai_translate.timeout) .. "秒)")
        return nil
    else
        -- 其他错误，可能是连接断开
        logger.warn("AI翻译服务TCP读取错误: " .. tostring(err))
        M.disconnect_from_ai_server()
        return nil
    end
end

-- 读取AI翻译服务TCP套接字所有可用数据（支持自定义超时）
function M.read_all_from_ai_socket(timeout_seconds)
    local ai_translate = socket_system.ai_translate
    if not ai_translate.client or not ai_translate.is_connected then
        logger.debug("AI翻译服务未连接，尝试重新连接...")
        if not M.connect_to_ai_server() then
            logger.warn("AI翻译服务重连失败")
            return nil
        end
        logger.debug("AI翻译服务重连成功，继续读取数据")
    end

    -- 设置自定义超时时间
    local original_timeout = ai_translate.timeout
    if timeout_seconds then
        ai_translate.client:settimeout(timeout_seconds)
        logger.debug("🕐 临时设置AI翻译服务超时时间为: " .. timeout_seconds .. "秒")
    end

    local all_data = ""
    local chunk_size = 8192 -- 每次读取8KB
    local start_time = get_current_time_ms()
    local timeout_ms = (timeout_seconds or ai_translate.timeout) * 1000
    
    while true do
        -- 检查总体超时时间
        local current_time = get_current_time_ms()
        if (current_time - start_time) > timeout_ms then
            logger.warn("🕐 AI翻译服务批量读取总体超时 (" .. (timeout_seconds or ai_translate.timeout) .. "秒)")
            break
        end
        
        local chunk, err = ai_translate.client:receive(chunk_size)
        
        if chunk then
            all_data = all_data .. chunk
            logger.debug("📥 从AI翻译服务读取到数据块: " .. string.len(chunk) .. " 字节")
            
            -- 如果读取的数据少于chunk_size，说明没有更多数据了
            if string.len(chunk) < chunk_size then
                break
            end
        elseif err == "timeout" then
            -- 超时表示没有更多数据可读
            if string.len(all_data) > 0 then
                logger.debug("📥 AI翻译服务读取完成，总共读取: " .. string.len(all_data) .. " 字节")
            else
                logger.warn("⏰ AI翻译服务等待超时，无数据可读 (" .. (timeout_seconds or ai_translate.timeout) .. "秒)")
            end
            break
        else
            -- 其他错误，可能是连接断开
            logger.warn("AI翻译服务TCP批量读取错误: " .. tostring(err))
            if string.len(all_data) == 0 then
                M.disconnect_from_ai_server()
                -- 恢复原始超时设置
                if timeout_seconds and ai_translate.client then
                    ai_translate.client:settimeout(original_timeout)
                end
                return nil
            end
            break
        end
    end
    
    -- 恢复原始超时设置
    if timeout_seconds and ai_translate.client then
        ai_translate.client:settimeout(original_timeout)
        logger.debug("🔄 恢复AI翻译服务原始超时时间: " .. original_timeout .. "秒")
    end
    
    if string.len(all_data) > 0 then
        logger.debug("📥 从AI翻译服务读取到完整数据: " .. all_data)
        return all_data
    else
        return nil
    end
end

-- 快速清理AI翻译服务TCP套接字积压数据
function M.flush_ai_socket_buffer()
    local ai_translate = socket_system.ai_translate
    if not ai_translate.client or not ai_translate.is_connected then
        logger.debug("AI翻译服务未连接，尝试重新连接...")
        if not M.connect_to_ai_server() then
            logger.warn("AI翻译服务重连失败，无法清理缓冲区")
            return 0
        end
        logger.debug("AI翻译服务重连成功，继续清理缓冲区")
    end

    -- 临时设置为非阻塞模式（0秒超时）
    local original_timeout = ai_translate.timeout
    ai_translate.client:settimeout(0)
    
    local total_flushed = 0
    local chunk_size = 8192
    
    -- 快速读取并丢弃所有积压数据
    while true do
        local chunk, err = ai_translate.client:receive(chunk_size)
        
        if chunk then
            total_flushed = total_flushed + string.len(chunk)
            -- 如果读取的数据少于chunk_size，说明没有更多数据了
            if string.len(chunk) < chunk_size then
                break
            end
        else
            -- 没有更多数据或出错，退出循环
            break
        end
    end
    
    -- 恢复原始超时设置
    ai_translate.client:settimeout(original_timeout)
    
    if total_flushed > 0 then
        logger.debug("🗑️ 快速清理AI套接字积压数据: " .. total_flushed .. " 字节")
    end
    
    return total_flushed
end

-- 读取AI翻译服务最新消息（丢弃旧消息，只返回最后一条）- 优化版本
-- 返回值格式: {data = parsed_data or nil, status = "success"|"timeout"|"no_data"|"error", raw_message = string or nil}
function M.read_latest_from_ai_socket(timeout_seconds)
    local ai_translate = socket_system.ai_translate
    if not ai_translate.client or not ai_translate.is_connected then
        logger.debug("AI翻译服务未连接，尝试重新连接...")
        if not M.connect_to_ai_server() then
            logger.warn("AI翻译服务重连失败")
            return {data = nil, status = "error", raw_message = nil, error_msg = "服务未连接且重连失败"}
        end
        logger.debug("AI翻译服务重连成功，继续读取数据")
    end

    -- 设置自定义超时时间
    local original_timeout = ai_translate.timeout
    local effective_timeout = timeout_seconds or 0.1 -- 默认100ms超时
    
    ai_translate.client:settimeout(effective_timeout)
    logger.debug("🕐 设置AI翻译服务读取超时时间为: " .. effective_timeout .. "秒")

    -- 使用循环按行读取数据，保留最后一行
    local latest_line = nil
    local total_lines = 0
    local max_attempts = 50 -- 最多尝试50次读取，防止无限循环
    
    for attempt = 1, max_attempts do
        local line, err = ai_translate.client:receive("*l")
        
        if line then
            latest_line = line  -- 保存最新的一行
            total_lines = total_lines + 1
            logger.debug("📥 读取到消息行 #" .. total_lines .. " (长度:" .. string.len(line) .. "): " .. 
                        string.sub(line, 1, 100) .. (string.len(line) > 100 and "..." or ""))
        elseif err == "timeout" then
            -- 超时表示没有更多数据，退出循环
            logger.debug("⏰ 第 " .. attempt .. " 次读取超时，停止读取")
            break
        else
            -- 其他错误
            logger.warn("AI翻译服务TCP读取错误: " .. tostring(err))
            -- 恢复原始超时设置
            ai_translate.client:settimeout(original_timeout)
            M.disconnect_from_ai_server()
            return {data = nil, status = "error", raw_message = nil, error_msg = tostring(err)}
        end
    end
    
    -- 恢复原始超时设置
    ai_translate.client:settimeout(original_timeout)
    logger.debug("🔄 恢复AI翻译服务原始超时时间: " .. original_timeout .. "秒")
    
    if latest_line then
        if total_lines > 1 then
            logger.debug("🎯 共读取了 " .. total_lines .. " 条消息，丢弃了 " .. 
                       (total_lines - 1) .. " 条旧消息，保留最后一条")
        else
            logger.debug("📥 从AI翻译服务读取到1条最新消息")
        end
        
        logger.debug("🎯 返回最新消息: " .. latest_line)
        
        -- 尝试解析JSON数据
        local parsed_data = M.parse_socket_data(latest_line)
        return {
            data = parsed_data, 
            status = "success", 
            raw_message = latest_line
        }
    else
        -- 没有读取到任何消息
        logger.debug("📭 没有收到有效消息，共尝试了 " .. max_attempts .. " 次读取")
        return {data = nil, status = "timeout", raw_message = nil}
    end
end

-- 解析从Python端接收的数据
function M.parse_socket_data(data)
    if not data or #data == 0 then
        return nil
    end

    logger.debug("🔍 解析socket数据data: " .. tostring(data) .. " (类型: " .. type(data) .. ")")

    local success, parsed_data = pcall(json.decode, data)

    if success and parsed_data then
        logger.debug("🔍 解析TCP数据成功: " .. tostring(parsed_data))
        return parsed_data
    else
        logger.error("❌ 解析TCP数据失败: " .. tostring(data))
        return nil
    end
end

-- 处理从Python端接收的命令
function M.handle_socket_command(command_messege, context)

    --[[ 接收到消息格式: 
    {"messege_type": "command_response", "response": "rime_state_received", "timestamp": 1753022593756, "client_id": "rime-127.0.0.1:57187", "command_messege": [{"command": "set_option", "command_type": "option", "option_name": "full_shape", "option_value": true, "timestamp": 1753022590433}]}
    
    注意：外层的 command_messege 是一个数组，但此函数处理的是数组中的单个命令对象
    ]]

    -- 🎯 处理TCP命令: set_option option_name: super_tips
    logger.debug("🎯 处理TCP命令: " .. command_messege.command .. " option_name: " ..
                     (command_messege.option_name or "N/A"))

    local command = command_messege.command
    if command == "ping" then
        -- 响应ping命令
        logger.debug("📞 收到ping命令")
        M.write_to_rime_socket('{"response": "pong"}')
        return true
    elseif command == "set_option" then
        -- 修改设置
        logger.debug("command_messege.option_value: " .. tostring(command_messege.option_value))
        if context then
            if context:get_option(command_messege.option_name) ~= command_messege.option_value then
                context:set_option(command_messege.option_name, command_messege.option_value)
                logger.debug("已设置选项: " .. tostring(command_messege.option_name) .. " = " ..
                                 tostring(command_messege.option_value))
            end
            local response = {
                response = "option_set",
                option_name = command_messege.option_name,
                success = true,
                timestamp = get_current_time_ms(),
                responding_to = "set_option"
            }
            M.write_to_rime_socket(json.encode(response))
        else
            logger.warn("context为nil，无法设置选项: " .. tostring(command_messege.option_name))
            local response = {
                response = "option_set",
                option_name = command_messege.option_name,
                success = false,
                error = "context is nil",
                timestamp = get_current_time_ms(),
                responding_to = "set_option"
            }
            M.write_to_rime_socket(json.encode(response))
        end
        return true

    elseif command == "server_ping" then
        -- 响应服务端ping命令
        logger.debug("📞 收到服务端ping命令")
        local response = {
            response = "pong",
            client_id = "lua_tcp_client",
            timestamp = get_current_time_ms(),
            responding_to = "server_ping"
        }
        M.write_to_rime_socket(json.encode(response))
        return true
    elseif command == "server_broadcast" then
        -- 处理服务端广播消息
        local message = command_messege.message or "无消息内容"
        local broadcast_id = command_messege.broadcast_id or "unknown"
        local timestamp = command_messege.timestamp or "unknown"
        logger.debug("📢 收到服务端广播消息:")
        logger.debug("   📝 内容: " .. message)
        logger.debug("   🆔 广播ID: " .. tostring(broadcast_id))
        logger.debug("   ⏰ 时间戳: " .. tostring(timestamp))

        local response = {
            response = "broadcast_received",
            client_id = "lua_tcp_client",
            broadcast_id = broadcast_id,
            timestamp = get_current_time_ms(),
            responding_to = "server_broadcast"
        }
        M.write_to_rime_socket(json.encode(response))
        return true
    elseif command == "get_status" then
        -- 返回当前状态
        logger.debug("📊 收到状态查询命令")
        local stats = M.get_stats()
        local response = {
            response = "status",
            data = stats
        }
        M.write_to_rime_socket(json.encode(response))
        return true
    elseif command == "paste_executed" then
        -- 粘贴命令执行成功响应
        logger.info("✅ 服务端已成功执行粘贴操作")
        return true
    elseif command == "paste_failed" then
        -- 粘贴命令执行失败响应
        local error_msg = command_messege.error or "未知错误"
        logger.error("❌ 服务端执行粘贴操作失败: " .. tostring(error_msg))
        return true
    else
        logger.warn("❓ 未知的TCP命令: " .. command)
        return false
    end
end

-- 定期处理Rime状态服务TCP套接字数据
function M.process_rime_socket_data(context)
    local data = M.read_from_rime_socket()
    if data then
        logger.debug("🎯 成功接收到Rime状态服务完整消息: " .. data)
        local parsed_data = M.parse_socket_data(data)
        if parsed_data then
            logger.debug("📨 Rime状态消息解析成功")
            if parsed_data.messege_type == "command_response" then
                logger.debug("📨 检测到嵌套命令 command_messege 字段.")
                -- command_messege 现在是一个数组，可能包含多条命令
                if parsed_data.command_messege then
                    if #parsed_data.command_messege > 0 then
                        -- 如果是数组，遍历处理每个命令
                        for i, command_item in ipairs(parsed_data.command_messege) do
                            logger.debug("📨 处理第 " .. i .. " 条命令: " .. tostring(command_item.command))
                            M.handle_socket_command(command_item, context)
                        end
                    else
                        -- 如果是单个命令对象（向后兼容）
                        M.handle_socket_command(parsed_data.command_messege, context)
                    end
                end
            elseif parsed_data.messege_type == "command_executed" then
                -- 命令执行成功的通知消息
                logger.info("✅ 收到命令执行成功通知: paste_executed")
                logger.debug("命令执行成功响应内容: " .. data)
            end
            return true -- 返回成功标志
        else
            logger.warn("⚠️  Rime状态消息解析失败")
            return false
        end
    else
        return false -- 没有接收到数据
    end
end

-- 带超时的处理AI翻译服务TCP套接字数据（用于大模型等长时间等待的场景）
function M.process_ai_socket_data_with_timeout(timeout_seconds)
    local ai_translate = socket_system.ai_translate
    if not ai_translate.client or not ai_translate.is_connected then
        logger.debug("AI翻译服务未连接，尝试重新连接...")
        if not M.connect_to_ai_server() then
            logger.warn("AI翻译服务重连失败，无法等待数据")
            return nil
        end
        logger.debug("AI翻译服务重连成功，继续等待数据")
    end

    local line = M.read_from_ai_socket(timeout_seconds)

    if line then
        logger.debug("📥 收到AI翻译服务回复数据: " .. line)
        local parsed_data = M.parse_socket_data(line)
        if parsed_data then
            logger.debug("📨 AI翻译数据解析成功")
            if parsed_data.messege_type == "translate_result" then
                for k, v in pairs(parsed_data) do
                    logger.debug("parsed_data[" .. tostring(k) .. "] = " .. tostring(v))
                end
                return parsed_data
            elseif parsed_data.messege_type == "chat_result" then
                logger.debug("📨 收到对话结果数据")
                for k, v in pairs(parsed_data) do
                    logger.debug("chat_result[" .. tostring(k) .. "] = " .. tostring(v))
                end
                return parsed_data
            elseif parsed_data.messege_type == "command_response" then
                logger.debug("📨 收到命令响应，但期望翻译结果")
                -- 处理可能的多条命令
                if parsed_data.command_messege and type(parsed_data.command_messege) == "table" then
                    if #parsed_data.command_messege > 0 then
                        -- 如果是数组，遍历处理每个命令
                        for i, command_item in ipairs(parsed_data.command_messege) do
                            logger.debug("📨 AI服务处理第 " .. i .. " 条命令: " ..
                                             tostring(command_item.command))
                            M.handle_socket_command(command_item)
                        end
                    else
                        -- 如果是单个命令对象（向后兼容）
                        M.handle_socket_command(parsed_data.command_messege)
                    end
                end
                return nil -- 收到的不是翻译结果
            end
        end
    end

    return nil
end

-- 和Rime状态服务进行数据交换
function M.sync_with_server(context, option_info)
    local success, error_msg = pcall(function()
        local current_time = get_current_time_ms()

        -- local context =  env.engine.context
        -- 构建基础状态数据
        local state_data = {
            messege_type = "state",
            is_composing = context:is_composing(),
            timestamp = current_time,
            switches_option = {} -- 初始化为空表
        }

        if option_info then
            -- 构建完整的带有option当前配置的状态数据
            -- 简单开关列表（name类型）
            local simple_switches = {"ascii_punct", "full_shape", "tone_display", "prediction", "s2s", "s2t", "s2hk",
                                     "s2tw"}
            -- 收集简单开关状态
            for _, switch_name in ipairs(simple_switches) do
                local switch_state = context:get_option(switch_name)
                table.insert(state_data.switches_option, {
                    name = switch_name,
                    type = "simple",
                    state = switch_state,
                    state_index = switch_state and 1 or 0
                })
            end

        end

        logger.debug("state_data: " .. tostring(state_data))

        -- 序列化状态数据
        local json_data = json.encode(state_data)

        -- 写入Rime状态服务TCP套接字
        M.write_to_rime_socket(json_data)

        -- 处理来自Rime状态服务端的数据
        if socket_system.is_initialized and socket_system.rime_state.is_connected then
            M.process_rime_socket_data(context)
        end
    end)

    if not success then
        logger.error("状态更新失败: " .. tostring(error_msg))
        return false
    end

    return true
end

-- 统计信息
function M.get_stats()
    local stats = {
        is_initialized = socket_system.is_initialized,
        host = socket_system.host,

        -- Rime状态服务统计
        rime_state = {
            port = socket_system.rime_state.port,
            is_connected = socket_system.rime_state.is_connected,
            connection_failures = socket_system.rime_state.connection_failures,
            write_failure_count = socket_system.rime_state.write_failure_count,
            timeout = socket_system.rime_state.timeout
        },

        -- AI翻译服务统计
        ai_translate = {
            port = socket_system.ai_translate.port,
            is_connected = socket_system.ai_translate.is_connected,
            connection_failures = socket_system.ai_translate.connection_failures,
            write_failure_count = socket_system.ai_translate.write_failure_count,
            timeout = socket_system.ai_translate.timeout
        }
    }

    return stats
end

-- 公开接口：手动处理Rime状态服务TCP套接字数据
function M.manual_process_rime_socket_data()
    return M.process_rime_socket_data()
end

-- 公开接口：获取连接信息
function M.get_connection_info()
    return {
        host = socket_system.host,
        rime_state = {
            port = socket_system.rime_state.port,
            is_connected = socket_system.rime_state.is_connected
        },
        ai_translate = {
            port = socket_system.ai_translate.port,
            is_connected = socket_system.ai_translate.is_connected
        }
    }
end

-- 公开接口：检查双端口系统是否就绪（任一服务可用即为就绪）
function M.is_system_ready()
    return socket_system.is_initialized and
               (socket_system.rime_state.is_connected or socket_system.ai_translate.is_connected)
end

-- 公开接口：检查Rime状态服务连接状态
function M.is_rime_socket_ready()
    return socket_system.is_initialized and socket_system.rime_state.is_connected
end

-- 公开接口：检查AI翻译服务连接状态
function M.is_ai_socket_ready()
    return socket_system.is_initialized and socket_system.ai_translate.is_connected
end

-- 公开接口：强制重置连接状态（用于服务端重启后立即重连）
function M.force_reconnect()
    logger.info("强制重置所有TCP连接状态")
    
    -- 重置连接状态和重连计时器
    socket_system.rime_state.last_connect_attempt = 0
    socket_system.ai_translate.last_connect_attempt = 0
    socket_system.rime_state.connection_failures = 0
    socket_system.ai_translate.connection_failures = 0
    socket_system.rime_state.write_failure_count = 0
    socket_system.ai_translate.write_failure_count = 0
    
    -- 断开现有连接
    M.disconnect_from_server()
    
    -- 尝试重新连接
    local rime_connected = M.connect_to_rime_server()
    local ai_connected = M.connect_to_ai_server()
    
    logger.info("强制重连结果 - Rime:" .. tostring(rime_connected) .. " AI:" .. tostring(ai_connected))
    
    return rime_connected or ai_connected
end

-- 公开接口：设置连接参数
function M.set_connection_params(host, rime_port, ai_port)
    if host then
        socket_system.host = host
    end
    if rime_port then
        socket_system.rime_state.port = rime_port
    end
    if ai_port then
        socket_system.ai_translate.port = ai_port
    end
    logger.debug(
        "连接参数已更新: " .. socket_system.host .. " Rime:" .. socket_system.rime_state.port .. " AI:" ..
            socket_system.ai_translate.port)
end

-- 公开接口：翻译拼音字符串（支持自定义超时）
function M.translate(schema_name, shuru_schema, confirmed_pos_input, long_candidates_table, timeout_seconds)
    local timeout = timeout_seconds or socket_system.ai_translate.timeout -- 默认使用AI服务超时时间
    local parsed_data = nil

    local success, error_msg = pcall(function()
        local current_time = get_current_time_ms()

        -- 构建要翻译的拼音字符串
        local translate_data = {
            messege_type = "translate",
            confirmed_pos_input = confirmed_pos_input,
            schema_name = schema_name,
            shuru_schema = shuru_schema,
            timestamp = current_time,
            timeout = timeout -- 告知服务端预期的超时时间
        }

        -- 提取long_candidates_table中每个元素的text属性，组成数组
        if long_candidates_table then
            translate_data.candidates_text = {}
            for _, candidate in ipairs(long_candidates_table) do
                table.insert(translate_data.candidates_text, candidate.text)
            end
        end

        -- 序列化状态数据
        
        local json_data = json.encode(translate_data)
        logger.debug("json_data: " .. tostring(json_data))

        if json_data then
            -- 写入AI翻译服务TCP套接字
            M.write_to_ai_socket(json_data)

            -- 处理来自AI翻译服务端的数据
            if socket_system.is_initialized and socket_system.ai_translate.is_connected then
                parsed_data = M.process_ai_socket_data_with_timeout()
                logger.debug("parsed_data: " .. tostring(parsed_data))
            end
        else
            logger.debug("translate_data序列化失败,请排查错误: " .. tostring(translate_data))
        end

    end)

    if not success then
        logger.error("带超时翻译处理失败: " .. tostring(error_msg))
        return nil
    end

    return parsed_data
end

-- 公开接口：发送粘贴命令到服务端（跨平台通用）
function M.send_paste_command()
    local success, error_msg = pcall(function()
        local current_time = get_current_time_ms()

        -- 构建粘贴命令数据
        local paste_command = {
            messege_type = "command",  -- 使用state类型以兼容现有处理逻辑
            command = "paste",       -- 粘贴命令
            timestamp = current_time,
            client_id = "lua_tcp_client"
        }

        -- 序列化命令数据
        local json_data = json.encode(paste_command)
        logger.debug("发送粘贴命令json_data: " .. tostring(json_data))

        if json_data then
            -- 写入Rime状态服务TCP套接字
            local send_success = M.write_to_rime_socket(json_data)
            if send_success then
                logger.info("🍴 粘贴命令发送成功，等待服务端执行")
                
                -- 可选：等待服务端响应
                local response = M.process_rime_socket_data()
                if response then
                    logger.info("📥 收到粘贴命令执行响应")
                    return true
                else
                    logger.warn("⚠️ 未收到粘贴命令执行响应")
                    return true -- 命令已发送，视为成功
                end
            else
                logger.error("❌ 粘贴命令发送失败")
                return false
            end
        else
            logger.error("粘贴命令序列化失败: " .. tostring(paste_command))
            return false
        end
    end)

    if not success then
        logger.error("发送粘贴命令失败: " .. tostring(error_msg))
        return false
    end

    return true
end

-- 公开接口：发送对话消息到AI服务（仅发送）
function M.send_chat_message(commit_text, chat_type)
    local success, error_msg = pcall(function()
        local current_time = get_current_time_ms()

        -- 构建对话消息数据
        local chat_data = {
            messege_type = "chat",
            commit_text = commit_text, -- 对话内容
            chat_type = chat_type, -- AI对话类型
            timestamp = current_time
        }

        -- 序列化聊天数据
        local json_data = json.encode(chat_data)
        logger.debug("发送对话消息json_data: " .. tostring(json_data))

        if json_data then
            -- 写入AI翻译服务TCP套接字
            M.write_to_ai_socket(json_data)
            logger.debug("对话消息发送成功，类型: " .. tostring(chat_type))
        else
            logger.error("对话消息序列化失败: " .. tostring(chat_data))
            return false
        end
    end)

    if not success then
        logger.error("发送对话消息失败: " .. tostring(error_msg))
        return false
    end

    return true
end

-- 公开接口：接收AI对话流式回复数据（单次调用版本）
function M.receive_chat_stream_once(timeout_seconds)
    local timeout = timeout_seconds or 10 -- 默认10秒超时
    
    local success, result = pcall(function()
        logger.debug("单次获取AI对话回复数据...")
        
        -- 获取AI回复数据
        local ai_response = M.process_ai_socket_data_with_timeout(timeout_seconds)
        
        -- 构造统一的stream_data结构
        local stream_data = {
            content = "",
            timestamp = get_current_time_ms(),
            is_final = false
        }
        
        if ai_response and ai_response.messege_type == "chat_result" then
            logger.debug("收到流式对话数据: " .. tostring(ai_response.content or ""))
            
            -- 设置内容和状态
            stream_data.content = ai_response.content or ""
            stream_data.is_final = ai_response.is_final or ai_response.finished or false
            
            logger.debug("当前对话内容: " .. stream_data.content)
            logger.debug("is_final=" .. tostring(stream_data.is_final))
        elseif ai_response == nil then
            -- 没有收到数据，保持默认值
            logger.debug("没有收到AI数据")
        else
            -- 收到非对话结果数据，保持默认值
            if ai_response then
                logger.debug("收到非对话结果数据: " .. tostring(ai_response.messege_type))
            end
        end
        
        return stream_data
    end)

    if not success then
        logger.error("单次接收AI对话数据失败: " .. tostring(result))
        return {
            content = "",
            timestamp = get_current_time_ms(),
            is_final = false,
            error = result
        }
    end

    return result
end


-- 公开接口：发送对话消息并接收回复（组合功能，向后兼容）
function M.send_and_receive_chat(commit_text, context, chat_type, timeout_seconds)
    -- 发送消息
    local send_success = M.send_chat_message(commit_text, chat_type)
    if not send_success then
        return nil
    end
    
    -- 接收流式回复
    return M.receive_chat_stream(context, timeout_seconds)
end

-- 初始化系统
function M.init()
    logger.info("双端口TCP套接字状态同步系统初始化")

    -- 检查是否已经初始化
    logger.info("socket_system.is_initialized: " .. tostring(socket_system.is_initialized))
    if socket_system.is_initialized then
        return true
    end

    -- 尝试连接到Rime状态服务
    local rime_connected = M.connect_to_rime_server()
    -- 尝试连接到AI翻译服务
    local ai_connected = M.connect_to_ai_server()

    if rime_connected or ai_connected then
        socket_system.is_initialized = true
        logger.info("双端口TCP套接字系统初始化成功")
        if rime_connected then
            logger.info("Rime状态服务连接成功")
        end
        if ai_connected then
            logger.info("AI翻译服务连接成功")
        end
        logger.info("双端口TCP套接字系统初始化完成")
        return true
    end

    logger.info("双端口TCP套接字系统初始化失败，但系统仍可工作（离线模式）")
    socket_system.is_initialized = true -- 允许离线工作
    logger.info("双端口TCP套接字系统初始化完成")
    return true
end

-- 清理资源
function M.fini()
    logger.info("双端口TCP套接字系统清理")

    -- 断开所有TCP连接
    M.disconnect_from_server()

    logger.info("双端口TCP套接字系统清理完成")
end

return M
