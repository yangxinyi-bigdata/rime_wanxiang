-- 测试标点符号检测逻辑
local function test_punctuation_detection()
    local test_cases = {
        {input = "hello", expected = false, desc = "纯英文字母"},
        {input = "helloworld", expected = false, desc = "纯英文字母长串"},
        {input = "hello,world", expected = true, desc = "包含逗号"},
        {input = "hello`world", expected = true, desc = "包含反引号"},
        {input = "hello.world", expected = true, desc = "包含句号"},
        {input = "hello!world", expected = true, desc = "包含感叹号"},
        {input = "hello-world", expected = true, desc = "包含连字符"},
        {input = "hello_world", expected = true, desc = "包含下划线"},
        {input = "hello123", expected = false, desc = "字母加数字"},
        {input = "hello@world", expected = true, desc = "包含@符号"},
        {input = "hello'world", expected = true, desc = "包含单引号"},
        {input = 'hello"world', expected = true, desc = "包含双引号"},
        {input = "hello\"world", expected = true, desc = "包含中文左双引号"},
        {input = "hello\"world", expected = true, desc = "包含中文右双引号"},
    }
    
    print("=== 标点符号检测测试 ===")
    for i, case in ipairs(test_cases) do
        local has_punctuation = case.input:match("[,.!?;:()%[%]<>/_=+*&^%%$#@~|%-`'\"']") ~= nil
        local result = has_punctuation == case.expected and "✅ 通过" or "❌ 失败"
        print(string.format("测试 %d: %s | 输入: '%s' | 期望: %s | 实际: %s | %s", 
            i, case.desc, case.input, 
            case.expected and "有标点" or "无标点",
            has_punctuation and "有标点" or "无标点",
            result))
    end
end

test_punctuation_detection()
