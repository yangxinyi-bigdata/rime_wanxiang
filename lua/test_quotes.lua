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

local s = "ni hk wo de ge"
local pos = s:match(".*() ")
print(pos)

local temp_script_text = s:sub(1, pos)
print("移除一个音节，剩余script_text: '" .. temp_script_text .. "'")

-- 测试字符串切片
local test_string = " ok wo mf vi dk le uf me‸    ▶ [⇧+回车 AI转换]"
local start_pos = 13
local end_pos = 24

print("原始字符串: '" .. test_string .. "'")
print("字符串长度: " .. #test_string)
print("从位置 " .. start_pos .. " 到 " .. end_pos .. " 的切片:")

-- 使用最简单的字符串切片
local sliced_text = string.sub(test_string, start_pos, end_pos)
print("切片结果: '" .. sliced_text .. "'")

-- [2025-08-08 16:16:23] [INFO] [smart_cursor_processor:521] get_preedit.text:  ok 我们只dk le uf me‸    ▶ [⇧+回车 AI转换]  
-- [2025-08-08 16:16:23] [INFO] [smart_cursor_processor:522] caret_pos: 24
-- [2025-08-08 16:16:23] [INFO] [smart_cursor_processor:523] preedit.sel_start: 13
-- [2025-08-08 16:16:23] [INFO] [smart_cursor_processor:524] preedit.sel_end: 24

-- [2025-08-08 16:41:55] [INFO] [smart_cursor_processor:521] get_preedit.text: AI翻译: ok wo mf yi dy ngg‸    ▶ [⇧+回车 AI转换]  
-- [2025-08-08 16:41:55] [INFO] [smart_cursor_processor:522] caret_pos: 28
-- [2025-08-08 16:41:55] [INFO] [smart_cursor_processor:523] preedit.sel_start: 13
-- [2025-08-08 16:41:55] [INFO] [smart_cursor_processor:524] preedit.sel_end: 27

local test_string = "AI翻译: ok wo mf yi dy ngg‸    ▶ [⇧+回车 AI转换]"
local sliced_text = string.sub(test_string, 1, 27)
print(sliced_text)

local test_string = " ok 我们只dk le uf me‸    ▶ [⇧+回车 AI转换]"
local sliced_text = string.sub(test_string, 1, 24)
print(sliced_text)

-- 首先处理preedit_text，去除最后一个"‸"符号及其后面的内容
local preedit_text = " ok 我们只dk le uf me‸    ▶ [⇧+回车 AI转换]"
local cleaned_preedit_text = preedit_text
-- 使用简单的find查找‸符号位置，然后截取到该位置之前
local cursor_pos = preedit_text:find("‸")
if cursor_pos then
    cleaned_preedit_text = preedit_text:sub(1, cursor_pos - 1)
    print("去除光标符号及后续内容，原文本: '" .. preedit_text .. "', 处理后: '" ..
                     cleaned_preedit_text .. "'")
else
    print("没找到")
end


-- =============== split_by_rawenglish 空格场景测试 ===============
local function print_segments(label, input, segments)
    print("\n[split_by_rawenglish] " .. label)
    print("input: " .. input)
    for i, seg in ipairs(segments) do
        print(string.format("  #%d type=%s start=%d end=%d len=%d content='%s'", i, seg.type, seg.start, seg._end,
            seg.length, seg.content))
    end
end

local function run_rawenglish_test(input, seg_start, delimiter_before, delimiter_after)
    seg_start = seg_start or 0
    delimiter_before = delimiter_before or "`"
    delimiter_after = delimiter_after or "`"
    local segments = text_splitter.split_by_rawenglish(input, seg_start, #input, delimiter_before, delimiter_after)
    print_segments("seg_start=" .. tostring(seg_start), input, segments)
end

-- 1) 基本：英文片段内含单个空格
run_rawenglish_test("nihk`ok de`", 0)

-- 2) 英文片段内含多个连续空格
run_rawenglish_test("nihk`ok  de`", 0)

-- 3) 英文片段内含多个词与空格
run_rawenglish_test("nihk`ok de fg`", 0)

-- 4) 开头就是英文片段（含空格），后接中文拼音
run_rawenglish_test("`hello world`nihk", 0)

-- 5) 两个英文片段（都含空格）
run_rawenglish_test("ni`hello   world`hk`foo bar`", 0)

-- 6) 未闭合的英文片段（含空格）
run_rawenglish_test("ni`hello world", 0)

-- 7) 英文片段前后有空格与中文
run_rawenglish_test("ni `hello world` hk", 0)

-- 8) 原例：英文片段包含换行（也测试与空格混合）
run_rawenglish_test("nihk`ok\n de`", 0)