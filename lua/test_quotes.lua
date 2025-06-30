-- 测试text_splitter模块对引号的处理
local text_splitter = require("text_splitter")

local function test_quotes_handling()
    local test_cases = {
        {input = "hello'world", desc = "单引号测试"},
        {input = 'say"hello"world', desc = "双引号测试"},
        {input = "it's`good`day", desc = "单引号+反引号混合"},
        {input = 'he said"hello"`world`', desc = "双引号+反引号混合"},
    }
    
    print("=== 引号处理测试 ===")
    for i, case in ipairs(test_cases) do
        print(string.format("\n测试 %d: %s", i, case.desc))
        print("输入: " .. case.input)
        
        local segments = text_splitter.split_and_convert_input(case.input)
        print("切分结果:")
        for j, seg in ipairs(segments) do
            print(string.format("  片段%d: 类型=%s, 内容='%s'", j, seg.type, seg.content))
        end
    end
end

test_quotes_handling()
