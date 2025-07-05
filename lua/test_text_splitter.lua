-- test_text_splitter.lua - 文本切分模块测试文件

local text_splitter = require("text_splitter")

-- 打印分隔线
local function print_separator()
    print(string.rep("-", 80))
end

-- 打印测试结果
local function print_test_result(test_name, input, segments, delimiter)
    print_separator()
    print("测试名称: " .. test_name)
    print("输入: " .. input)
    if delimiter and delimiter ~= "" then
        print("分隔符: '" .. delimiter .. "'")
    end
    print("切分结果:")
    for i, seg in ipairs(segments) do
        print(string.format("  [%d] 类型: %-10s 内容: '%s'", i, seg.type, seg.content))
    end
    print()
end

-- 运行测试
local function run_tests()
    print("=== 文本切分器测试 ===")
    print()
    
    -- 测试1: 基本的成对反引号
    local test1_input = "nihao`hello`shijie"
    local test1_result = text_splitter.split_by_backtick(test1_input, "", "")
    print_test_result("基本成对反引号", test1_input, test1_result)
    
    -- 测试2: 多对反引号
    local test2_input = "nihk`hello`wode`dream3`keyi"
    local test2_result = text_splitter.split_by_backtick(test2_input, "", "")
    print_test_result("多对反引号", test2_input, test2_result)
    
    -- 测试3: 未配对的反引号
    local test3_input = "nihk`hello`wode`dream3"
    local test3_result = text_splitter.split_by_backtick(test3_input, "", "")
    print_test_result("未配对的反引号", test3_input, test3_result)
    
    -- 测试4: 包含标点符号（不应该被切分）
    local test4_input = "hello,world!`test`nice.work"
    local test4_result = text_splitter.split_by_backtick(test4_input, "", "")
    print_test_result("包含标点符号", test4_input, test4_result)
    
    -- 测试5: 空的反引号内容
    local test5_input = "before``after"
    local test5_result = text_splitter.split_by_backtick(test5_input, "", "")
    print_test_result("空的反引号内容", test5_input, test5_result)
    
    -- 测试6: 只有一个反引号
    local test6_input = "before`everything after this"
    local test6_result = text_splitter.split_by_backtick(test6_input, "", "")
    print_test_result("只有一个反引号", test6_input, test6_result)
    
    -- 测试7: 使用分隔符
    local test7_input = "nihao`hello`shijie"
    local test7_result = text_splitter.split_by_backtick(test7_input, " ", " ")
    print_test_result("使用空格分隔符", test7_input, test7_result, " ")
    
    -- 测试8: 使用自定义分隔符
    local test8_input = "code`function test()`end"
    local test8_result = text_splitter.split_by_backtick(test8_input, "___", "___")
    print_test_result("使用自定义分隔符", test8_input, test8_result, "___")
    
    -- 测试9: 复杂混合情况
    local test9_input = "start!@#$%^&*()_+-=`special chars: <>?`middle[]{};':\",./<>?`another`end!!!"
    local test9_result = text_splitter.split_by_backtick(test9_input, "", "")
    print_test_result("复杂混合情况", test9_input, test9_result)
    
    -- 测试10: 连续的反引号
    local test10_input = "```multiple```backticks"
    local test10_result = text_splitter.split_by_backtick(test10_input, "", "")
    print_test_result("连续的反引号", test10_input, test10_result)
    
    -- 测试11: 反引号在开头和结尾
    local test11_input = "`start`middle`end`"
    local test11_result = text_splitter.split_by_backtick(test11_input, "", "")
    print_test_result("反引号在开头和结尾", test11_input, test11_result)
    
    -- 测试12: 未配对反引号加分隔符
    local test12_input = "before`unclosed with delimiter"
    local test12_result = text_splitter.split_by_backtick(test12_input, "||", "||")
    print_test_result("未配对反引号加分隔符", test12_input, test12_result, "||")
    
    print_separator()
    print("测试完成！")
end

-- 运行测试
run_tests()
