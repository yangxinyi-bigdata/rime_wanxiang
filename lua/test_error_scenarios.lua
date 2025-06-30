-- test_error_scenarios.lua - 测试各种异常情况的错误捕获
local logger_module = require("logger")

-- 创建测试日志记录器
local logger = logger_module.create("test_error_scenarios", {
    enabled = true
})

-- 清空日志
logger:clear()
logger:info("开始测试异常情况的错误捕获")

-- 模拟可能出错的text_splitter模块
local fake_text_splitter = {}

-- 故意制造错误的版本
function fake_text_splitter.split_and_convert_input_with_log(input, logger)
    if input == "cause_error" then
        error("模拟的切分函数错误")
    elseif input == "return_nil" then
        return nil
    elseif input == "return_invalid" then
        return "not_a_table"
    elseif input == "partial_error" then
        -- 返回包含无效片段的结果
        return {
            {type = "text", content = "valid1"},
            {type = "invalid_type", content = "invalid"},
            {type = "text"}  -- 缺少content字段
        }
    else
        -- 正常情况
        return {
            {type = "text", content = input}
        }
    end
end

-- 模拟baidu_filter中的错误捕获逻辑
local function test_error_scenario(input, text_splitter_module)
    logger:info("=" .. string.rep("=", 50))
    logger:info("测试输入: '" .. input .. "'")
    
    -- 切分并处理输入（添加错误捕获）
    local segments = {}
    local final_result = ""
    
    local success, result = pcall(function()
        return text_splitter_module.split_and_convert_input_with_log(input, logger)
    end)
    
    if success and result and type(result) == "table" then
        segments = result
        logger:info("成功运行切分函数，获得 " .. #segments .. " 个片段")
        for i, seg in ipairs(segments) do
            if type(seg) == "table" and seg.type and seg.content then
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
                if not segment.content then
                    error("text片段缺少content字段")
                end
                logger:info(string.format("处理文本片段 %d: '%s'", i, segment.content))
                return "[处理后]" .. segment.content
            elseif segment.type == "punct" then
                if not segment.content then
                    error("punct片段缺少content字段")
                end
                logger:info(string.format("处理标点片段 %d: '%s'", i, segment.content))
                return segment.content
            elseif segment.type == "backtick" then
                if not segment.content then
                    error("backtick片段缺少content字段")
                end
                logger:info(string.format("处理反引号片段 %d: '%s'", i, segment.content))
                return segment.content
            else
                logger:info(string.format("未知片段类型 %d: type=%s", i, segment.type))
                return segment.content or ""
            end
        end)
        
        if segment_success and segment_result then
            final_result = final_result .. segment_result
            logger:info(string.format("片段 %d 处理成功，结果: '%s'", i, segment_result))
        else
            logger:error(string.format("片段 %d 处理失败: %s", i, tostring(segment_result)))
            -- 失败时使用原始内容或空字符串
            local fallback = ""
            if segment and type(segment) == "table" and segment.content then
                fallback = segment.content
            elseif type(segment) == "string" then
                fallback = segment
            end
            final_result = final_result .. fallback
            logger:info(string.format("片段 %d 使用降级处理: '%s'", i, fallback))
        end
    end
    
    logger:info("最终结果: '" .. final_result .. "'")
    return final_result
end

-- 测试各种异常情况
local test_cases = {
    "normal_input",      -- 正常情况
    "cause_error",       -- 切分函数抛出异常
    "return_nil",        -- 切分函数返回nil
    "return_invalid",    -- 切分函数返回非表格类型
    "partial_error",     -- 切分函数返回部分无效数据
}

for _, test_input in ipairs(test_cases) do
    test_error_scenario(test_input, fake_text_splitter)
end

logger:info("=" .. string.rep("=", 50))
logger:info("异常情况错误捕获测试完成")
