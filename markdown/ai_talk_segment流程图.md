# AI 对话分词器流程图

```mermaid
flowchart TD
    A[开始] --> B[segmentor.init 初始化]
    
    B --> B1[读取 schema 配置]
    B1 --> B2[读取 ai_assistant/enabled]
    B2 --> B3[读取 behavior 配置]
    B3 --> B4[读取 chat_triggers 配置]
    B4 --> B5[设置更新通知器]
    
    B5 --> C[等待用户输入]
    
    C --> D[segmentor.func 开始处理]
    
    D --> E{AI助手是否启用?}
    E -->|否| F[return true<br/>不处理，交给其他分词器]
    
    E -->|是| G{输入是否为AI回复}
    G -->|是| G1[创建 ai_reply 标签段落]
    G1 --> G2[return false<br/>处理完成]
    
    G -->|否| H[遍历所有触发器]
    
    H --> I{检查触发器匹配}
    I --> I1{输入等于触发器前缀<br/>如 input 等于 a:}
    I1 -->|是| I2[创建 ai_talk 标签段落]
    I2 --> I3[return false<br/>纯触发器处理完成]
    
    I1 -->|否| I4{输入匹配触发器前缀加字符模式<br/>如 input 等于 a:hello}
    I4 -->|是| I5[记录 matched_trigger 和 matched_prefix]
    I4 -->|否| I6[继续检查下一个触发器]
    
    I6 --> I7{还有触发器?}
    I7 -->|是| I
    I7 -->|否| J{找到匹配的触发器?}
    
    I5 --> J
    J -->|否| F
    
    J -->|是| K{是否已经处理过AI分词?}
    K -->|是| K1[return true<br/>跳过重复处理]
    
    K -->|否| L[开始分词处理]
    L --> L1[计算前缀长度]
    L1 --> L2[提取拼音部分]
    L2 --> L3[清空原有分割结果]
    L3 --> L4[创建 AI 前缀段落<br/>标签: ai_talk]
    L4 --> L5{是否有拼音部分?}
    
    L5 -->|否| L7[标记已处理]
    L5 -->|是| L6[创建拼音段落<br/>标签: abc]
    L6 --> L7
    L7 --> L8[return false<br/>分词完成]
    
    style B fill:#e1f5fe
    style D fill:#f3e5f5
    style L fill:#fff3e0