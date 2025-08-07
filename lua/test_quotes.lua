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

-- 英文标点符号到中文标点符号的映射表
local punct_map = {
    [","] = "，", -- 逗号
    ["."] = "。", -- 句号
    ["?"] = "？", -- 问号  
    ["!"] = "！", -- 感叹号
    [":"] = "：", -- 冒号
    [";"] = "；", -- 分号
    ["("] = "（", -- 左括号
    [")"] = "）", -- 右括号
    -- ["["] = "【",    -- 左方括号
    -- ["]"] = "】",    -- 右方括号
    ["{"] = "｛", -- 左花括号
    ["}"] = "｝", -- 右花括号
    ["<"] = "《", -- 左书名号
    [">"] = "》" -- 右书名号
}

-- 成对引号的映射表
local quote_map = {
    ["\""] = {"“", "”"}, -- 双引号：前引号、后引号
    ["'"] = {"‘", "’"} -- 单引号：前引号、后引号
}

-- 执行测试
test_extract_leading_chinese()


local function replace_quotes(text)

    local result = text

    -- 处理双引号
    local double_quote_open = true -- 跟踪双引号状态，true表示下一个是开引号
    result = result:gsub("\"", function()
        if double_quote_open then
            double_quote_open = false
            return "“" -- 前引号
        else
            double_quote_open = true
            return "”" -- 后引号
        end
    end)

    -- -- 处理单引号, 因为单引号是音节分隔符, 所以这里不能使用单引号. 
    -- local single_quote_open = true  -- 跟踪单引号状态，true表示下一个是开引号
    -- result = result:gsub("'", function()
    --     if single_quote_open then
    --         single_quote_open = false
    --         return "‘"  -- 前引号
    --     else
    --         single_quote_open = true
    --         return "’"  -- 后引号
    --     end
    -- end)

    return result
end

-- 标点符号替换函数
local function replace_punct(text)
    if not text or text == "" then
        return text
    end

    local result = text

    -- 先处理成对引号
    result = replace_quotes(result)

    -- 再处理其他标点符号
    for eng_punct, chn_punct in pairs(punct_map) do
        result = result:gsub(eng_punct:gsub("([%(%)%.%+%-%*%?%[%]%^%$%%])", "%%%1"), chn_punct)
    end

    return result
end


print(replace_punct("你好\"我\""))