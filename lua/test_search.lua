-- 测试搜索功能
package.path = package.path .. ";lua/?.lua"
local text_splitter = require("text_splitter")

-- 模拟logger
local logger = {
    info = function(self, msg) print("INFO: " .. msg) end
}

-- 测试用例
local test_cases = {
    {
        input = "nihao`world`test",
        search = "world",
        start_pos = 1,
        expected = nil,  -- 应该找不到，因为world在反引号内
        desc = "测试跳过反引号内的内容"
    },
    {
        input = "nihao`world`test",
        search = "test",
        start_pos = 1,
        expected = 14,  -- 应该找到test
        desc = "测试搜索反引号外的内容"
    },
    {
        input = "nihao`world`test`end",
        search = "end",
        start_pos = 1,
        expected = nil,  -- 末尾未配对的反引号，应该跳过
        desc = "测试跳过未配对反引号到末尾的内容"
    },
    {
        input = "hello world test",
        search = "world",
        start_pos = 1,
        expected = 7,  -- 没有反引号，正常搜索
        desc = "测试没有反引号的正常搜索"
    }
}

print("开始测试搜索功能...")
for i, case in ipairs(test_cases) do
    print("\n测试 " .. i .. ": " .. case.desc)
    print("输入: " .. case.input)
    print("搜索: " .. case.search)
    
    local result = text_splitter.find_text_skip_backticks(case.input, case.search, case.start_pos, logger)
    
    print("期望结果: " .. tostring(case.expected))
    print("实际结果: " .. tostring(result))
    
    if result == case.expected then
        print("✓ 测试通过")
    else
        print("✗ 测试失败")
    end
end

print("\n测试完成")
