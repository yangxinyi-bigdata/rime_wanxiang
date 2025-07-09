-- 测试text_splitter模块对引号的处理

local test_cases = "ab"


print(test_cases:sub(3,3) == "")

local test = 0

if test then
    print("1")
end

local segment_content = "a"
segment_content = segment_content:sub(1, -2)
print(segment_content == "")


local a = (false ~= nil) and false or true
print(a)