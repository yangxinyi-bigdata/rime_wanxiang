# text_splitter 模块使用指南

## 概述
`text_splitter.lua` 是一个用于智能切分包含反引号和标点符号的文本的Lua模块。

## 功能特性
- 支持多对反引号的智能切分
- 支持未配对反引号的处理
- 支持各种标点符号的识别和切分
- 保留反引号内容不被标点符号切分
- 提供带日志记录和不带日志记录两个版本

## 安装使用

### 1. 引入模块
```lua
local text_splitter = require("text_splitter")
```

### 2. 基本使用（无日志）
```lua
local input = "hello,`world`!how-are_you"
local segments = text_splitter.split_and_convert_input(input)

-- segments 是一个表，包含切分后的片段
-- 每个片段格式：{type = "类型", content = "内容"}
-- 类型可能是：
--   "text" - 普通文本
--   "punct" - 标点符号
--   "backtick" - 反引号内容
```

### 3. 带日志记录的使用
```lua
local log = require("log")
log.level = "info"
log.outfile = "path/to/your/logfile.log"

local input = "function`getName`()=>name"
local segments = text_splitter.split_and_convert_input_with_log(input, log)
```

### 4. 在其他模块中使用
如在 `baidu_filter.lua` 中：
```lua
-- 在文件开头引入
local text_splitter = require("text_splitter")

-- 在函数中使用
local function process_input(input, logger)
    local segments = text_splitter.split_and_convert_input_with_log(input, logger)
    
    -- 处理切分后的片段
    for i, seg in ipairs(segments) do
        if seg.type == "text" then
            -- 处理普通文本（如双拼转全拼）
        elseif seg.type == "backtick" then
            -- 处理反引号内容（保持原样）
        elseif seg.type == "punct" then
            -- 处理标点符号
        end
    end
    
    return segments
end
```

## 切分规则

### 反引号处理
- 配对的反引号：`hello`world`` → ["hello", "world"]
- 未配对的反引号：`hello`world`end` → ["hello", "world", "end"]
- 空反引号：`hello``world` → ["hello", "", "world"]

### 标点符号识别
支持的标点符号包括：`,`, `.`, `!`, `?`, `;`, `:`, `(`, `)`, `[`, `]`, `<`, `>`, `/`, `_`, `=`, `+`, `*`, `&`, `^`, `%`, `$`, `#`, `@`, `~`, `|`, `\`, `-`

### 切分示例
```
输入: "hello,`world`!how-are_you"
输出:
  片段1: 类型=text, 内容='hello'
  片段2: 类型=punct, 内容=','
  片段3: 类型=backtick, 内容='world'
  片段4: 类型=punct, 内容='!'
  片段5: 类型=text, 内容='how'
  片段6: 类型=punct, 内容='-'
  片段7: 类型=text, 内容='are'
  片段8: 类型=punct, 内容='_'
  片段9: 类型=text, 内容='you'
```

## API 参考

### text_splitter.split_and_convert_input(input)
基础版本，不记录日志。

**参数：**
- `input` (string): 待切分的输入字符串

**返回值：**
- `segments` (table): 切分后的片段数组

### text_splitter.split_and_convert_input_with_log(input, logger)
带日志记录版本。

**参数：**
- `input` (string): 待切分的输入字符串
- `logger` (table): 日志记录器对象（需要有info方法）

**返回值：**
- `segments` (table): 切分后的片段数组

## 注意事项
1. 模块文件需要放在Lua的搜索路径中
2. 日志记录器需要支持 `info` 方法
3. 反引号内的内容不会被进一步切分
4. 标点符号会被单独作为一个片段
