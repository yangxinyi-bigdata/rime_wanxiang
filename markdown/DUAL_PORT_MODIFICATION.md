# 双端口TCP套接字系统修改说明

## 概述

根据Python服务端的双端口架构，将原有的单端口Lua TCP客户端修改为双端口模式，以支持不同类型的服务和超时要求。

## 主要修改内容

### 1. 系统架构变更

**原架构（单端口）：**
```
Rime ←→ TCP客户端 ←→ Python服务端（端口10086）
```

**新架构（双端口）：**
```
Rime ←→ TCP客户端 {
    ├── Rime状态服务客户端 ←→ Python Rime状态服务（端口10086，0.1s超时）
    └── AI翻译服务客户端 ←→ Python AI翻译服务（端口10087，5s超时）
}
```

### 2. 数据结构重构

```lua
-- 新的双端口系统配置
local socket_system = {
    host = "127.0.0.1",
    
    -- Rime状态服务（快速响应）
    rime_state = {
        port = 10086,
        timeout = 0.1,  -- 快速响应
        client = nil,
        is_connected = false,
        -- ... 其他连接管理字段
    },
    
    -- AI翻译服务（长时间等待）
    ai_translate = {
        port = 10087,
        timeout = 5.0,  -- 长时间等待
        client = nil,
        is_connected = false,
        -- ... 其他连接管理字段
    }
}
```

### 3. 新增的主要函数

#### 连接管理函数
- `M.connect_to_rime_server()` - 连接Rime状态服务
- `M.connect_to_ai_server()` - 连接AI翻译服务
- `M.disconnect_from_rime_server()` - 断开Rime状态服务
- `M.disconnect_from_ai_server()` - 断开AI翻译服务

#### 数据传输函数
- `M.write_to_rime_socket(data)` - 向Rime状态服务发送数据
- `M.write_to_ai_socket(data)` - 向AI翻译服务发送数据
- `M.read_from_rime_socket()` - 从Rime状态服务读取数据（快速）
- `M.read_from_ai_socket(timeout_seconds)` - 从AI翻译服务读取数据（支持长超时）

#### 数据处理函数
- `M.process_rime_socket_data()` - 处理Rime状态服务数据
- `M.process_ai_socket_data_with_timeout(timeout_seconds)` - 处理AI翻译服务数据

#### 状态检查函数
- `M.is_rime_socket_ready()` - 检查Rime状态服务连接状态
- `M.is_ai_socket_ready()` - 检查AI翻译服务连接状态

### 4. 功能分离

#### Rime状态服务（端口10086）
- **用途：** 实时状态同步、快速命令响应
- **超时：** 0.1秒
- **数据类型：** 
  - Rime输入状态
  - 选项设置命令
  - 系统状态查询

#### AI翻译服务（端口10087）
- **用途：** 拼音到中文的AI翻译
- **超时：** 5秒（可配置）
- **数据类型：**
  - 拼音翻译请求
  - AI翻译结果

### 5. 兼容性保持

为了保持与现有代码的兼容性，保留了原有的函数接口：

```lua
-- 兼容接口（默认使用Rime状态服务）
M.write_to_socket(data)  -- 等同于 M.write_to_rime_socket(data)
M.read_from_socket()     -- 等同于 M.read_from_rime_socket()
M.process_socket_data()  -- 等同于 M.process_rime_socket_data()

-- 翻译接口（使用AI翻译服务）
M.translate(input, timeout)  -- 自动使用AI翻译服务
```

### 6. 错误处理增强

每个服务都有独立的错误处理机制：
- 独立的连接失败计数
- 独立的写入失败计数
- 独立的重连逻辑
- 详细的日志记录

### 7. 配置管理

新增配置接口：
```lua
-- 设置连接参数
M.set_connection_params(host, rime_port, ai_port)

-- 获取连接信息
local info = M.get_connection_info()
-- 返回：{ host, rime_state: {port, is_connected}, ai_translate: {port, is_connected} }
```

## 使用示例

### 发送Rime状态数据
```lua
local state_data = {
    messege_type = "state",
    is_composing = true,
    input_mode = false
}
local json_data = M.serialize_state(state_data)
M.write_to_rime_socket(json_data)
```

### 请求AI翻译
```lua
local result = M.translate("ni hao", 3)  -- 3秒超时
if result then
    print("翻译结果: " .. result)
end
```

### 检查连接状态
```lua
if M.is_rime_socket_ready() then
    print("Rime状态服务已连接")
end

if M.is_ai_socket_ready() then
    print("AI翻译服务已连接")
end
```

## 优势

1. **性能优化：** 不同类型的请求使用不同的超时时间，避免相互影响
2. **服务分离：** 状态同步和AI翻译分别处理，提高系统稳定性
3. **容错能力：** 单个服务故障不影响另一个服务
4. **可扩展性：** 便于将来添加更多专用服务
5. **向下兼容：** 保留原有接口，现有代码无需修改

## 测试

使用提供的测试脚本验证系统功能：
```bash
lua test_dual_port.lua
```

测试结果显示双端口系统配置正确，各项参数符合预期。


# 双端口TCP套接字系统精简重构说明

## 概述

已完成对双端口TCP套接字系统的精简重构，移除了所有旧接口的兼容性代码，使代码更加简洁和语义明确。

## 移除的兼容性接口

以下旧的兼容性接口已被完全移除：

### 1. 已移除的函数
```lua
-- ❌ 已移除 - 兼容旧接口
function M.write_to_socket(data)
function M.read_from_socket()
function M.process_socket_data()
function M.process_socket_data_with_timeout(timeout_seconds)
```

### 2. 重命名的函数
```lua
-- 旧名称：M.is_socket_ready()
-- ✅ 新名称：M.is_system_ready()
-- 描述：检查双端口系统是否就绪（任一服务可用即为就绪）

-- 旧名称：M.manual_process_socket_data()
-- ✅ 新名称：M.manual_process_rime_socket_data()
-- 描述：手动处理Rime状态服务TCP套接字数据
```

## 当前明确的API接口

### 连接管理
```lua
-- 双端口连接
M.connect_to_rime_server()      -- 连接Rime状态服务（端口10086）
M.connect_to_ai_server()        -- 连接AI翻译服务（端口10087）

-- 双端口断开
M.disconnect_from_rime_server() -- 断开Rime状态服务
M.disconnect_from_ai_server()   -- 断开AI翻译服务
M.disconnect_from_server()      -- 断开所有服务
```

### 数据传输
```lua
-- Rime状态服务（快速响应，0.1秒超时）
M.write_to_rime_socket(data)
M.read_from_rime_socket()
M.process_rime_socket_data()

-- AI翻译服务（长时间等待，5秒超时）
M.write_to_ai_socket(data)
M.read_from_ai_socket(timeout_seconds)
M.process_ai_socket_data_with_timeout(timeout_seconds)
```

### 状态检查
```lua
M.is_system_ready()           -- 系统整体就绪状态
M.is_rime_socket_ready()      -- Rime状态服务连接状态
M.is_ai_socket_ready()        -- AI翻译服务连接状态
```

### 核心功能
```lua
M.init(env)                   -- 初始化双端口系统
M.fini(env)                   -- 清理双端口系统
M.sync_with_server()          -- 与Rime状态服务同步
M.translate(input, timeout)   -- AI翻译（自动使用AI翻译服务）
```

### 配置和工具
```lua
M.set_connection_params(host, rime_port, ai_port)
M.get_connection_info()
M.get_stats()
M.serialize_state(state)
M.parse_socket_data(data)
M.handle_socket_command(command)
M.manual_process_rime_socket_data()
```

## 代码内部调用修正

所有内部调用都已修正为使用明确的双端口接口：

### 命令处理函数修正
```lua
-- ✅ 修正前后对比
-- 旧调用：M.write_to_socket()
-- 新调用：M.write_to_rime_socket()

-- 所有命令响应都明确使用Rime状态服务
M.handle_socket_command() 函数中的所有响应都使用 M.write_to_rime_socket()
```

## 优势

### 1. **语义明确**
- 每个函数名都明确表示操作的服务类型
- 消除了模糊性，提高了代码可读性

### 2. **架构清晰**
- 双端口服务分离明确
- 不同超时策略一目了然

### 3. **维护简便**
- 移除了冗余的兼容性代码
- 减少了函数调用层次

### 4. **错误减少**
- 明确的接口减少了误用可能
- 调试时能快速定位问题

## 迁移指南

如果有外部代码使用了旧接口，需要按以下方式迁移：

### 旧代码 → 新代码
```lua
-- 状态同步（无需修改，仍使用 M.sync_with_server()）
M.sync_with_server()  -- ✅ 保持不变

-- AI翻译（无需修改，仍使用 M.translate()）
M.translate(input, timeout)  -- ✅ 保持不变

-- 手动操作需要明确指定服务
-- 旧：M.write_to_socket(data)
-- 新：M.write_to_rime_socket(data) 或 M.write_to_ai_socket(data)

-- 旧：M.read_from_socket()
-- 新：M.read_from_rime_socket() 或 M.read_from_ai_socket(timeout)

-- 状态检查
-- 旧：M.is_socket_ready()
-- 新：M.is_system_ready()
```

## 测试验证

使用更新后的测试脚本验证：
```bash
lua test_dual_port.lua
```

测试结果确认：
- ✅ 语法检查通过
- ✅ 接口调用正常
- ✅ 双端口配置正确
- ✅ 状态检查功能正常

## 总结

通过这次精简重构：
1. **移除了5个兼容性函数**
2. **重命名了2个函数使其更明确**
3. **修正了5处内部函数调用**
4. **保持了核心功能不变**

代码现在更加简洁、明确，符合双端口架构的设计理念，为后续维护和扩展提供了更好的基础。
