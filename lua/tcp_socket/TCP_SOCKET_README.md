# TCP套接字缓存实时状态同步系统

这个系统将原有的命名管道通信方式改造为TCP套接字，提供更好的双向通信和跨平台兼容性。

## 主要改进

1. **TCP套接字通信**: 替代命名管道，提供更可靠的双向通信
2. **非阻塞读取**: 使用 `client:settimeout(0)` 实现非阻塞操作
3. **行缓冲协议**: 每条JSON消息以换行符结尾，便于解析
4. **连接管理**: 自动重连和连接状态检测
5. **错误处理**: 完善的错误处理和恢复机制

## 系统架构

```
Lua客户端 (Rime插件) <--TCP套接字--> Python服务端
```

## 配置说明

### Lua端配置

默认连接参数：
- 主机: `127.0.0.1`
- 端口: `12345`

可以通过以下方式修改：
```lua
local sync_module = require("named_pipe_cached_sync")
sync_module.set_connection_params("127.0.0.1", 8888)
```

### Python端配置

参考 `tcp_server_example.py` 中的示例服务端实现。

## 使用方法

### 1. 启动Python服务端

```bash
cd /Users/yangxinyi/Library/Rime
python3 tcp_server_example.py
```

或者使用简单测试服务端：
```bash
python3 tcp_test.py
```

### 2. Lua端初始化

在Rime配置中：
```lua
local sync_module = require("named_pipe_cached_sync")

-- 初始化系统
sync_module.init()

-- 在合适的地方调用状态更新
sync_module.update_state_cached(context)
```

**注意**: 现在json模块导入已简化为：
```lua
local json = require("json")
```

系统会自动添加项目lua目录到搜索路径，确保能找到json.lua文件。

### 3. 测试连接

使用测试客户端：
```bash
python3 tcp_test.py client
```

或者使用Lua测试客户端：
```bash
lua test_tcp_client.lua
```

## 通信协议

### 数据格式

所有数据以JSON格式传输，每条消息以换行符结尾：

**Rime状态数据**（Lua -> Python）：
```json
{
    "is_composing": true,
    "input_mode": "chinese",
    "input_text": "hello",
    "timestamp": 1642234567890
}
```

**命令数据**（双向）：
```json
{
    "command": "ping"
}
```

**响应数据**（Python -> Lua）：
```json
{
    "response": "pong"
}
```

### 支持的命令

1. **ping**: 连接测试
2. **get_status**: 获取状态信息
3. **clear_cache**: 清理缓存

## 主要功能

### 1. 缓存机制

- **去重缓存**: 避免发送重复数据
- **时间缓存**: 50ms内的重复数据自动去重
- **批处理**: 可选的批量发送模式

### 2. 连接管理

- **自动重连**: 连接断开时自动尝试重连
- **连接检测**: 定期检查连接状态
- **失败计数**: 连接失败次数限制

### 3. 非阻塞操作

- **写入**: 非阻塞发送，避免影响输入法性能
- **读取**: 使用 `settimeout(0)` 实现非阻塞读取
- **错误处理**: 超时和连接错误的优雅处理

## API接口

### 主要方法

```lua
-- 初始化系统
M.init()

-- 更新状态（主要接口）
M.update_state_cached(context)

-- 手动处理套接字数据
M.manual_process_socket_data()

-- 检查连接状态
M.is_socket_ready()

-- 获取连接信息
M.get_connection_info()

-- 设置连接参数
M.set_connection_params(host, port)

-- 获取缓存统计
M.get_cache_stats()

-- 清理资源
M.fini(env)
```

## 故障排除

### 常见问题

1. **连接失败**
   - 检查Python服务端是否启动
   - 确认端口没有被占用
   - 检查防火墙设置

2. **数据不更新**
   - 检查Lua端是否正确调用 `update_state_cached()`
   - 查看日志文件确认错误信息

3. **性能问题**
   - 调整缓存TTL设置
   - 启用批处理模式
   - 检查网络延迟

### 日志位置

Lua端日志：`/Users/yangxinyi/Library/Rime/log/named_pipe_cached_sync.log`

## 迁移指南

从命名管道迁移到TCP套接字的步骤：

1. 备份原有配置
2. 更新Lua代码调用新的接口
3. 启动Python TCP服务端
4. 测试连接和数据传输
5. 根据需要调整连接参数

## 注意事项

1. **安全性**: 当前仅支持本地连接，如需远程访问请添加认证机制
2. **性能**: TCP套接字比命名管道有更好的跨平台兼容性，但可能有轻微的性能开销
3. **端口冲突**: 确保配置的端口未被其他程序占用
4. **网络环境**: 在某些网络环境下可能需要配置防火墙规则
