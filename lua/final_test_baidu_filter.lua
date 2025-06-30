-- final_test_baidu_filter.lua - 综合测试修改后的baidu_filter错误捕获功能
local logger_module = require("logger")
local text_splitter = require("text_splitter")

-- 创建测试日志记录器
local logger = logger_module.create("final_test_baidu_filter", {
    enabled = true
})

-- 清空日志
logger:clear()
logger:info("开始综合测试baidu_filter的错误捕获功能")

-- 模拟 get_cloud_result 函数（避免实际网络请求）
local function mock_get_cloud_result(pinyin_text)
    if pinyin_text == "" then return "" end
    
    logger:info("模拟处理片段: '" .. pinyin_text .. "'")
    
    -- 模拟一些可能的结果
    if pinyin_text == "hello" then
        return "你好"
    elseif pinyin_text == "world" then
        return "世界"
    elseif pinyin_text == "test" then
        return "测试"
    else
        return "[云输入]" .. pinyin_text
    end
end

-- 复制baidu_filter中的核心逻辑（包含标点符号处理部分）
local function test_baidu_filter_logic(input)
    logger:info("=" .. string.rep("=", 60))
    logger:info("测试输入: '" .. input .. "'")
    
    -- 检查输入是否包含标点符号或反引号
    local has_punctuation = input:match("[,.!?;:()%[%]<>/_=+*&^%%$#@~|%-`'\"']") ~= nil
    
    if not has_punctuation then
        logger:info("检测到纯英文字母输入，使用传统处理方式")
        -- 这里简化处理，实际中会调用百度云接口
        local result = mock_get_cloud_result(input)
        logger:info("处理结果: " .. result)
        return result
    else
        -- 包含标点符号或反引号，使用智能切分处理
        logger:info("检测到标点符号或反引号，使用智能切分处理方式")

        -- 切分并处理输入（添加错误捕获）
        local segments = {}
        local final_result = ""
        
        local success, result = pcall(function()
            return text_splitter.split_and_convert_input_with_log(input, logger)
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
            -- 降级处理：将整个输入当作纯文本处理
            segments = {{type = "text", content = input}}
        end
        
        -- 处理每个片段（添加错误捕获）
        for i, segment in ipairs(segments) do
            local segment_success, segment_result = pcall(function()
                -- 检查片段格式
                if not segment or type(segment) ~= "table" or not segment.type then
                    error("片段格式无效")
                end
                
                if segment.type == "text" then
                    -- 文本片段：进行双拼转换和云输入
                    if segment.content == nil then
                        error("text片段缺少content字段")
                    end
                    logger:info(string.format("处理文本片段 %d: '%s'", i, segment.content))
                    return mock_get_cloud_result(segment.content)
                elseif segment.type == "punct" then
                    -- 标点符号：直接添加
                    if segment.content == nil then
                        error("punct片段缺少content字段")
                    end
                    logger:info(string.format("处理标点片段 %d: '%s'", i, segment.content))
                    return segment.content
                elseif segment.type == "backtick" then
                    -- 反引号内容：不处理，直接添加
                    if segment.content == nil then
                        error("backtick片段缺少content字段")
                    end
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
                -- 失败时使用原始内容
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
end

-- 测试用例
local test_cases = {
    -- 纯英文测试
    "hello",
    "world",
    
    -- 标点符号测试
    "hello,world",
    "test.case",
    "one;two;three",
    
    -- 反引号测试
    "ni`hao`ma",
    "hello`world`test",
    "single`quote",
    "empty``content",
    
    -- 引号测试
    "test'quote'end",
    'test"double"quote',
    
    -- 混合测试
    "hello,world`test`end",
    "complex.case`with`mixed;content",
    
    -- 边界情况
    "",
    "`",
    "``",
    ",",
    ".,;",
}

-- 运行所有测试
logger:info("开始运行综合测试用例...")
local success_count = 0
local total_count = #test_cases

for i, test_input in ipairs(test_cases) do
    local test_success, test_result = pcall(function()
        return test_baidu_filter_logic(test_input)
    end)
    
    if test_success then
        success_count = success_count + 1
        logger:info(string.format("测试 %d/%d 成功", i, total_count))
    else
        logger:error(string.format("测试 %d/%d 失败: %s", i, total_count, tostring(test_result)))
    end
end

logger:info("=" .. string.rep("=", 60))
logger:info(string.format("综合测试完成: %d/%d 成功", success_count, total_count))

if success_count == total_count then
    logger:info("✅ 所有测试都通过！错误捕获功能工作正常。")
else
    logger:error(string.format("❌ 有 %d 个测试失败，需要进一步检查。", total_count - success_count))
end
