-- lua/test_script_backtick_translator.lua
-- 测试脚本反引号翻译器功能

local text_splitter = require("text_splitter")

-- 简单的测试函数
local function test_split_by_backtick()
    print("=== 测试 split_by_backtick 函数 ===")
    
    local test_cases = {
        {input = "wokeyi`hello my love`keai", delimiter = " "},
        {input = "nihao`world`zaijian", delimiter = ""},
        {input = "abc`def`ghi`jkl`mno", delimiter = " "},
        {input = "simple", delimiter = " "},
        {input = "test`unclosed", delimiter = " "},
    }
    
    for i, case in ipairs(test_cases) do
        print(string.format("\n测试案例 %d: 输入='%s', 分隔符='%s'", i, case.input, case.delimiter))
        
        local segments = text_splitter.split_by_backtick(case.input, case.delimiter)
        
        print("切分结果:")
        for j, seg in ipairs(segments) do
            if seg.type == "backtick" then
                print(string.format("  片段%d: 类型=%s, 内容='%s', 原始='%s'", j, seg.type, seg.content, seg.original or "无"))
            else
                print(string.format("  片段%d: 类型=%s, 内容='%s'", j, seg.type, seg.content))
            end
        end
        
        -- 模拟拼接结果（包含text和preedit）
        local result_text = ""
        local result_preedit = ""
        
        for j, seg in ipairs(segments) do
            if seg.type == "abc" then
                -- 模拟翻译结果（这里只是示例）
                if seg.content == "wokeyi" then
                    result_text = result_text .. "我可以"
                    result_preedit = result_preedit .. "wo ke yi"  -- 模拟preedit
                elseif seg.content == "keai" then
                    result_text = result_text .. "可爱"
                    result_preedit = result_preedit .. "ke ai"    -- 模拟preedit
                elseif seg.content == "nihao" then
                    result_text = result_text .. "你好"
                    result_preedit = result_preedit .. "ni hao"   -- 模拟preedit
                elseif seg.content == "zaijian" then
                    result_text = result_text .. "再见"
                    result_preedit = result_preedit .. "zai jian" -- 模拟preedit
                else
                    result_text = result_text .. seg.content
                    result_preedit = result_preedit .. seg.content
                end
            else
                -- backtick类型：text是处理后的（带分隔符），preedit是原始的（带反引号）
                result_text = result_text .. seg.content  -- 处理后的内容
                result_preedit = result_preedit .. (seg.original or seg.content)  -- 原始反引号内容
            end
        end
        
        print("模拟最终结果:")
        print("  text: " .. result_text)
        print("  preedit: " .. result_preedit)
    end
end

-- 运行测试
test_split_by_backtick()

print("\n=== 测试完成 ===")
print("说明：")
print("- abc类型的片段会被script_translator翻译")
print("- backtick类型的片段：text是处理后内容（包含分隔符），preedit是原始反引号形式")
print("- 分隔符会被添加到反引号内容的前后（仅影响text）")
print("- 最终结果是所有片段的text和preedit分别拼接")

return {
    test_split_by_backtick = test_split_by_backtick
}
