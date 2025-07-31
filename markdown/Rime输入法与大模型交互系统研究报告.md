# Rime输入法与大模型交互系统研究报告

**文档版本：** 1.0  
**创建日期：** 2025年7月27日  
**作者：** Rime万象输入法团队  

## 目录

1. [项目概述](#1-项目概述)
2. [系统架构设计](#2-系统架构设计)
3. [触发标识符设计方案](#3-触发标识符设计方案)
4. [Rime端核心组件](#4-rime端核心组件)
5. [Python服务端架构](#5-python服务端架构)
6. [通信协议设计](#6-通信协议设计)
7. [AI功能模式详细设计](#7-ai功能模式详细设计)
8. [用户交互场景分析](#8-用户交互场景分析)
9. [配置系统设计](#9-配置系统设计)
10. [异常处理与容错机制](#10-异常处理与容错机制)
11. [性能优化策略](#11-性能优化策略)
12. [实施计划](#12-实施计划)

---

## 1. 项目概述

### 1.1 项目目标

本项目旨在将大模型的智能对话能力深度集成到 Rime 输入法中，为用户提供无缝的AI辅助输入体验。通过特定的触发标识符，用户可以在任何应用场景下快速调用AI服务，实现智能翻译、内容生成、对话交互等功能。

### 1.2 核心特性

- **无缝集成**：通过输入法直接调用AI服务，无需切换应用
- **多模式支持**：翻译、对话、Agent、辅助聊天等多种AI功能模式
- **实时交互**：支持流式AI回复，实时更新候选词
- **智能上屏**：支持选择性上屏，避免多行内容显示问题
- **高度可配置**：触发标识符、功能模式、行为策略均可配置

### 1.3 技术架构概览

```
┌─────────────────┐    Socket通信    ┌─────────────────┐    HTTP/WebSocket    ┌─────────────────┐
│   Rime 输入法   │ ◄─────────────► │  Python 服务端  │ ◄─────────────────► │    大模型API     │
│                 │                 │                 │                     │                 │
│ • 触发识别      │                 │ • 消息转发      │                     │ • GPT-4         │
│ • 候选词显示    │                 │ • 流式处理      │                     │ • Claude        │
│ • 快捷键响应    │                 │ • 剪贴板操作    │                     │ • 本地模型      │
│ • 状态管理      │                 │ • 快捷键发送    │                     │                 │
└─────────────────┘                 └─────────────────┘                     └─────────────────┘
```

---

## 2. 系统架构设计

### 2.1 整体架构

系统采用三层架构设计：

1. **表示层（Rime端）**：负责用户交互、输入识别、候选词展示
2. **业务层（Python服务端）**：负责协议转换、状态管理、AI调用
3. **服务层（大模型API）**：提供AI能力服务

### 2.2 Rime端组件架构

```lua
-- Rime端核心组件
RimeAISystem = {
    -- 分词器：识别AI触发标识
    ai_segmentor = {
        patterns = {"a:", "t:", "chat:", "agent:"},
        priority = 100
    },
    
    -- 翻译器：处理AI标签，生成候选词
    ai_translator = {
        modes = {"chat", "translate", "agent", "assist"},
        stream_support = true
    },
    
    -- 处理器：监听按键事件
    ai_processor = {
        intercept_keys = {"Return", "Escape", "Tab"},
        state_machine = true
    },
    
    -- 过滤器：候选词处理和显示
    ai_filter = {
        streaming_display = true,
        candidate_management = true
    }
}
```

### 2.3 Python服务端架构

```python
# Python服务端核心模块
class AIService:
    def __init__(self):
        self.socket_server = SocketServer()      # Socket通信服务
        self.ai_client = AIClient()              # 大模型客户端
        self.clipboard = ClipboardManager()      # 剪贴板管理
        self.hotkey = HotkeyManager()           # 快捷键管理
        self.state = StateManager()             # 状态管理
        
    # 主要功能模块
    modules = {
        'chat': ChatModule(),           # 对话模块
        'translate': TranslateModule(), # 翻译模块
        'agent': AgentModule(),         # Agent模块
        'assist': AssistModule()        # 辅助模块
    }
```

---

## 3. 触发标识符设计方案

### 3.1 标识符分类体系

#### 3.1.1 基础对话类
```yaml
chat_triggers:
  simple_chat: "a:"          # 简单对话
  context_chat: "ac:"        # 上下文对话
  role_chat: "ar:"           # 角色扮演对话
  
# 使用示例:
# a:今天天气怎么样？
# ac:继续刚才的话题
# ar:请扮演一个编程专家
```

#### 3.1.2 翻译功能类
```yaml
translate_triggers:
  cn_to_en: "t:"             # 中译英
  en_to_cn: "tc:"            # 英译中
  multi_lang: "tm:"          # 多语言翻译
  
# 使用示例:
# t:你好世界
# tc:hello world
# tm:bonjour (法语到中文)
```

#### 3.1.3 专业助手类
```yaml
agent_triggers:
  code_assistant: "code:"    # 编程助手
  write_assistant: "write:"  # 写作助手
  math_assistant: "math:"    # 数学助手
  search_assistant: "search:" # 搜索助手
  
# 使用示例:
# code:如何实现快速排序？
# write:帮我写一份会议纪要
# math:求解二次方程 x²+3x+2=0
```

#### 3.1.4 快捷工具类
```yaml
tool_triggers:
  summarize: "sum:"          # 总结工具
  explain: "exp:"            # 解释工具
  improve: "imp:"            # 改进工具
  
# 使用示例:
# sum:请总结这段文字
# exp:解释量子计算的原理
# imp:改进这段代码的性能
```

### 3.2 动态配置系统

```yaml
# ai_config.yaml - 触发标识符配置文件
ai_triggers:
  enabled: true
  custom_triggers:
    # 用户可以自定义触发器
    my_chat: "聊:"
    my_translate: "翻:"
    my_code: "码:"
  
  # 触发器行为配置
  behavior:
    show_input: true          # 是否显示用户输入
    auto_commit: false        # 是否自动上屏
    clipboard_mode: true      # 是否使用剪贴板模式
    
  # 模式特定配置
  modes:
    chat:
      max_context: 10         # 最大上下文轮数
      temperature: 0.7        # AI温度参数
    translate:
      target_lang: "auto"     # 目标语言
      preserve_format: true   # 保持格式
```

### 3.3 触发器优先级系统

```lua
-- 触发器优先级配置
local trigger_priority = {
    ["code:"] = 1,      -- 最高优先级
    ["math:"] = 2,
    ["t:"] = 3,
    ["a:"] = 4,         -- 默认优先级
    -- 自定义触发器优先级较低
}

-- 模糊匹配策略
local fuzzy_matching = {
    enabled = true,
    threshold = 0.8,    -- 相似度阈值
    suggestions = true  -- 提供建议
}
```

---

## 4. Rime端核心组件

### 4.1 AI分词器 (ai_segmentor.lua)

#### 4.1.1 核心功能
```lua
local function ai_segmentor(segmentation, env)
    local context = env.engine.context
    local input = context.input
    
    -- 触发器匹配逻辑
    for pattern, config in pairs(ai_config.triggers) do
        if input:match("^" .. pattern) then
            -- 创建AI段落
            local ai_segment = Segment(0, #pattern)
            ai_segment.tags = Set{"ai_talk", config.mode}
            
            -- 创建内容段落
            if #input > #pattern then
                local content_segment = Segment(#pattern, #input)
                content_segment.tags = Set{"ai_content"}
                segmentation:add_segment(content_segment)
            end
            
            segmentation:add_segment(ai_segment)
            return true
        end
    end
    
    return false
end
```

#### 4.1.2 状态管理
```lua
local ai_state = {
    current_mode = nil,
    session_id = nil,
    is_streaming = false,
    last_trigger = nil
}

function update_ai_state(mode, trigger)
    ai_state.current_mode = mode
    ai_state.last_trigger = trigger
    ai_state.session_id = generate_session_id()
end
```

### 4.2 AI翻译器 (ai_translator.lua)

#### 4.2.1 候选词生成
```lua
local function ai_translator(input, seg, env)
    local context = env.engine.context
    
    if seg:has_tag("ai_talk") then
        -- 生成AI模式提示候选词
        local mode = detect_ai_mode(input)
        yield(Candidate("ai_prompt", seg.start, seg._end, 
                       get_mode_prompt(mode), get_mode_description(mode)))
    end
    
    if seg:has_tag("ai_content") then
        -- 处理AI内容
        local content = input:sub(seg.start + 1)
        if #content > 0 then
            yield(Candidate("ai_content", seg.start, seg._end, 
                           content, "准备发送到AI"))
        end
    end
end
```

#### 4.2.2 流式响应处理
```lua
local function handle_streaming_response(context)
    local stream_content = context:get_property("ai_stream_content")
    if stream_content and stream_content ~= "" then
        -- 更新流式候选词
        local candidate = Candidate("ai_response", 0, 0, 
                                  stream_content, "AI回复中...")
        candidate.preedit = "AI: " .. stream_content
        return candidate
    end
end
```

### 4.3 AI处理器 (ai_processor.lua)

#### 4.3.1 按键拦截处理
```lua
local function ai_processor(key_event, env)
    local context = env.engine.context
    local input = context.input
    
    -- 检查是否在AI模式
    if is_ai_mode(context) then
        if key_event:repr() == "Return" then
            return handle_ai_commit(context, env)
        elseif key_event:repr() == "Escape" then
            return handle_ai_cancel(context, env)
        elseif key_event:repr() == "Tab" then
            return handle_ai_action(context, env)
        end
    end
    
    return kNoop  -- 继续处理
end
```

#### 4.3.2 提交处理逻辑
```lua
local function handle_ai_commit(context, env)
    local config = get_ai_config()
    local input = context.input
    
    if config.show_input then
        -- 显示用户输入
        context:commit_text(extract_content(input))
    end
    
    -- 发送到AI服务
    send_to_ai_service(input, context)
    
    -- 根据配置决定是否清空输入
    if config.auto_clear then
        context:clear()
    end
    
    return kAccepted
end
```

---

## 5. Python服务端架构

### 5.1 主服务架构

#### 5.1.1 服务端主类
```python
import asyncio
import socket
import json
from typing import Dict, Any, Optional
from dataclasses import dataclass
from enum import Enum

class AIMode(Enum):
    CHAT = "chat"
    TRANSLATE = "translate"
    AGENT = "agent"
    ASSIST = "assist"

@dataclass
class AIRequest:
    mode: AIMode
    content: str
    session_id: str
    config: Dict[str, Any]
    timestamp: float

class RimeAIServer:
    def __init__(self, host='127.0.0.1', port=10086):
        self.host = host
        self.port = port
        self.clients = {}
        self.ai_handlers = self._init_ai_handlers()
        self.running = False
        
    async def start(self):
        """启动服务器"""
        server = await asyncio.start_server(
            self.handle_client, self.host, self.port
        )
        self.running = True
        logger.info(f"AI服务器启动: {self.host}:{self.port}")
        await server.serve_forever()
```

#### 5.1.2 客户端连接处理
```python
async def handle_client(self, reader, writer):
    """处理客户端连接"""
    client_addr = writer.get_extra_info('peername')
    logger.info(f"新客户端连接: {client_addr}")
    
    try:
        while self.running:
            # 读取请求
            data = await reader.read(4096)
            if not data:
                break
                
            # 解析请求
            request = self.parse_request(data)
            
            # 处理请求
            await self.process_ai_request(request, writer)
            
    except Exception as e:
        logger.error(f"客户端处理错误: {e}")
    finally:
        writer.close()
        await writer.wait_closed()
```

### 5.2 AI处理模块

#### 5.2.1 模块化AI处理器
```python
class BaseAIHandler:
    """AI处理器基类"""
    def __init__(self, ai_client):
        self.ai_client = ai_client
        
    async def process(self, request: AIRequest) -> AsyncGenerator[str, None]:
        """处理AI请求，返回流式响应"""
        raise NotImplementedError

class ChatHandler(BaseAIHandler):
    """对话处理器"""
    async def process(self, request: AIRequest):
        messages = self.build_chat_messages(request)
        
        async for chunk in self.ai_client.stream_chat(messages):
            if chunk.choices[0].delta.content:
                yield chunk.choices[0].delta.content

class TranslateHandler(BaseAIHandler):
    """翻译处理器"""
    async def process(self, request: AIRequest):
        prompt = self.build_translate_prompt(request)
        
        async for chunk in self.ai_client.stream_complete(prompt):
            yield chunk
```

#### 5.2.2 AI客户端集成
```python
class AIClient:
    """统一AI客户端接口"""
    def __init__(self, config):
        self.config = config
        self.providers = self._init_providers()
        
    async def stream_chat(self, messages, model="gpt-4"):
        """流式对话"""
        provider = self.get_provider(model)
        async for chunk in provider.stream_chat(messages):
            yield chunk
            
    def _init_providers(self):
        """初始化AI提供商"""
        return {
            'openai': OpenAIProvider(self.config.openai),
            'claude': ClaudeProvider(self.config.claude),
            'local': LocalProvider(self.config.local)
        }
```

### 5.3 系统集成组件

#### 5.3.1 剪贴板管理器
```python
import pyperclip
from typing import Optional

class ClipboardManager:
    """剪贴板管理器"""
    
    def __init__(self):
        self.last_content = ""
        
    def set_content(self, content: str) -> bool:
        """设置剪贴板内容"""
        try:
            pyperclip.copy(content)
            self.last_content = content
            logger.info(f"剪贴板内容已更新: {len(content)} 字符")
            return True
        except Exception as e:
            logger.error(f"设置剪贴板失败: {e}")
            return False
            
    def get_content(self) -> Optional[str]:
        """获取剪贴板内容"""
        try:
            return pyperclip.paste()
        except Exception as e:
            logger.error(f"获取剪贴板失败: {e}")
            return None
            
    def execute_paste(self) -> bool:
        """执行粘贴操作"""
        try:
            # 发送 Ctrl+V 快捷键
            import pyautogui
            pyautogui.hotkey('ctrl', 'v')
            return True
        except Exception as e:
            logger.error(f"执行粘贴失败: {e}")
            return False
```

#### 5.3.2 快捷键管理器
```python
import pynput
from pynput import keyboard

class HotkeyManager:
    """快捷键管理器"""
    
    def __init__(self, rime_callback=None):
        self.rime_callback = rime_callback
        self.listener = None
        
    def send_update_signal(self):
        """发送更新信号给Rime"""
        try:
            # 发送特定快捷键组合，触发Rime更新
            import pyautogui
            pyautogui.hotkey('ctrl', 'alt', 'u')  # 自定义更新信号
            logger.debug("已发送Rime更新信号")
        except Exception as e:
            logger.error(f"发送更新信号失败: {e}")
            
    def start_monitoring(self):
        """开始监听快捷键"""
        def on_hotkey():
            if self.rime_callback:
                self.rime_callback()
                
        self.listener = keyboard.GlobalHotKeys({
            '<ctrl>+<alt>+r': on_hotkey  # Rime刷新快捷键
        })
        self.listener.start()
```

---

## 6. 通信协议设计

### 6.1 Socket通信协议

#### 6.1.1 消息格式定义
```json
{
  "version": "1.0",
  "message_type": "request|response|notification",
  "session_id": "uuid",
  "timestamp": 1627834567890,
  "data": {
    "action": "chat|translate|agent|assist",
    "content": "用户输入内容",
    "config": {
      "mode": "stream|block",
      "show_input": true,
      "auto_commit": false
    }
  }
}
```

#### 6.1.2 请求类型定义
```python
# 请求类型枚举
class MessageType(Enum):
    # Rime -> Python 请求
    AI_REQUEST = "ai_request"           # AI处理请求
    CONFIG_UPDATE = "config_update"     # 配置更新
    SESSION_START = "session_start"     # 会话开始
    SESSION_END = "session_end"         # 会话结束
    
    # Python -> Rime 响应
    AI_RESPONSE = "ai_response"         # AI响应
    AI_STREAM = "ai_stream"             # 流式响应
    AI_COMPLETE = "ai_complete"         # 响应完成
    ERROR_RESPONSE = "error"            # 错误响应
    
    # 系统通知
    HEARTBEAT = "heartbeat"             # 心跳包
    STATUS_UPDATE = "status_update"     # 状态更新

# 消息处理映射
MESSAGE_HANDLERS = {
    MessageType.AI_REQUEST: handle_ai_request,
    MessageType.CONFIG_UPDATE: handle_config_update,
    MessageType.SESSION_START: handle_session_start,
    MessageType.SESSION_END: handle_session_end,
    MessageType.HEARTBEAT: handle_heartbeat
}
```

#### 6.1.3 流式响应协议
```python
class StreamResponse:
    """流式响应处理"""
    
    def __init__(self, session_id: str):
        self.session_id = session_id
        self.buffer = ""
        self.is_complete = False
        
    async def send_chunk(self, writer, chunk: str):
        """发送流式数据块"""
        message = {
            "message_type": "ai_stream",
            "session_id": self.session_id,
            "data": {
                "chunk": chunk,
                "is_complete": False
            }
        }
        
        await self.send_message(writer, message)
        
    async def send_complete(self, writer, final_content: str):
        """发送完成信号"""
        message = {
            "message_type": "ai_complete",
            "session_id": self.session_id,
            "data": {
                "final_content": final_content,
                "is_complete": True
            }
        }
        
        await self.send_message(writer, message)
```

### 6.2 状态同步机制

#### 6.2.1 双向状态同步
```lua
-- Rime端状态同步
local function sync_state_to_server(context, state_data)
    local message = {
        message_type = "status_update",
        session_id = get_session_id(context),
        data = {
            input_state = context.input,
            composition_state = context:is_composing(),
            candidate_count = #context.candidates,
            custom_data = state_data
        }
    }
    
    tcp_socket.send_message(json.encode(message))
end

-- 状态变化监听
local function setup_state_listeners(env)
    local context = env.engine.context
    
    -- 输入状态变化
    context.update_notifier:connect(function(ctx)
        if is_ai_mode(ctx) then
            sync_state_to_server(ctx, {event = "input_change"})
        end
    end)
    
    -- 候选词选择
    context.select_notifier:connect(function(ctx)
        if is_ai_mode(ctx) then
            sync_state_to_server(ctx, {event = "candidate_select"})
        end
    end)
end
```

#### 6.2.2 会话管理
```python
class SessionManager:
    """会话管理器"""
    
    def __init__(self):
        self.sessions = {}
        self.active_sessions = set()
        
    def create_session(self, client_info) -> str:
        """创建新会话"""
        session_id = str(uuid.uuid4())
        self.sessions[session_id] = {
            'id': session_id,
            'client_info': client_info,
            'created_at': time.time(),
            'last_activity': time.time(),
            'context': [],
            'state': 'active'
        }
        self.active_sessions.add(session_id)
        return session_id
        
    def update_session(self, session_id: str, data: dict):
        """更新会话数据"""
        if session_id in self.sessions:
            self.sessions[session_id].update(data)
            self.sessions[session_id]['last_activity'] = time.time()
            
    def cleanup_expired_sessions(self, max_idle_time=3600):
        """清理过期会话"""
        current_time = time.time()
        expired_sessions = []
        
        for session_id, session in self.sessions.items():
            if current_time - session['last_activity'] > max_idle_time:
                expired_sessions.append(session_id)
                
        for session_id in expired_sessions:
            self.end_session(session_id)
```

---

## 7. AI功能模式详细设计

### 7.1 对话模式 (Chat Mode)

#### 7.1.1 简单对话模式
```python
class SimpleChatHandler(BaseAIHandler):
    """简单对话处理器"""
    
    async def process(self, request: AIRequest):
        # 构建对话消息
        messages = [
            {"role": "system", "content": "你是一个有用的助手，请简洁明了地回答问题。"},
            {"role": "user", "content": request.content}
        ]
        
        # 流式响应
        response_buffer = ""
        async for chunk in self.ai_client.stream_chat(messages):
            if chunk.choices[0].delta.content:
                content = chunk.choices[0].delta.content
                response_buffer += content
                yield {
                    "type": "chunk",
                    "content": content,
                    "buffer": response_buffer
                }
        
        # 完成响应
        yield {
            "type": "complete",
            "content": response_buffer,
            "actions": ["copy_to_clipboard", "send_hotkey"]
        }
```

#### 7.1.2 上下文对话模式
```python
class ContextChatHandler(BaseAIHandler):
    """上下文对话处理器"""
    
    def __init__(self, ai_client, session_manager):
        super().__init__(ai_client)
        self.session_manager = session_manager
        self.max_context_length = 10
        
    async def process(self, request: AIRequest):
        # 获取会话上下文
        session = self.session_manager.get_session(request.session_id)
        context_messages = session.get('context', [])
        
        # 构建完整对话历史
        messages = [
            {"role": "system", "content": "你是一个智能助手，能够理解上下文并保持对话连贯性。"}
        ]
        
        # 添加历史上下文（限制长度）
        recent_context = context_messages[-self.max_context_length:]
        messages.extend(recent_context)
        
        # 添加当前用户输入
        messages.append({"role": "user", "content": request.content})
        
        # 处理响应
        response_content = ""
        async for chunk in self.ai_client.stream_chat(messages):
            if chunk.choices[0].delta.content:
                content = chunk.choices[0].delta.content
                response_content += content
                yield {
                    "type": "chunk", 
                    "content": content,
                    "session_id": request.session_id
                }
        
        # 更新会话上下文
        context_messages.extend([
            {"role": "user", "content": request.content},
            {"role": "assistant", "content": response_content}
        ])
        
        self.session_manager.update_session(request.session_id, {
            'context': context_messages
        })
        
        yield {
            "type": "complete",
            "content": response_content,
            "session_id": request.session_id
        }
```

#### 7.1.3 角色扮演对话模式
```python
class RoleChatHandler(BaseAIHandler):
    """角色扮演对话处理器"""
    
    def __init__(self, ai_client):
        super().__init__(ai_client)
        self.roles = {
            "programmer": "你是一个经验丰富的程序员，精通多种编程语言和开发框架。",
            "teacher": "你是一个耐心的老师，善于用简单易懂的方式解释复杂概念。",
            "writer": "你是一个专业的作家，擅长各种文体的写作和文案创作。",
            "analyst": "你是一个数据分析师，善于从数据中发现规律和提供洞察。"
        }
    
    def extract_role_and_content(self, input_text):
        """提取角色和内容"""
        # 解析格式：ar:programmer 如何优化代码性能？
        parts = input_text.split(' ', 1)
        if len(parts) >= 2:
            role = parts[0].replace('ar:', '')
            content = parts[1]
            return role, content
        return 'assistant', input_text
    
    async def process(self, request: AIRequest):
        role, content = self.extract_role_and_content(request.content)
        
        # 获取角色系统提示
        system_prompt = self.roles.get(role, "你是一个有用的助手。")
        
        messages = [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": content}
        ]
        
        # 流式响应处理
        async for chunk in self.ai_client.stream_chat(messages):
            if chunk.choices[0].delta.content:
                yield {
                    "type": "chunk",
                    "content": chunk.choices[0].delta.content,
                    "role": role
                }
```

### 7.2 翻译模式 (Translate Mode)

#### 7.2.1 智能翻译处理器
```python
class SmartTranslateHandler(BaseAIHandler):
    """智能翻译处理器"""
    
    def __init__(self, ai_client):
        super().__init__(ai_client)
        self.language_map = {
            't:': ('auto', 'en'),     # 自动检测到英文
            'tc:': ('auto', 'zh'),    # 自动检测到中文
            'tj:': ('auto', 'ja'),    # 自动检测到日文
            'tk:': ('auto', 'ko'),    # 自动检测到韩文
        }
    
    def detect_source_language(self, text):
        """检测源语言"""
        # 简单的语言检测逻辑
        chinese_chars = len([c for c in text if '\u4e00' <= c <= '\u9fff'])
        total_chars = len(text)
        
        if chinese_chars / total_chars > 0.3:
            return 'zh'
        elif any(c.isascii() and c.isalpha() for c in text):
            return 'en'
        else:
            return 'auto'
    
    def build_translate_prompt(self, source_lang, target_lang, text):
        """构建翻译提示词"""
        if source_lang == 'auto':
            source_desc = "自动检测源语言"
        else:
            lang_names = {'zh': '中文', 'en': '英文', 'ja': '日文', 'ko': '韩文'}
            source_desc = lang_names.get(source_lang, source_lang)
            
        target_names = {'zh': '中文', 'en': '英文', 'ja': '日文', 'ko': '韩文'}
        target_desc = target_names.get(target_lang, target_lang)
        
        return f"""请将以下文本翻译成{target_desc}。要求：
1. 保持原文的语气和风格
2. 确保翻译准确自然
3. 如果是专业术语，请保持专业性
4. 只输出翻译结果，不要包含解释

原文：{text}

翻译："""

    async def process(self, request: AIRequest):
        # 解析翻译请求
        trigger = request.content.split(':', 1)[0] + ':'
        text_to_translate = request.content.split(':', 1)[1].strip()
        
        # 获取语言配置
        source_lang, target_lang = self.language_map.get(trigger, ('auto', 'en'))
        
        # 构建翻译提示
        prompt = self.build_translate_prompt(source_lang, target_lang, text_to_translate)
        
        # 流式翻译
        translation = ""
        async for chunk in self.ai_client.stream_complete(prompt):
            translation += chunk
            yield {
                "type": "chunk",
                "content": chunk,
                "translation": translation,
                "source_lang": source_lang,
                "target_lang": target_lang
            }
        
        yield {
            "type": "complete",
            "content": translation.strip(),
            "source_text": text_to_translate,
            "source_lang": source_lang,
            "target_lang": target_lang
        }
```

#### 7.2.2 格式保持翻译
```python
class FormatPreservingTranslator:
    """格式保持翻译器"""
    
    def __init__(self, ai_client):
        self.ai_client = ai_client
        
    def extract_format_structure(self, text):
        """提取格式结构"""
        import re
        
        # 提取Markdown格式
        markdown_patterns = {
            'headers': re.findall(r'^#+\s+', text, re.MULTILINE),
            'lists': re.findall(r'^[\*\-\+]\s+', text, re.MULTILINE),
            'code_blocks': re.findall(r'```[\s\S]*?```', text),
            'inline_code': re.findall(r'`[^`]+`', text),
            'links': re.findall(r'\[([^\]]+)\]\(([^)]+)\)', text),
            'bold': re.findall(r'\*\*([^*]+)\*\*', text),
            'italic': re.findall(r'\*([^*]+)\*', text)
        }
        
        return markdown_patterns
    
    async def translate_with_format(self, text, source_lang, target_lang):
        """保持格式的翻译"""
        # 提取格式信息
        format_info = self.extract_format_structure(text)
        
        # 构建特殊提示词
        prompt = f"""请翻译以下文本到{target_lang}，并严格保持原有的格式结构：
- 保持所有Markdown标记
- 保持代码块不变
- 保持链接结构
- 保持列表格式

原文：
{text}

翻译："""

        # 执行翻译
        translated = ""
        async for chunk in self.ai_client.stream_complete(prompt):
            translated += chunk
            
        return translated.strip()
```

### 7.3 Agent模式 (Agent Mode)

#### 7.3.1 编程助手Agent
```python
class CodeAssistantAgent(BaseAIHandler):
    """编程助手Agent"""
    
    def __init__(self, ai_client):
        super().__init__(ai_client)
        self.system_prompt = """你是一个专业的编程助手，具备以下能力：
1. 代码编写和优化
2. 代码审查和调试
3. 算法设计和分析
4. 技术方案设计
5. 编程最佳实践指导

请根据用户需求提供专业的编程建议和解决方案。"""

    def analyze_code_request(self, content):
        """分析代码请求类型"""
        request_types = {
            '写': 'code_generation',
            '优化': 'code_optimization', 
            '调试': 'code_debugging',
            '解释': 'code_explanation',
            '重构': 'code_refactoring'
        }
        
        for keyword, request_type in request_types.items():
            if keyword in content:
                return request_type
        
        return 'general_coding'
    
    async def process(self, request: AIRequest):
        # 移除触发器前缀
        content = request.content.replace('code:', '').strip()
        request_type = self.analyze_code_request(content)
        
        # 根据请求类型调整系统提示
        specialized_prompts = {
            'code_generation': self.system_prompt + "\n重点关注代码的可读性和效率。",
            'code_optimization': self.system_prompt + "\n重点关注性能优化和代码质量。",
            'code_debugging': self.system_prompt + "\n重点关注问题定位和解决方案。",
            'code_explanation': self.system_prompt + "\n重点关注清晰的解释和示例。",
            'code_refactoring': self.system_prompt + "\n重点关注代码结构和可维护性。"
        }
        
        system_prompt = specialized_prompts.get(request_type, self.system_prompt)
        
        messages = [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": content}
        ]
        
        # 流式响应
        response_buffer = ""
        async for chunk in self.ai_client.stream_chat(messages):
            if chunk.choices[0].delta.content:
                content_chunk = chunk.choices[0].delta.content
                response_buffer += content_chunk
                yield {
                    "type": "chunk",
                    "content": content_chunk,
                    "request_type": request_type,
                    "buffer": response_buffer
                }
        
        yield {
            "type": "complete",
            "content": response_buffer,
            "request_type": request_type,
            "actions": ["copy_to_clipboard", "format_code"]
        }
```

#### 7.3.2 写作助手Agent
```python
class WritingAssistantAgent(BaseAIHandler):
    """写作助手Agent"""
    
    def __init__(self, ai_client):
        super().__init__(ai_client)
        self.writing_types = {
            '邮件': 'email',
            '报告': 'report', 
            '文案': 'copywriting',
            '总结': 'summary',
            '提纲': 'outline'
        }
        
    def get_writing_template(self, writing_type):
        """获取写作模板"""
        templates = {
            'email': {
                'system': "你是专业的商务写作助手，擅长撰写各类邮件。",
                'structure': "主题-称谓-正文-结尾-署名"
            },
            'report': {
                'system': "你是专业的报告撰写助手，擅长结构化内容组织。",
                'structure': "摘要-背景-分析-结论-建议"
            },
            'copywriting': {
                'system': "你是创意文案写手，擅长吸引人的营销文案。",
                'structure': "标题-开头-主体-行动号召"
            }
        }
        
        return templates.get(writing_type, {
            'system': "你是专业的写作助手。",
            'structure': "开头-正文-结尾"
        })
    
    async def process(self, request: AIRequest):
        content = request.content.replace('write:', '').strip()
        
        # 识别写作类型
        writing_type = 'general'
        for type_key, type_value in self.writing_types.items():
            if type_key in content:
                writing_type = type_value
                break
        
        # 获取模板
        template = self.get_writing_template(writing_type)
        
        messages = [
            {"role": "system", "content": template['system']},
            {"role": "user", "content": f"请帮我写{content}，结构参考：{template['structure']}"}
        ]
        
        # 流式响应
        async for chunk in self.ai_client.stream_chat(messages):
            if chunk.choices[0].delta.content:
                yield {
                    "type": "chunk",
                    "content": chunk.choices[0].delta.content,
                    "writing_type": writing_type
                }
```

---

## 8. 用户交互场景分析

### 8.1 标准交互流程

#### 8.1.1 基本对话流程
```
用户输入: a:今天天气怎么样？
     ↓
1. Rime识别触发器 "a:"
     ↓
2. 分词器标记AI段落
     ↓
3. 翻译器显示: 〔AI对话〕今天天气怎么样？
     ↓
4. 用户按回车确认
     ↓
5. 处理器拦截提交事件
     ↓
6. Socket发送请求到Python服务端
     ↓
7. Python调用AI API获取回复
     ↓
8. 流式响应更新Rime候选词
     ↓
9. 用户选择操作（上屏/复制/取消）qasq
```

#### 8.1.2 配置驱动的交互变化
```yaml
# 场景1：显示用户输入
show_user_input: true
# 交互：用户看到完整对话内容
# 输出：用户: 今天天气怎么样？
#      AI: 今天是晴天，温度适宜...

# 场景2：仅显示AI回复
show_user_input: false  
# 交互：用户输入被隐藏
# 输出：今天是晴天，温度适宜...

# 场景3：自动提交模式
auto_commit: true
# 交互：AI回复自动上屏，无需用户选择

# 场景4：剪贴板模式
clipboard_mode: true
# 交互：AI回复不上屏，直接复制到剪贴板
```

### 8.2 复杂交互场景处理

#### 8.2.1 多行内容处理策略
```python
class MultilineHandler:
    """多行内容处理器"""
    
    def __init__(self, config):
        self.config = config
        
    def process_multiline_response(self, content):
        """处理多行AI响应"""
        strategies = {
            'clipboard': self.handle_clipboard_mode,
            'segmented': self.handle_segmented_commit,
            'formatted': self.handle_formatted_display
        }
        
        strategy = self.config.get('multiline_strategy', 'clipboard')
        return strategies[strategy](content)
    
    def handle_clipboard_mode(self, content):
        """剪贴板模式：复制到剪贴板，发送粘贴快捷键"""
        clipboard_manager.set_content(content)
        hotkey_manager.send_paste_command()
        return {
            'action': 'clipboard_paste',
            'content': content,
            'user_message': '内容已复制到剪贴板并粘贴'
        }
    
    def handle_segmented_commit(self, content):
        """分段提交：按段落分别上屏"""
        paragraphs = content.split('\n\n')
        return {
            'action': 'segmented_commit',
            'segments': paragraphs,
            'user_message': f'将分{len(paragraphs)}段上屏'
        }
    
    def handle_formatted_display(self, content):
        """格式化显示：在候选词中显示预览"""
        preview = content[:100] + '...' if len(content) > 100 else content
        return {
            'action': 'formatted_display',
            'preview': preview.replace('\n', ' '),
            'full_content': content,
            'user_message': '查看完整内容请按Tab'
        }
```

#### 8.2.2 用户中断处理
```lua
-- Rime端中断处理
local function handle_user_interruption(context, interruption_type)
    local ai_state = context:get_property("ai_state")
    
    if ai_state == "waiting_response" then
        -- AI正在响应时的中断处理
        local actions = {
            escape = function()
                -- 用户按ESC，取消AI请求
                send_cancel_request(context)
                context:clear()
                return kAccepted
            end,
            
            mouse_click = function()
                -- 用户点击其他位置，保存状态
                save_ai_session_state(context)
                return kNoop
            end,
            
            app_switch = function()
                -- 应用切换，暂停AI会话
                pause_ai_session(context)
                return kNoop
            end,
            
            new_input = function()
                -- 用户开始新输入，询问是否取消当前请求
                show_cancel_confirmation(context)
                return kAccepted
            end
        }
        
        local handler = actions[interruption_type]
        if handler then
            return handler()
        end
    end
    
    return kNoop
end

-- 应用焦点变化监听
local function setup_focus_monitoring(env)
    -- 监听应用焦点变化
    env.focus_notifier = context.option_update_notifier:connect(function(context, option)
        if option == "ascii_mode" then
            -- 应用切换通常会触发ascii_mode变化
            local ai_session = context:get_property("ai_session_active")
            if ai_session == "true" then
                handle_user_interruption(context, "app_switch")
            end
        end
    end)
end
```

#### 8.2.3 错误场景处理
```python
class ErrorScenarioHandler:
    """错误场景处理器"""
    
    async def handle_ai_timeout(self, session_id):
        """处理AI响应超时"""
        return {
            'error_type': 'timeout',
            'message': 'AI响应超时，请重试',
            'suggested_actions': ['retry', 'cancel'],
            'fallback_content': '抱歉，AI服务暂时不可用'
        }
    
    async def handle_network_error(self, session_id):
        """处理网络错误"""
        return {
            'error_type': 'network',
            'message': '网络连接异常',
            'suggested_actions': ['check_connection', 'retry'],
            'fallback_content': '请检查网络连接后重试'
        }
    
    async def handle_ai_service_error(self, session_id, error_details):
        """处理AI服务错误"""
        return {
            'error_type': 'ai_service',
            'message': f'AI服务错误: {error_details}',
            'suggested_actions': ['switch_model', 'retry'],
            'fallback_content': '请尝试切换AI模型或稍后重试'
        }
```

### 8.3 用户操作选项设计

#### 8.3.1 AI回复后的操作选项
```lua
-- AI回复完成后的候选词选项
local function generate_ai_action_candidates(ai_response)
    local candidates = {}
    
    -- 主要操作选项
    table.insert(candidates, Candidate("ai_action", 0, 0, 
        ai_response.content, "上屏AI回复"))
    
    table.insert(candidates, Candidate("ai_copy", 0, 0,
        "📋 复制", "复制到剪贴板"))
    
    table.insert(candidates, Candidate("ai_paste", 0, 0,
        "📋➡️ 粘贴", "复制并粘贴"))
    
    -- 扩展操作选项
    if #ai_response.content > 200 then
        table.insert(candidates, Candidate("ai_preview", 0, 0,
            "👁️ 预览", "预览完整内容"))
    end
    
    if ai_response.mode == "translate" then
        table.insert(candidates, Candidate("ai_reverse", 0, 0,
            "🔄 反向翻译", "翻译回原语言"))
    end
    
    if ai_response.mode == "chat" then
        table.insert(candidates, Candidate("ai_continue", 0, 0,
            "💬 继续对话", "基于此回复继续"))
    end
    
    -- 取消操作
    table.insert(candidates, Candidate("ai_cancel", 0, 0,
        "❌ 取消", "取消当前操作"))
    
    return candidates
end
```

#### 8.3.2 快捷键操作映射
```yaml
# 快捷键配置
ai_shortcuts:
  # 主要操作
  commit: "Return"          # 上屏AI回复
  copy: "Ctrl+c"           # 复制到剪贴板
  paste: "Ctrl+v"          # 复制并粘贴
  cancel: "Escape"         # 取消操作
  
  # 扩展操作
  preview: "Tab"           # 预览完整内容
  continue_chat: "Ctrl+Return"  # 继续对话
  reverse_translate: "Ctrl+r"   # 反向翻译
  
  # 模式切换
  switch_mode: "Ctrl+m"    # 切换AI模式
  settings: "Ctrl+,"       # 打开设置
```

---

## 9. 配置系统设计

### 9.1 分层配置架构

#### 9.1.1 配置文件层次结构
```
配置系统层次:
├── 全局配置 (ai_global.yaml)
│   ├── 服务端连接配置
│   ├── 默认AI模型配置  
│   └── 系统级开关
├── 方案配置 (schema.yaml中的ai_config段)
│   ├── 方案特定的触发器
│   ├── 候选词显示配置
│   └── 快捷键映射
├── 用户配置 (ai_user.yaml)
│   ├── 个人偏好设置
│   ├── 自定义触发器
│   └── 历史记录配置
└── 会话配置 (运行时动态配置)
    ├── 当前会话状态
    ├── 临时设置覆盖
    └── 模式特定参数
```

#### 9.1.2 配置文件示例
```yaml
# ai_global.yaml - 全局配置
ai_system:
  version: "1.0"
  enabled: true
  
  # 服务端配置
  server:
    host: "127.0.0.1"
    port: 10086
    timeout: 30
    retry_attempts: 3
    
  # 默认AI配置
  default_ai:
    provider: "openai"
    model: "gpt-4"
    temperature: 0.7
    max_tokens: 2000
    
  # 系统行为
  behavior:
    auto_start_server: true
    log_conversations: true
    cache_responses: true

# ai_user.yaml - 用户配置  
user_preferences:
  # 界面偏好
  display:
    show_user_input: true
    show_typing_indicator: true
    candidate_limit: 5
    preview_length: 100
    
  # 交互偏好
  interaction:
    auto_commit: false
    clipboard_mode: true
    confirm_before_send: false
    save_history: true
    
  # 自定义触发器
  custom_triggers:
    quick_chat: "q:"
    translate_cn: "翻:"
    code_help: "代码:"
    
  # AI配置覆盖
  ai_overrides:
    chat:
      model: "gpt-3.5-turbo"
      temperature: 0.8
    translate:
      model: "gpt-4"
      temperature: 0.3
```

### 9.2 动态配置管理

#### 9.2.1 配置热重载机制
```python
import yaml
from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler

class ConfigManager:
    """配置管理器"""
    
    def __init__(self, config_dir):
        self.config_dir = config_dir
        self.configs = {}
        self.observers = []
        self.change_callbacks = []
        
    def load_all_configs(self):
        """加载所有配置文件"""
        config_files = {
            'global': 'ai_global.yaml',
            'user': 'ai_user.yaml',
            'triggers': 'ai_triggers.yaml'
        }
        
        for config_type, filename in config_files.items():
            file_path = os.path.join(self.config_dir, filename)
            self.configs[config_type] = self.load_config_file(file_path)
            
    def load_config_file(self, file_path):
        """加载单个配置文件"""
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                return yaml.safe_load(f)
        except FileNotFoundError:
            logger.warning(f"配置文件不存在: {file_path}")
            return {}
        except yaml.YAMLError as e:
            logger.error(f"配置文件格式错误: {file_path}, {e}")
            return {}
            
    def start_watching(self):
        """开始监听配置文件变化"""
        event_handler = ConfigFileHandler(self)
        observer = Observer()
        observer.schedule(event_handler, self.config_dir, recursive=False)
        observer.start()
        self.observers.append(observer)
        
    def on_config_changed(self, config_type, new_config):
        """配置变化回调"""
        old_config = self.configs.get(config_type, {})
        self.configs[config_type] = new_config
        
        # 通知所有订阅者
        for callback in self.change_callbacks:
            callback(config_type, old_config, new_config)
            
    def get_merged_config(self, section=None):
        """获取合并后的配置"""
        merged = {}
        
        # 按优先级合并：全局 < 用户 < 会话
        for config_type in ['global', 'user', 'session']:
            config = self.configs.get(config_type, {})
            if section:
                config = config.get(section, {})
            self._deep_merge(merged, config)
            
        return merged
        
    def _deep_merge(self, base, override):
        """深度合并字典"""
        for key, value in override.items():
            if key in base and isinstance(base[key], dict) and isinstance(value, dict):
                self._deep_merge(base[key], value)
            else:
                base[key] = value

class ConfigFileHandler(FileSystemEventHandler):
    """配置文件变化处理器"""
    
    def __init__(self, config_manager):
        self.config_manager = config_manager
        
    def on_modified(self, event):
        if event.is_directory:
            return
            
        filename = os.path.basename(event.src_path)
        if filename.endswith('.yaml'):
            logger.info(f"检测到配置文件变化: {filename}")
            # 重新加载配置
            config_type = filename.replace('ai_', '').replace('.yaml', '')
            new_config = self.config_manager.load_config_file(event.src_path)
            self.config_manager.on_config_changed(config_type, new_config)
```

#### 9.2.2 Rime端配置同步
```lua
-- Rime端配置管理
local config_manager = {}

function config_manager.init(env)
    -- 从schema.yaml读取AI配置
    local schema_config = env.engine.schema.config
    local ai_config = schema_config:get_map("ai_config") or {}
    
    -- 设置默认配置
    config_manager.config = {
        triggers = ai_config:get_map("triggers") or {},
        display = ai_config:get_map("display") or {},
        behavior = ai_config:get_map("behavior") or {},
        shortcuts = ai_config:get_map("shortcuts") or {}
    }
    
    -- 监听配置变化
    config_manager.setup_config_listeners(env)
end

function config_manager.get(section, key, default)
    local section_config = config_manager.config[section] or {}
    return section_config[key] or default
end

function config_manager.update_from_server(new_config)
    -- 从服务端接收配置更新
    for section, values in pairs(new_config) do
        if not config_manager.config[section] then
            config_manager.config[section] = {}
        end
        
        for key, value in pairs(values) do
            config_manager.config[section][key] = value
        end
    end
    
    -- 通知配置变化
    config_manager.notify_config_change()
end

function config_manager.notify_config_change()
    -- 通知其他组件配置已变化
    local context = rime_api.get_current_context()
    if context then
        context:set_property("config_updated", "true")
    end
end
```

### 9.3 配置验证与错误处理

#### 9.3.1 配置验证器
```python
from jsonschema import validate, ValidationError

class ConfigValidator:
    """配置验证器"""
    
    def __init__(self):
        self.schemas = self._load_schemas()
        
    def _load_schemas(self):
        """加载配置模式定义"""
        return {
            'global': {
                'type': 'object',
                'properties': {
                    'ai_system': {
                        'type': 'object',
                        'properties': {
                            'version': {'type': 'string'},
                            'enabled': {'type': 'boolean'},
                            'server': {
                                'type': 'object',
                                'properties': {
                                    'host': {'type': 'string'},
                                    'port': {'type': 'integer', 'minimum': 1, 'maximum': 65535},
                                    'timeout': {'type': 'integer', 'minimum': 1}
                                },
                                'required': ['host', 'port']
                            }
                        },
                        'required': ['version', 'enabled']
                    }
                },
                'required': ['ai_system']
            },
            'user': {
                'type': 'object',
                'properties': {
                    'user_preferences': {
                        'type': 'object',
                        'properties': {
                            'display': {'type': 'object'},
                            'interaction': {'type': 'object'},
                            'custom_triggers': {'type': 'object'}
                        }
                    }
                }
            }
        }
    
    def validate_config(self, config_type, config_data):
        """验证配置数据"""
        try:
            schema = self.schemas.get(config_type)
            if schema:
                validate(instance=config_data, schema=schema)
            return True, None
        except ValidationError as e:
            return False, f"配置验证失败: {e.message}"
    
    def fix_config_errors(self, config_type, config_data):
        """自动修复配置错误"""
        fixed_config = config_data.copy()
        
        # 根据配置类型进行特定修复
        if config_type == 'global':
            fixed_config = self._fix_global_config(fixed_config)
        elif config_type == 'user':
            fixed_config = self._fix_user_config(fixed_config)
            
        return fixed_config
    
    def _fix_global_config(self, config):
        """修复全局配置"""
        # 确保必需字段存在
        if 'ai_system' not in config:
            config['ai_system'] = {}
            
        ai_system = config['ai_system']
        
        # 设置默认值
        if 'version' not in ai_system:
            ai_system['version'] = '1.0'
        if 'enabled' not in ai_system:
            ai_system['enabled'] = True
        if 'server' not in ai_system:
            ai_system['server'] = {
                'host': '127.0.0.1',
                'port': 10086,
                'timeout': 30
            }
            
        return config
```

---

## 10. 异常处理与容错机制

### 10.1 分层异常处理策略

#### 10.1.1 Rime端异常处理
```lua
-- Rime端异常处理模块
local exception_handler = {}

function exception_handler.safe_call(func, context, ...)
    local ok, result = pcall(func, ...)
    
    if not ok then
        -- 记录错误
        logger.error("Rime端异常: " .. tostring(result))
        
        -- 恢复上下文状态
        exception_handler.recover_context(context)
        
        -- 通知用户
        exception_handler.show_error_message(context, "操作失败，请重试")
        
        return nil
    end
    
    return result
end

function exception_handler.recover_context(context)
    -- 清理AI相关属性
    local ai_properties = {
        "ai_state", "ai_session_id", "ai_stream_content", 
        "ai_talk_option", "get_ai_stream"
    }
    
    for _, prop in ipairs(ai_properties) do
        context:set_property(prop, "")
    end
    
    -- 重置输入状态
    if context:is_composing() then
        context:clear()
    end
end

function exception_handler.show_error_message(context, message)
    -- 在候选词中显示错误信息
    local error_candidate = Candidate("error", 0, 0, 
                                     "❌ " .. message, "AI服务异常")
    -- 注意：这里需要通过特定机制插入候选词
    context:set_property("error_message", message)
end

-- 网络异常处理
function exception_handler.handle_network_error(context, error_type)
    local error_messages = {
        timeout = "AI服务响应超时",
        connection_refused = "无法连接到AI服务",
        connection_lost = "与AI服务的连接中断"
    }
    
    local message = error_messages[error_type] or "网络异常"
    exception_handler.show_error_message(context, message)
    
    -- 尝试重连
    tcp_socket.attempt_reconnect()
end
```

#### 10.1.2 Python服务端异常处理
```python
import traceback
import asyncio
from enum import Enum
from typing import Optional, Dict, Any

class ErrorType(Enum):
    NETWORK_ERROR = "network_error"
    AI_SERVICE_ERROR = "ai_service_error"
    VALIDATION_ERROR = "validation_error"
    SYSTEM_ERROR = "system_error"
    TIMEOUT_ERROR = "timeout_error"

class AIExceptionHandler:
    """AI服务异常处理器"""
    
    def __init__(self, logger):
        self.logger = logger
        self.error_counts = {}
        self.max_retries = 3
        
    async def handle_exception(self, error: Exception, context: Dict[str, Any]) -> Dict[str, Any]:
        """统一异常处理入口"""
        error_type = self._classify_error(error)
        error_id = self._generate_error_id()
        
        # 记录错误
        self.logger.error(f"异常[{error_id}]: {error_type.value}", exc_info=True)
        
        # 更新错误统计
        self._update_error_stats(error_type)
        
        # 生成错误响应
        response = await self._generate_error_response(error_type, error, context)
        response['error_id'] = error_id
        
        return response
    
    def _classify_error(self, error: Exception) -> ErrorType:
        """异常分类"""
        if isinstance(error, (ConnectionError, TimeoutError)):
            return ErrorType.NETWORK_ERROR
        elif isinstance(error, asyncio.TimeoutError):
            return ErrorType.TIMEOUT_ERROR
        elif isinstance(error, ValueError):
            return ErrorType.VALIDATION_ERROR
        elif "API" in str(error) or "model" in str(error).lower():
            return ErrorType.AI_SERVICE_ERROR
        else:
            return ErrorType.SYSTEM_ERROR
    
    async def _generate_error_response(self, error_type: ErrorType, 
                                     error: Exception, context: Dict[str, Any]) -> Dict[str, Any]:
        """生成错误响应"""
        base_response = {
            'success': False,
            'error_type': error_type.value,
            'timestamp': time.time(),
            'context': context
        }
        
        if error_type == ErrorType.AI_SERVICE_ERROR:
            return {
                **base_response,
                'message': 'AI服务暂时不可用',
                'suggestion': '请稍后重试或切换AI模型',
                'retry_after': 60,
                'fallback_available': True
            }
        elif error_type == ErrorType.NETWORK_ERROR:
            return {
                **base_response,
                'message': '网络连接异常',
                'suggestion': '请检查网络连接',
                'retry_after': 30,
                'fallback_available': False
            }
        elif error_type == ErrorType.TIMEOUT_ERROR:
            return {
                **base_response,
                'message': 'AI响应超时',
                'suggestion': '请重新发送请求',
                'retry_after': 5,
                'fallback_available': True
            }
        else:
            return {
                **base_response,
                'message': '系统内部错误',
                'suggestion': '请联系技术支持',
                'retry_after': 300,
                'fallback_available': False
            }

class RetryManager:
    """重试管理器"""
    
    def __init__(self, max_retries=3, backoff_factor=2):
        self.max_retries = max_retries
        self.backoff_factor = backoff_factor
        
    async def execute_with_retry(self, func, *args, **kwargs):
        """带重试的函数执行"""
        last_exception = None
        
        for attempt in range(self.max_retries + 1):
            try:
                return await func(*args, **kwargs)
            except Exception as e:
                last_exception = e
                
                if attempt < self.max_retries:
                    wait_time = (self.backoff_factor ** attempt)
                    logger.warning(f"第{attempt + 1}次尝试失败，{wait_time}秒后重试: {e}")
                    await asyncio.sleep(wait_time)
                else:
                    logger.error(f"重试{self.max_retries}次后仍然失败: {e}")
        
        raise last_exception

class FallbackService:
    """备用服务"""
    
    def __init__(self):
        self.fallback_responses = {
            'chat': '抱歉，AI服务暂时不可用，请稍后重试。',
            'translate': '翻译服务暂时不可用，请使用在线翻译工具。',
            'code': '代码助手暂时不可用，请查阅相关文档。'
        }
        
    async def get_fallback_response(self, request_type: str, original_request: str) -> str:
        """获取备用响应"""
        base_response = self.fallback_responses.get(request_type, '服务暂时不可用。')
        
        # 可以根据请求内容生成更智能的备用响应
        if request_type == 'translate' and self._detect_language(original_request):
            return f"无法翻译"{original_request[:50]}..."，请稍后重试。"
        
        return base_response
    
    def _detect_language(self, text: str) -> bool:
        """简单的语言检测"""
        chinese_chars = sum(1 for c in text if '\u4e00' <= c <= '\u9fff')
        return chinese_chars > len(text) * 0.3
```

### 10.2 容错机制设计

#### 10.2.1 服务降级策略
```python
class ServiceDegradationManager:
    """服务降级管理器"""
    
    def __init__(self):
        self.service_health = {}
        self.degradation_levels = {
            'normal': 0,      # 正常服务
            'limited': 1,     # 限制服务
            'essential': 2,   # 基础服务
            'emergency': 3    # 应急模式
        }
        
    def check_service_health(self, service_name: str) -> int:
        """检查服务健康状态"""
        health_info = self.service_health.get(service_name, {})
        error_rate = health_info.get('error_rate', 0)
        response_time = health_info.get('avg_response_time', 0)
        
        # 根据错误率和响应时间确定降级级别
        if error_rate > 0.5 or response_time > 30:
            return self.degradation_levels['emergency']
        elif error_rate > 0.3 or response_time > 15:
            return self.degradation_levels['essential']
        elif error_rate > 0.1 or response_time > 10:
            return self.degradation_levels['limited']
        else:
            return self.degradation_levels['normal']
    
    async def handle_degraded_request(self, request: AIRequest, degradation_level: int):
        """处理降级请求"""
        if degradation_level == self.degradation_levels['emergency']:
            # 应急模式：仅返回预设响应
            return await self._emergency_response(request)
        elif degradation_level == self.degradation_levels['essential']:
            # 基础服务：使用本地模型或缓存
            return await self._essential_service(request)
        elif degradation_level == self.degradation_levels['limited']:
            # 限制服务：减少功能，提高成功率
            return await self._limited_service(request)
        else:
            # 正常服务
            return await self._normal_service(request)
    
    async def _emergency_response(self, request: AIRequest):
        """应急响应"""
        fallback_service = FallbackService()
        return await fallback_service.get_fallback_response(
            request.mode.value, request.content
        )
    
    async def _essential_service(self, request: AIRequest):
        """基础服务"""
        # 尝试使用本地缓存或简化的本地模型
        cache_response = await self._check_cache(request)
        if cache_response:
            return cache_response
        
        # 使用轻量级本地模型
        return await self._use_local_model(request)
    
    async def _limited_service(self, request: AIRequest):
        """限制服务"""
        # 减少AI调用的复杂度
        simplified_request = self._simplify_request(request)
        return await self._normal_service(simplified_request)
```

#### 10.2.2 数据备份与恢复
```python
class DataBackupManager:
    """数据备份管理器"""
    
    def __init__(self, backup_dir: str):
        self.backup_dir = backup_dir
        self.session_backup = {}
        
    async def backup_session_state(self, session_id: str, state_data: Dict[str, Any]):
        """备份会话状态"""
        backup_file = os.path.join(self.backup_dir, f"session_{session_id}.json")
        
        try:
            with open(backup_file, 'w', encoding='utf-8') as f:
                json.dump({
                    'session_id': session_id,
                    'timestamp': time.time(),
                    'state_data': state_data
                }, f, ensure_ascii=False, indent=2)
                
            logger.debug(f"会话状态已备份: {session_id}")
        except Exception as e:
            logger.error(f"备份会话状态失败: {e}")
    
    async def restore_session_state(self, session_id: str) -> Optional[Dict[str, Any]]:
        """恢复会话状态"""
        backup_file = os.path.join(self.backup_dir, f"session_{session_id}.json")
        
        try:
            if os.path.exists(backup_file):
                with open(backup_file, 'r', encoding='utf-8') as f:
                    backup_data = json.load(f)
                    
                # 检查备份时间是否过期（24小时）
                backup_time = backup_data.get('timestamp', 0)
                if time.time() - backup_time < 86400:
                    logger.info(f"成功恢复会话状态: {session_id}")
                    return backup_data.get('state_data')
                else:
                    # 删除过期备份
                    os.remove(backup_file)
                    
        except Exception as e:
            logger.error(f"恢复会话状态失败: {e}")
            
        return None
    
    async def cleanup_old_backups(self, max_age_hours: int = 24):
        """清理旧备份文件"""
        current_time = time.time()
        max_age_seconds = max_age_hours * 3600
        
        try:
            for filename in os.listdir(self.backup_dir):
                if filename.startswith('session_') and filename.endswith('.json'):
                    file_path = os.path.join(self.backup_dir, filename)
                    file_age = current_time - os.path.getmtime(file_path)
                    
                    if file_age > max_age_seconds:
                        os.remove(file_path)
                        logger.debug(f"删除过期备份: {filename}")
                        
        except Exception as e:
            logger.error(f"清理备份文件失败: {e}")
```

---

## 11. 性能优化策略

### 11.1 响应速度优化

#### 11.1.1 连接池管理
```python
import aiohttp
import asyncio
from typing import Dict, Optional

class ConnectionPoolManager:
    """连接池管理器"""
    
    def __init__(self):
        self.pools = {}
        self.max_connections = 100
        self.max_keepalive_connections = 30
        
    async def get_session(self, provider: str) -> aiohttp.ClientSession:
        """获取连接会话"""
        if provider not in self.pools:
            connector = aiohttp.TCPConnector(
                limit=self.max_connections,
                limit_per_host=self.max_keepalive_connections,
                keepalive_timeout=30,
                enable_cleanup_closed=True
            )
            
            timeout = aiohttp.ClientTimeout(total=30, connect=5)
            
            self.pools[provider] = aiohttp.ClientSession(
                connector=connector,
                timeout=timeout
            )
            
        return self.pools[provider]
    
    async def close_all(self):
        """关闭所有连接池"""
        for session in self.pools.values():
            await session.close()
        self.pools.clear()

class RequestOptimizer:
    """请求优化器"""
    
    def __init__(self):
        self.request_cache = {}
        self.pending_requests = {}
        
    async def optimize_request(self, request: AIRequest) -> Dict[str, Any]:
        """优化AI请求"""
        # 请求去重
        request_key = self._generate_request_key(request)
        
        if request_key in self.pending_requests:
            # 等待已有的相同请求完成
            logger.debug("发现重复请求，等待现有请求完成")
            return await self.pending_requests[request_key]
        
        # 检查缓存
        cached_response = await self._check_cache(request_key)
        if cached_response:
            logger.debug("使用缓存响应")
            return cached_response
        
        # 创建新请求的Future
        future = asyncio.Future()
        self.pending_requests[request_key] = future
        
        try:
            # 执行请求
            response = await self._execute_request(request)
            
            # 缓存响应
            await self._cache_response(request_key, response)
            
            # 设置结果
            future.set_result(response)
            return response
            
        except Exception as e:
            future.set_exception(e)
            raise
        finally:
            # 清理pending请求
            self.pending_requests.pop(request_key, None)
    
    def _generate_request_key(self, request: AIRequest) -> str:
        """生成请求键"""
        import hashlib
        content = f"{request.mode.value}:{request.content}:{request.config}"
        return hashlib.md5(content.encode()).hexdigest()
```

#### 11.1.2 流式响应优化
```python
class StreamOptimizer:
    """流式响应优化器"""
    
    def __init__(self):
        self.buffer_size = 1024
        self.flush_interval = 0.1  # 100ms
        
    async def optimize_stream(self, ai_stream, callback):
        """优化流式响应"""
        buffer = ""
        last_flush = time.time()
        
        async for chunk in ai_stream:
            buffer += chunk
            current_time = time.time()
            
            # 根据缓冲区大小或时间间隔决定是否刷新
            should_flush = (
                len(buffer) >= self.buffer_size or
                current_time - last_flush >= self.flush_interval or
                self._is_natural_break_point(buffer)
            )
            
            if should_flush:
                await callback(buffer)
                buffer = ""
                last_flush = current_time
        
        # 发送剩余内容
        if buffer:
            await callback(buffer)
    
    def _is_natural_break_point(self, text: str) -> bool:
        """检测自然断点"""
        natural_breaks = ['。', '！', '？', '\n', '. ', '! ', '? ']
        return any(text.endswith(break_char) for break_char in natural_breaks)

class ResponseCompressor:
    """响应压缩器"""
    
    def __init__(self):
        self.compression_threshold = 500  # 字节
        
    def compress_response(self, content: str) -> bytes:
        """压缩响应内容"""
        if len(content.encode()) > self.compression_threshold:
            import gzip
            return gzip.compress(content.encode('utf-8'))
        return content.encode('utf-8')
    
    def decompress_response(self, data: bytes) -> str:
        """解压响应内容"""
        try:
            import gzip
            return gzip.decompress(data).decode('utf-8')
        except:
            return data.decode('utf-8')
```

### 11.2 内存优化

#### 11.2.1 内存监控和清理
```python
import psutil
import gc
from typing import Dict, Any

class MemoryManager:
    """内存管理器"""
    
    def __init__(self, max_memory_mb: int = 512):
        self.max_memory_mb = max_memory_mb
        self.cleanup_threshold = 0.8  # 80%使用率时开始清理
        self.monitoring_interval = 30  # 秒
        
    async def start_monitoring(self):
        """开始内存监控"""
        while True:
            await asyncio.sleep(self.monitoring_interval)
            await self._check_memory_usage()
    
    async def _check_memory_usage(self):
        """检查内存使用情况"""
        process = psutil.Process()
        memory_info = process.memory_info()
        memory_mb = memory_info.rss / 1024 / 1024
        
        usage_ratio = memory_mb / self.max_memory_mb
        
        logger.debug(f"内存使用: {memory_mb:.1f}MB ({usage_ratio:.1%})")
        
        if usage_ratio > self.cleanup_threshold:
            logger.warning(f"内存使用率过高: {usage_ratio:.1%}")
            await self._perform_cleanup()
    
    async def _perform_cleanup(self):
        """执行内存清理"""
        # 清理会话缓存
        session_manager.cleanup_expired_sessions()
        
        # 清理响应缓存
        cache_manager.cleanup_old_entries()
        
        # 强制垃圾回收
        gc.collect()
        
        logger.info("内存清理完成")

class CacheManager:
    """缓存管理器"""
    
    def __init__(self, max_cache_size: int = 1000):
        self.max_cache_size = max_cache_size
        self.cache = {}
        self.access_times = {}
        
    async def get(self, key: str) -> Optional[Any]:
        """获取缓存项"""
        if key in self.cache:
            self.access_times[key] = time.time()
            return self.cache[key]
        return None
    
    async def set(self, key: str, value: Any, ttl: int = 3600):
        """设置缓存项"""
        # 检查缓存大小限制
        if len(self.cache) >= self.max_cache_size:
            await self._evict_lru_items()
        
        self.cache[key] = {
            'value': value,
            'created_at': time.time(),
            'ttl': ttl
        }
        self.access_times[key] = time.time()
    
    async def _evict_lru_items(self):
        """清理最少使用的缓存项"""
        # 移除10%的最少使用项
        items_to_remove = max(1, len(self.cache) // 10)
        
        # 按访问时间排序
        sorted_items = sorted(self.access_times.items(), key=lambda x: x[1])
        
        for key, _ in sorted_items[:items_to_remove]:
            self.cache.pop(key, None)
            self.access_times.pop(key, None)
    
    def cleanup_old_entries(self):
        """清理过期缓存项"""
        current_time = time.time()
        expired_keys = []
        
        for key, cache_item in self.cache.items():
            if current_time - cache_item['created_at'] > cache_item['ttl']:
                expired_keys.append(key)
        
        for key in expired_keys:
            self.cache.pop(key, None)
            self.access_times.pop(key, None)
        
        if expired_keys:
            logger.debug(f"清理了{len(expired_keys)}个过期缓存项")
```

### 11.3 网络优化

#### 11.3.1 请求批处理
```python
class RequestBatcher:
    """请求批处理器"""
    
    def __init__(self, batch_size: int = 5, batch_timeout: float = 0.5):
        self.batch_size = batch_size
        self.batch_timeout = batch_timeout
        self.pending_requests = []
        self.batch_timer = None
        
    async def add_request(self, request: AIRequest) -> Any:
        """添加请求到批次"""
        future = asyncio.Future()
        self.pending_requests.append((request, future))
        
        # 如果达到批次大小，立即处理
        if len(self.pending_requests) >= self.batch_size:
            await self._process_batch()
        else:
            # 设置定时器
            if self.batch_timer is None:
                self.batch_timer = asyncio.create_task(self._batch_timeout_handler())
        
        return await future
    
    async def _batch_timeout_handler(self):
        """批次超时处理"""
        await asyncio.sleep(self.batch_timeout)
        if self.pending_requests:
            await self._process_batch()
    
    async def _process_batch(self):
        """处理当前批次"""
        if not self.pending_requests:
            return
        
        batch = self.pending_requests[:]
        self.pending_requests.clear()
        
        if self.batch_timer:
            self.batch_timer.cancel()
            self.batch_timer = None
        
        # 并行处理批次中的所有请求
        tasks = []
        for request, future in batch:
            task = asyncio.create_task(self._process_single_request(request, future))
            tasks.append(task)
        
        await asyncio.gather(*tasks, return_exceptions=True)
    
    async def _process_single_request(self, request: AIRequest, future: asyncio.Future):
        """处理单个请求"""
        try:
            result = await ai_handler.process(request)
            future.set_result(result)
        except Exception as e:
            future.set_exception(e)
```

---

## 12. 实施计划

### 12.1 开发阶段规划

#### 12.1.1 第一阶段：基础架构（2-3周）
```markdown
**目标：建立基本的通信框架和核心组件**

任务清单：
□ 搭建Python服务端基础架构
  - Socket服务器实现
  - 基础消息协议定义
  - 配置管理系统
  - 日志系统集成

□ 开发Rime端核心组件
  - ai_segmentor.lua 基础版本
  - ai_translator.lua 基础版本  
  - ai_processor.lua 基础版本
  - Socket通信模块

□ 实现基础AI集成
  - OpenAI API客户端
  - 简单对话功能
  - 错误处理机制

□ 建立测试环境
  - 单元测试框架
  - 集成测试环境
  - 性能测试工具

交付物：
- 可工作的基础系统原型
- 支持"a:"触发器的简单对话功能
- 基础文档和测试用例
```

#### 12.1.2 第二阶段：功能扩展（3-4周）
```markdown
**目标：实现主要AI功能模式**

任务清单：
□ 翻译功能模块
  - 智能语言检测
  - 多语言翻译支持
  - 格式保持翻译
  - 翻译质量优化

□ Agent功能模块
  - 编程助手Agent
  - 写作助手Agent
  - 数学助手Agent
  - 角色扮演功能

□ 流式响应优化
  - 实时候选词更新
  - 响应内容缓冲
  - 用户体验优化

□ 配置系统完善
  - 触发器自定义
  - 用户偏好设置
  - 热配置重载

交付物：
- 完整的AI功能模式
- 可配置的触发器系统
- 优化的用户交互体验
```

#### 12.1.3 第三阶段：用户体验优化（2-3周）
```markdown
**目标：完善用户交互和系统稳定性**

任务清单：
□ 交互体验优化
  - 多行内容处理
  - 剪贴板集成
  - 快捷键操作
  - 候选词管理

□ 异常处理完善
  - 网络异常处理
  - AI服务异常处理
  - 数据备份恢复
  - 服务降级策略

□ 性能优化
  - 响应速度优化
  - 内存使用优化
  - 连接池管理
  - 请求缓存

□ 文档和帮助
  - 用户使用手册
  - 配置指南
  - 故障排除指南

交付物：
- 稳定可用的完整系统
- 完整的用户文档
- 性能测试报告
```

#### 12.1.4 第四阶段：发布准备（1-2周）
```markdown
**目标：准备生产环境发布**

任务清单：
□ 系统集成测试
  - 端到端测试
  - 压力测试
  - 兼容性测试
  - 安全性测试

□ 安装包制作
  - 自动安装脚本
  - 依赖环境检查
  - 配置向导
  - 卸载程序

□ 部署文档
  - 安装指南
  - 配置说明
  - 维护手册
  - API文档

□ 用户培训材料
  - 使用教程
  - 视频演示
  - 常见问题解答
  - 最佳实践指南

交付物：
- 生产就绪的系统
- 完整的部署包
- 用户培训材料
```

### 12.2 技术栈选择

#### 12.2.1 Rime端技术栈
```yaml
核心技术:
  - Lua 5.4+: 脚本语言
  - Rime框架: 输入法引擎
  - LuaSocket: 网络通信
  - json.lua: JSON处理

开发工具:
  - VS Code: 开发环境
  - Lua Language Server: 语言支持
  - Git: 版本控制

测试工具:
  - busted: Lua测试框架
  - 手动集成测试
```

#### 12.2.2 Python服务端技术栈
```yaml
核心技术:
  - Python 3.9+: 主要开发语言
  - asyncio: 异步编程
  - aiohttp: HTTP客户端
  - websockets: WebSocket支持
  - pydantic: 数据验证
  - PyYAML: 配置文件处理

AI集成:
  - openai: OpenAI API客户端
  - anthropic: Claude API客户端
  - httpx: HTTP请求库

系统集成:
  - pyperclip: 剪贴板操作
  - pynput: 键盘鼠标控制
  - psutil: 系统监控
  - watchdog: 文件监控

开发工具:
  - Poetry: 依赖管理
  - Black: 代码格式化
  - Pylint: 代码检查
  - pytest: 测试框架
  - mypy: 类型检查

部署工具:
  - PyInstaller: 打包工具
  - Docker: 容器化(可选)
```

### 12.3 质量保证计划

#### 12.3.1 测试策略
```python
class TestStrategy:
    """测试策略定义"""
    
    def unit_tests(self):
        """单元测试"""
        return {
            'coverage_target': 80,
            'frameworks': ['pytest', 'busted'],
            'focus_areas': [
                'AI请求处理',
                '消息协议',
                '配置管理',
                '异常处理'
            ]
        }
    
    def integration_tests(self):
        """集成测试"""
        return {
            'test_scenarios': [
                'Rime与Python服务端通信',
                'AI API集成',
                '配置热重载',
                '会话状态管理'
            ],
            'test_environments': [
                'macOS',
                'Windows', 
                'Linux'
            ]
        }
    
    def performance_tests(self):
        """性能测试"""
        return {
            'metrics': [
                '响应时间 < 2秒',
                '内存使用 < 512MB',
                '并发处理 > 10个请求',
                'CPU使用率 < 30%'
            ],
            'load_testing': '模拟100个并发用户'
        }
```

#### 12.3.2 代码质量标准
```yaml
代码规范:
  Python:
    - 遵循PEP 8规范
    - 使用类型注解
    - 文档字符串覆盖率 > 90%
    - 代码复杂度 < 10
    
  Lua:
    - 遵循Lua风格指南
    - 函数注释完整
    - 变量命名清晰
    - 模块结构规范

质量检查:
  - 代码审查: 所有PR必须经过审查
  - 自动化检查: CI/CD流水线
  - 安全扫描: 依赖漏洞检查
  - 性能分析: 定期性能测试
```

### 12.4 风险评估与应对

#### 12.4.1 技术风险
```markdown
**高风险项目：**

1. AI API稳定性
   - 风险：第三方AI服务不稳定
   - 应对：实现多AI提供商支持，本地备用模型

2. Rime框架兼容性
   - 风险：不同版本Rime行为差异
   - 应对：建立兼容性测试矩阵，向下兼容

3. 性能瓶颈
   - 风险：大量并发请求导致性能问题
   - 应对：连接池管理，请求批处理，缓存策略

**中风险项目：**

1. 网络连接问题
   - 风险：网络中断影响功能
   - 应对：重连机制，离线模式

2. 配置复杂性
   - 风险：用户配置错误导致功能异常
   - 应对：配置验证，默认配置，向导式配置
```

#### 12.4.2 项目风险
```markdown
**进度风险：**
- 开发时间估算偏差
- 技术难点超出预期
- 测试发现重大问题

**应对策略：**
- 敏捷开发，迭代交付
- 技术预研，风险前置
- 持续集成，早期发现问题

**资源风险：**
- 开发人员不足
- AI API成本控制
- 测试设备不足

**应对策略：**
- 合理分工，技能互补
- 成本监控，用量控制
- 云端测试环境
```

---

## 总结

本研究报告详细分析了Rime输入法与大模型交互系统的完整实现方案。该系统通过创新的触发标识符机制，将强大的AI能力无缝集成到日常输入体验中，为用户提供了智能对话、翻译、编程助手等多种AI功能。

### 核心创新点

1. **无缝集成架构**：通过Socket通信实现Rime与AI服务的实时交互
2. **灵活触发机制**：可配置的触发标识符系统，支持多种AI功能模式
3. **智能上屏策略**：针对多行AI回复的特殊处理，避免输入法限制
4. **流式响应体验**：实时更新候选词，提供流畅的AI交互体验
5. **完善的容错机制**：多层异常处理和服务降级策略

### 技术优势

- **高性能**：连接池管理、请求缓存、批处理优化
- **高可靠**：异常处理、重试机制、数据备份
- **高扩展**：模块化设计、插件架构、配置驱动
- **高兼容**：跨平台支持、多AI模型集成

### 应用前景

该系统不仅提升了输入法的智能化水平，更开创了输入法与AI深度融合的新模式。未来可扩展至更多AI能力，如图像识别、语音交互、知识图谱等，为用户打造真正智能的输入助手。

通过本报告的实施方案，可以构建一个功能完整、性能优秀、用户体验出色的Rime AI交互系统，为输入法技术的发展提供重要参考。

---

**报告完成日期：** 2025年7月27日  
**文档版本：** 1.0  
**技术支持：** Rime万象输入法团队
