-- 引入日志工具模块
local logger_module = require("logger")
-- 引入文本切分模块
local text_splitter = require("text_splitter")
-- 引入spans管理模块
local spans_manager = require("spans_manager")

-- 创建当前模块的日志记录器
local logger = logger_module.create("test_quotes", {
    enabled = true, -- 启用日志以便测试
    unique_file_log = false, -- 启用日志以便测试
    log_level = "DEBUG"
})

local function extract_leading_chinese(text)
    -- 最高效的方法：反向查找最后一个中文字符的位置
    local last_pos = 0
    local pos = 1

    -- 使用string.find从前往后查找所有中文字符，记录最后一个位置
    while true do
        local start_pos, end_pos = text:find("[\228-\233][\128-\191][\128-\191]", pos)
        if not start_pos then
            break
        end
        last_pos = end_pos
        pos = end_pos + 1
    end

    -- 如果找到中文字符，返回从开头到最后一个中文字符的部分
    if last_pos > 0 then
        return text:sub(1, last_pos)
    end

    -- 如果没有中文字符，返回空字符串
    return ""
end

-- 测试函数
local function test_extract_leading_chinese()
    print("开始测试 extract_leading_chinese 函数")

    -- 测试用例
    local test_cases = {"我们只dk ve ui", -- 期望: "我们只"
    "hello世界test", -- 期望: "hello世界"  
    "你好世界abc def", -- 期望: "你好世界"
    "abc我们only", -- 期望: "abc我们"
    "我们", -- 期望: "我们"
    "hello world", -- 期望: "hello world" (无中文)
    "123我们456", -- 期望: "123我们"
    "我们的world很beautiful" -- 期望: "我们的"
    }

    for i, test_input in ipairs(test_cases) do
        local result = extract_leading_chinese(test_input)
        print("测试用例 " .. i .. ": 输入='" .. test_input .. "' -> 输出='" .. result .. "'")
    end

    print("测试完成")
end

-- 执行测试
test_extract_leading_chinese()


local select_key_index = string.find("12345", "1", 1, true)
print(select_key_index)