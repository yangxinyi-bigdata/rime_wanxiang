-- lua/test_script_backtick_translator.lua
-- 测试脚本反引号翻译器功能，验证新的数据结构

local text_splitter = require("text_splitter")

-- 验证片段数据结构的函数
local function validate_segment(seg, index, input)
    local errors = {}
    
    -- 检查必需属性
    if not seg.type then
        table.insert(errors, "缺少 type 属性")
    end
    
    if not seg.content then
        table.insert(errors, "缺少 content 属性")
    end
    
    if not seg.original then
        table.insert(errors, "缺少 original 属性")
    end
    
    if not seg.start then
        table.insert(errors, "缺少 start 属性")
    end
    
    if not seg._end then
        table.insert(errors, "缺少 _end 属性")
    end
    
    if not seg.length then
        table.insert(errors, "缺少 length 属性")
    end
    
    -- 检查位置和长度的逻辑性
    if seg.start and seg._end and seg.start > seg._end then
        table.insert(errors, "start > _end")
    end
    
    -- 修改长度计算：半开区间 [start, _end) 的长度是 _end - start
    if seg.start and seg._end and seg.length and (seg._end - seg.start) ~= seg.length then
        table.insert(errors, string.format("长度不匹配: 计算长度=%d, 实际length=%d", seg._end - seg.start, seg.length))
    end
    
    -- 检查内容和长度的一致性
    if seg.content and seg.length then
        if seg.type == "abc" and #seg.content ~= seg.length then
            table.insert(errors, string.format("abc类型内容长度不匹配: content长度=%d, length=%d", #seg.content, seg.length))
        end
    end
    
    -- 检查位置是否超出输入范围（0基索引）
    if seg.start and (seg.start < 0 or seg.start > #input) then
        table.insert(errors, string.format("start位置超出范围: %d (输入长度: %d)", seg.start, #input))
    end
    
    if seg._end and (seg._end < 0 or seg._end > #input) then
        table.insert(errors, string.format("_end位置超出范围: %d (输入长度: %d)", seg._end, #input))
    end
    
    return errors
end

-- 详细的测试函数
local function test_split_by_backtick()
    print("=== 测试 split_by_backtick 函数的数据结构 ===")
    
    local test_cases = {
        {input = "wo`ke`yi", delimiter = " ", desc = "标准配对反引号"},
        {input = "wokeyi`hello my love`keai", delimiter = " ", desc = "标准配对反引号"},
        {input = "nihao`world`zaijian", delimiter = "", desc = "无分隔符配对反引号"},
        {input = "abc`def`ghi`jkl`mno", delimiter = " ", desc = "多对反引号"},
        {input = "simple", delimiter = " ", desc = "无反引号"},
        {input = "test`unclosed", delimiter = " ", desc = "未配对反引号"},
        {input = "`start", delimiter = " ", desc = "开头反引号"},
        {input = "end`", delimiter = " ", desc = "结尾反引号"},
        {input = "`single`", delimiter = " ", desc = "单独反引号对"},
    }
    
    for i, case in ipairs(test_cases) do
        print(string.format("\n测试案例 %d: %s", i, case.desc))
        print(string.format("输入='%s', 分隔符='%s'", case.input, case.delimiter))
        
        local segments = text_splitter.split_by_backtick(case.input, case.delimiter)
        
        print("切分结果:")
        local total_errors = 0
        
        for j, seg in ipairs(segments) do
            print(string.format("  片段%d:", j))
            print(string.format("    type: %s", seg.type or "nil"))
            print(string.format("    content: '%s'", seg.content or "nil"))
            print(string.format("    original: '%s'", seg.original or "nil"))
            print(string.format("    start: %s", tostring(seg.start)))
            print(string.format("    _end: %s", tostring(seg._end)))
            print(string.format("    length: %s", tostring(seg.length)))
            
            -- 验证数据结构
            local errors = validate_segment(seg, j, case.input)
            if #errors > 0 then
                print(string.format("    ❌ 数据结构错误:"))
                for _, error in ipairs(errors) do
                    print(string.format("      - %s", error))
                end
                total_errors = total_errors + #errors
            else
                print("    ✅ 数据结构正确")
            end
            
            -- 验证位置映射（适配0基索引和半开区间）
            if seg.start and seg._end and seg.start >= 0 and seg._end <= #case.input then
                -- 转换为Lua的1基索引进行字符串提取
                local extracted = case.input:sub(seg.start + 1, seg._end)
                if seg.type == "abc" then
                    if extracted == seg.content then
                        print("    ✅ 位置映射正确")
                    else
                        print(string.format("    ❌ 位置映射错误: 提取='%s', 内容='%s'", extracted, seg.content))
                        total_errors = total_errors + 1
                    end
                elseif seg.type == "backtick" then
                    -- 对于backtick类型，验证original字段
                    if extracted == seg.original then
                        print("    ✅ 位置映射正确(backtick)")
                    else
                        print(string.format("    ❌ backtick位置映射错误: 提取='%s', 原始='%s'", extracted, seg.original))
                        total_errors = total_errors + 1
                    end
                end
            end
        end
        
        if total_errors == 0 then
            print("  🎉 所有数据结构验证通过!")
        else
            print(string.format("  ❌ 发现 %d 个错误", total_errors))
        end
        
        -- 验证完整性：所有片段的覆盖范围（适配0基索引和半开区间）
        local covered_positions = {}
        for j, seg in ipairs(segments) do
            if seg.start and seg._end then
                -- 半开区间 [start, _end)：包含start，不包含_end
                for pos = seg.start, seg._end - 1 do
                    covered_positions[pos] = true
                end
            end
        end
        
        local coverage_gaps = {}
        -- 检查0基索引范围 [0, #input-1]
        for pos = 0, #case.input - 1 do
            if not covered_positions[pos] then
                table.insert(coverage_gaps, pos)
            end
        end
        
        if #coverage_gaps == 0 then
            print("  ✅ 位置覆盖完整")
        else
            print(string.format("  ❌ 位置覆盖不完整，缺失位置: %s", table.concat(coverage_gaps, ", ")))
        end
    end
end

-- 运行测试
test_split_by_backtick()

print("\n=== 测试完成 ===")
print("验证项目（0基索引，半开区间 [start, _end)）：")
print("- ✅ 所有必需属性存在 (type, content, original, start, _end, length)")
print("- ✅ 位置逻辑正确性 (start <= _end)")
print("- ✅ 长度一致性 (_end - start == length)")
print("- ✅ 内容长度匹配 (content长度与length匹配)")
print("- ✅ 位置范围有效性 (0 <= start < _end <= 输入长度)")
print("- ✅ 位置映射准确性 (提取的内容与segment.content/original匹配)")
print("- ✅ 覆盖完整性 (所有位置都被某个片段覆盖)")
print("注意：使用0基索引和半开区间 [start, _end)，符合现代编程语言惯例")

return {
    test_split_by_backtick = test_split_by_backtick,
    validate_segment = validate_segment
}
