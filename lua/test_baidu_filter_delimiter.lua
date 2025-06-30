-- test_baidu_filter_delimiter.lua - 测试baidu_filter的分隔符功能
local logger_module = require("logger")
local text_splitter = require("text_splitter")

-- 创建测试日志记录器
local logger = logger_module.create("test_baidu_filter_delimiter", {
    enabled = true
})

-- 清空日志
logger:clear()
logger:info("开始测试baidu_filter的分隔符功能")

-- 模拟baidu_filter中的配置和处理逻辑
local function test_baidu_filter_delimiter_logic(input, delimiter)
    logger:info("=" .. string.rep("=", 60))
    logger:info(string.format("测试输入: '%s'，分隔符: '%s'", input, delimiter))
    
    -- 模拟baidu_filter中的切分处理
    local segments = {}
    local final_result = ""
    
    local success, result = pcall(function()
        return text_splitter.split_and_convert_input_with_log_and_delimiter(input, logger, delimiter)
    end)
    
    if success and result and type(result) == "table" then
        segments = result
        logger:info("成功运行切分函数，获得 " .. #segments .. " 个片段")
        for i, seg in ipairs(segments) do
            if type(seg) == "table" and seg.type and seg.content ~= nil then
                logger:info(string.format("片段 %d: type=%s, content='%s'", i, seg.type, seg.content))
            else
                logger:info(string.format("片段 %d: 格式无效 %s", i, tostring(seg)))
            end
        end
    else
        logger:error("切分函数运行失败: " .. tostring(result))
        logger:info("降级到原始处理方式")
        segments = {{type = "text", content = input}}
    end
    
    -- 模拟baidu_filter中的片段处理逻辑
    for i, segment in ipairs(segments) do
        local segment_success, segment_result = pcall(function()
            if segment.type == "text" then
                -- 模拟云输入转换
                logger:info(string.format("处理文本片段 %d: '%s'", i, segment.content))
                return "[云输入]" .. segment.content
            elseif segment.type == "punct" then
                logger:info(string.format("处理标点片段 %d: '%s'", i, segment.content))
                return segment.content
            elseif segment.type == "backtick" then
                logger:info(string.format("处理反引号片段 %d: '%s'", i, segment.content))
                return segment.content
            else
                logger:info(string.format("未知片段类型 %d: type=%s, content='%s'", i, segment.type, segment.content or "nil"))
                return segment.content or ""
            end
        end)
        
        if segment_success and segment_result then
            final_result = final_result .. segment_result
            logger:info(string.format("片段 %d 处理成功，结果: '%s'", i, segment_result))
        else
            logger:error(string.format("片段 %d 处理失败: %s", i, tostring(segment_result)))
            local fallback = ""
            if segment and type(segment) == "table" and segment.content then
                fallback = segment.content
            end
            final_result = final_result .. fallback
            logger:info(string.format("片段 %d 使用降级处理: '%s'", i, fallback))
        end
    end
    
    logger:info("智能切分最终结果: " .. final_result)
    return final_result
end

-- 测试用例
local test_cases = {
    {input = "nihk`hello`veuiufme", delimiter = " "},
    {input = "nihk`hello`veuiufme", delimiter = "`"},
    {input = "nihk`hello`veuiufme", delimiter = ""},
    {input = "test`API`integration", delimiter = " "},
    {input = "single`quote", delimiter = " "},
}

-- 运行测试
for i, test_case in ipairs(test_cases) do
    test_baidu_filter_delimiter_logic(test_case.input, test_case.delimiter)
    logger:info(string.format("测试 %d/%d 完成", i, #test_cases))
end

logger:info("=" .. string.rep("=", 60))
logger:info("baidu_filter分隔符功能测试完成！")
logger:info("")
logger:info("现在可以在Rime配置文件中设置：")
logger:info("translator:")
logger:info("  backtick_delimiter: ' '  # 你想要的分隔符")
logger:info("")
logger:info("baidu_filter会自动读取这个配置并应用到反引号内容的处理中。")
