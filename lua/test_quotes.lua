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

local a = text_splitter.has_punctuation_no_backtick("你好", logger)
print(a)

-- 方法1: 使用表格查找方式替代正则表达式（当前方法）
local function has_chinese_punctuation_table(text)
    local chinese_puncts = {
        "，", "。", "？", "！", "：", "；", "（", "）", 
        "【", "】", "｛", "｝", "《", "》", "、", "……", 
        "—", "·", "〈", "〉", "「", "」", "『", "』", 
        "〔", "〕", "〖", "〗"
    }
    
    for _, punct in ipairs(chinese_puncts) do
        if string.find(text, punct, 1, true) then -- 使用plain text匹配
            return true
        end
    end
    return false
end

-- 方法2: 使用哈希表（Set）查找，避免循环
local function has_chinese_punctuation_set(text)
    -- 创建标点符号集合
    local punct_set = {
        ["，"] = true, ["。"] = true, ["？"] = true, ["！"] = true,
        ["："] = true, ["；"] = true, ["（"] = true, ["）"] = true,
        ["【"] = true, ["】"] = true, ["｛"] = true, ["｝"] = true,
        ["《"] = true, ["》"] = true, ["、"] = true, ["……"] = true,
        ["—"] = true, ["·"] = true, ["〈"] = true, ["〉"] = true,
        ["「"] = true, ["」"] = true, ["『"] = true, ["』"] = true,
        ["〔"] = true, ["〕"] = true, ["〖"] = true, ["〗"] = true
    }
    
    -- 遍历文本中的每个UTF-8字符
    for pos, code in utf8.codes(text) do
        local char = utf8.char(code)
        if punct_set[char] then
            return true
        end
    end
    return false
end

-- 方法3: 使用Unicode码点范围判断（最高效）
local function has_chinese_punctuation_unicode(text)
    for pos, code in utf8.codes(text) do
        -- 中文标点符号的Unicode范围
        if (code >= 0x3000 and code <= 0x303F) or  -- CJK符号和标点
           (code >= 0xFF00 and code <= 0xFFEF) then -- 全角ASCII、全角标点
            return true
        end
    end
    return false
end

-- 方法4: 使用字符串匹配组合（无循环版本）
local function has_chinese_punctuation_concat(text)
    -- 将所有标点符号连接成一个字符串，然后逐个检查
    local punct_chars = "，。？！：；（）【】｛｝《》、……—·〈〉「」『』〔〕〖〗"
    for pos, code in utf8.codes(text) do
        local char = utf8.char(code)
        if string.find(punct_chars, char, 1, true) then
            return true
        end
    end
    return false
end

-- 测试所有方法
print("=== 测试不同方法 ===")
local test_text = "你好"

print("方法1 (表格循环): " .. tostring(has_chinese_punctuation_table(test_text)))
print("方法2 (哈希表): " .. tostring(has_chinese_punctuation_set(test_text)))
print("方法3 (Unicode范围): " .. tostring(has_chinese_punctuation_unicode(test_text)))
print("方法4 (字符串匹配): " .. tostring(has_chinese_punctuation_concat(test_text)))

-- 测试包含标点的情况
local test_text_with_punct = "你好，世界！"
print("\n=== 测试包含标点的文本: " .. test_text_with_punct .. " ===")
print("方法1 (表格循环): " .. tostring(has_chinese_punctuation_table(test_text_with_punct)))
print("方法2 (哈希表): " .. tostring(has_chinese_punctuation_set(test_text_with_punct)))
print("方法3 (Unicode范围): " .. tostring(has_chinese_punctuation_unicode(test_text_with_punct)))
print("方法4 (字符串匹配): " .. tostring(has_chinese_punctuation_concat(test_text_with_punct)))
