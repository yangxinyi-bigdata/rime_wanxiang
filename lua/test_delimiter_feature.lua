-- test_delimiter_feature.lua - 测试反引号分隔符功能
local logger_module = require("logger")
local text_splitter = require("text_splitter")

-- 创建测试日志记录器
local logger = logger_module.create("test_delimiter_feature", {
    enabled = true
})

-- 清空日志
logger:clear()
logger:info("开始测试反引号分隔符功能")

-- 模拟云输入处理函数
local function mock_get_cloud_result(pinyin_text)
    if pinyin_text == "" then return "" end
    
    -- 模拟一些转换结果
    local conversions = {
        nihk = "你好",
        veuiufme = "这是什么",
        hello = "hello",  -- 反引号内容保持原样
        world = "world",
        test = "测试"
    }
    
    return conversions[pinyin_text] or ("[云输入]" .. pinyin_text)
end

-- 测试不同分隔符设置
local function test_delimiter(input, delimiter, description)
    logger:info("=" .. string.rep("=", 60))
    logger:info(string.format("测试: %s", description))
    logger:info(string.format("输入: %s", input))
    logger:info(string.format("分隔符: '%s'", delimiter))
    
    -- 使用带分隔符的切分函数
    local segments = text_splitter.split_and_convert_input_with_log_and_delimiter(input, logger, delimiter)
    
    -- 模拟处理每个片段
    local final_result = ""
    for i, segment in ipairs(segments) do
        if segment.type == "text" then
            -- 文本片段：进行模拟转换
            local converted = mock_get_cloud_result(segment.content)
            final_result = final_result .. converted
            logger:info(string.format("片段 %d (文本): '%s' -> '%s'", i, segment.content, converted))
        elseif segment.type == "punct" then
            -- 标点符号：直接添加
            final_result = final_result .. segment.content
            logger:info(string.format("片段 %d (标点): '%s'", i, segment.content))
        elseif segment.type == "backtick" then
            -- 反引号内容：直接添加（已包含分隔符）
            final_result = final_result .. segment.content
            logger:info(string.format("片段 %d (反引号): '%s'", i, segment.content))
        end
    end
    
    logger:info(string.format("最终结果: '%s'", final_result))
    return final_result
end

-- 测试用例
local test_cases = {
    {
        input = "nihk`hello`veuiufme",
        delimiter = " ",
        description = "空格分隔符测试 - 期望: 你好 hello 这是什么"
    },
    {
        input = "nihk`hello`veuiufme",
        delimiter = "`",
        description = "反引号分隔符测试 - 期望: 你好`hello`这是什么"
    },
    {
        input = "nihk`hello`veuiufme",
        delimiter = "",
        description = "无分隔符测试 - 期望: 你好hello这是什么"
    },
    {
        input = "test`world`end",
        delimiter = "-",
        description = "短横线分隔符测试 - 期望: 测试-world-[云输入]end"
    },
    {
        input = "before`middle`after`last",
        delimiter = " ",
        description = "未配对反引号测试（空格分隔符）"
    },
    {
        input = "a`b`c`d`e",
        delimiter = "|",
        description = "多对反引号测试（竖线分隔符）"
    },
    {
        input = "no_backtick_here",
        delimiter = " ",
        description = "无反引号内容测试"
    },
    {
        input = "`only_backtick`",
        delimiter = "[]",
        description = "仅反引号内容测试"
    }
}

-- 运行所有测试
logger:info("开始运行分隔符功能测试...")
for i, test_case in ipairs(test_cases) do
    local result = test_delimiter(test_case.input, test_case.delimiter, test_case.description)
    logger:info(string.format("测试 %d/%d 完成", i, #test_cases))
end

logger:info("=" .. string.rep("=", 60))
logger:info("所有分隔符功能测试完成！")
logger:info("")
logger:info("测试总结:")
logger:info("1. 空格分隔符: 在反引号内容两边添加空格")
logger:info("2. 反引号分隔符: 保持原有反引号")
logger:info("3. 无分隔符: 直接连接，无额外符号")
logger:info("4. 自定义分隔符: 支持任意字符串作为分隔符")
logger:info("5. 未配对反引号: 正确处理奇数个反引号的情况")
logger:info("6. 多对反引号: 支持多个反引号对")
logger:info("")
logger:info("配置方法:")
logger:info("在输入法配置文件中添加:")
logger:info("translator:")
logger:info("  backtick_delimiter: ' '  # 空格分隔符")
logger:info("  # 或者")
logger:info("  backtick_delimiter: '`'  # 反引号分隔符")
logger:info("  # 或者")
logger:info("  backtick_delimiter: ''   # 无分隔符（默认）")
