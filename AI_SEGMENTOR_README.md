# AI对话分词功能使用说明

## 功能概述

通过自定义 Lua 分词器实现 AI 对话功能。当输入 `a:nihk` 时：

1. `a:` 部分显示 "〔AI对话〕" 提示
2. `nihk` 部分正常进行拼音翻译，显示 "你好" 等候选词

## 工作机制

### 分词过程
```
输入: a:nihk
     ↓
ai_talk_segmentor 分析
     ↓
创建两个段落:
1. a: (标签: ai_talk)
2. nihk (标签: abc)
```

### 翻译过程
```
ai_talk 段落 → ai_talk_translator → 显示 "〔AI对话〕"
abc 段落     → script_translator   → 显示 "你好" 等拼音候选词
```

## 配置说明

### 1. Segmentor 配置
```yaml
segmentors:
  - lua_segmentor@*ai_talk_segmentor  # AI对话自定义分词器
  - abc_segmentor                     # 正常拼音分词器
```

### 2. Translator 配置
```yaml
translators:
  - lua_translator@*ai_talk_translator  # AI对话前缀翻译器
  - script_translator                   # 脚本翻译器
```

### 3. Recognizer 配置
```yaml
recognizer:
  patterns:
    ai_talk: "^a:.+$"  # 识别 a: 开头的输入
```

## 预期效果

当你输入 `a:nihk` 时：

```
候选词列表:
1. 〔AI对话〕        # 来自 ai_talk_translator
2. 你好              # 来自 script_translator 处理 nihk
3. 你好吗            # 其他拼音候选词
4. ...
```

## 测试方法

1. 保存配置文件
2. 重新部署方案: `Control+Option+Grave`
3. 输入 `a:nihk`
4. 观察候选词是否包含:
   - "〔AI对话〕" 提示
   - "你好" 等拼音候选词

## 调试信息

查看日志文件了解处理过程：
```
/Users/yangxinyi/Library/Rime/log/all_modules.log
```

日志会显示：
- 分词器的段落创建过程
- 翻译器的候选词生成过程

## 优势

1. **精确分割**: `a:` 和拼音部分分别处理
2. **保持兼容**: 拼音部分使用标准的 `abc` 标签
3. **灵活扩展**: 可以轻松添加更多AI功能
4. **性能优化**: 只在需要时激活AI处理

## 下一步扩展

1. **AI回答生成**: 基于拼音内容生成智能回答
2. **上下文记忆**: 保存对话历史
3. **多轮对话**: 支持连续AI对话
4. **自定义触发**: 支持更多触发模式
