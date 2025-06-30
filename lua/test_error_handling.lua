-- test_error_handling.lua - 测试baidu_filter的错误捕获功能
local logger_module = require("logger")
local text_splitter = require("text_splitter")

-- 创建测试日志记录器
local logger = logger_module.create("test_error_handling", {
    enabled = true
})

-- 清空日志
logger:clear()
logger:info("开始测试错误捕获功能")

-- 测试用例
local test_cases = {
    "hello,world",
    "ni`hao`ma",
    "test'quote'end",
    "empty``test",
    "single`test",
    "normal_text",
    "",  -- 空字符串测试
}

-- 模拟baidu_filter中的错误捕获逻辑
local function test_error_handling(input)
    logger:info("=" .. string.rep("=", 50))
    logger:info("测试输入: '" .. input .. "'")
    
    -- 切分并处理输入（添加错误捕获）
    local segments = {}
    local final_result = ""
    
    local success, result = pcall(function()
        return text_splitter.split_and_convert_input_with_log(input, logger)
    end)
    
    if success and result then
        segments = result
        logger:info("成功运行切分函数，获得 " .. #segments .. " 个片段")
        for i, seg in ipairs(segments) do
            logger:info(string.format("片段 %d: type=%s, content='%s'", i, seg.type, seg.content))
        end
    else
        logger:error("切分函数运行失败: " .. tostring(result))
        logger:info("降级到原始处理方式")
        -- 降级处理：将整个输入当作纯文本处理
        segments = {{type = "text", content = input}}
    end
    
    -- 处理每个片段（添加错误捕获）
    for i, segment in ipairs(segments) do
        local segment_success, segment_result = pcall(function()
            if segment.type == "text" then
                -- 文本片段：模拟处理（这里不调用实际的云接口）
                logger:info(string.format("处理文本片段 %d: '%s'", i, segment.content))
                return "[处理后]" .. segment.content
            elseif segment.type == "punct" then
                -- 标点符号：直接添加
                logger:info(string.format("处理标点片段 %d: '%s'", i, segment.content))
                return segment.content
            elseif segment.type == "backtick" then
                -- 反引号内容：不处理，直接添加
                logger:info(string.format("处理反引号片段 %d: '%s'", i, segment.content))
                return segment.content
            else
                logger:warning(string.format("未知片段类型 %d: type=%s, content='%s'", i, segment.type, segment.content))
                return segment.content
            end
        end)
        
        if segment_success and segment_result then
            final_result = final_result .. segment_result
            logger:info(string.format("片段 %d 处理成功，结果: '%s'", i, segment_result))
        else
            logger:error(string.format("片段 %d 处理失败: %s", i, tostring(segment_result)))
            -- 失败时使用原始内容
            final_result = final_result .. (segment.content or "")
        end
    end
    
    logger:info("最终结果: '" .. final_result .. "'")
    return final_result
end

-- 运行测试
for _, test_input in ipairs(test_cases) do
    test_error_handling(test_input)
end

logger:info("=" .. string.rep("=", 50))
logger:info("错误捕获功能测试完成")
