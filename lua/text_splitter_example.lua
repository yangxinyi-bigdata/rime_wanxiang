-- 使用text_splitter模块的示例

local text_splitter = require("text_splitter")

-- 方法1：简单使用（无日志）
local function example_usage()
    local input = "hello,`world`!how-are_you"
    local segments = text_splitter.split_and_convert_input(input)
    
    print("输入: " .. input)
    print("切分结果:")
    for i, seg in ipairs(segments) do
        print(string.format("  片段%d: 类型=%s, 内容='%s'", i, seg.type, seg.content))
    end
end

-- 方法2：带日志记录的使用
local function example_usage_with_log()
    local log = require("log")
    log.level = "info"
    log.outfile = "/Users/yangxinyi/Library/Rime/log/text_splitter_example.log"
    log.usecolor = false
    
    local input = "function`getName`()=>name"
    local segments = text_splitter.split_and_convert_input_with_log(input, log)
    
    return segments
end

-- 运行示例
print("=== 简单使用示例 ===")
example_usage()

print("\n=== 带日志记录示例 ===")
local result = example_usage_with_log()
print("返回了 " .. #result .. " 个片段")
