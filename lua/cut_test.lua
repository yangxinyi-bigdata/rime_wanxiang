#!/usr/bin/env lua

local log = require "log"
log.level = "info"               -- 最低日志级别
log.outfile = "/Users/yangxinyi/Library/Rime/log/cut_test.log"     -- 输出到文件
log.usecolor = false            -- 关闭控制台颜色

-- 智能切分输入并转换双拼到全拼
local function split_and_convert_input(input)
    log.info("开始处理输入: " .. input)
    
    -- 先处理反引号 - 支持多对反引号
    -- nihk`hello`wode`dream3`keyi 应该处理成：nihk + `hello` + wode + `dream3` + keyi
    -- nihk`hello`wode`dream3 应该处理成：nihk + `hello` + wode + `dream3（后面所有内容不处理）
    local backtick_positions = {}  -- 所有反引号位置
    
    -- 先找到所有反引号的位置
    for i = 1, #input do
        local char = input:sub(i, i)
        if char == "`" then
        table.insert(backtick_positions, i)
        end
    end
    
    -- 检查反引号数量
    local backtick_count = #backtick_positions
    local has_unpaired_backtick = (backtick_count % 2 == 1)  -- 奇数个反引号表示有未配对的
    
    log.info("找到 " .. backtick_count .. " 个反引号，位置: " .. table.concat(backtick_positions, ", "))
    if has_unpaired_backtick then
        log.info("检测到未配对的反引号，最后一个反引号后的内容将不被处理")
    end
    
    -- 定义标点符号模式
    local punct_pattern = "[,.!?;:()%[%]<>/_=+*&^%%$#@~|\\-]"
    
    -- 切分输入，保留标点符号位置
    local segments = {}  -- 片段列表
    local current_segment = ""  -- 当前片段
    local i = 1
    local in_backtick = false  -- 在反引号中
    local backtick_content = ""  -- 反引号内容
    local backtick_pair_index = 0  -- 当前处理到第几个反引号
    
    while i <= #input do
        local char = input:sub(i, i)  -- 当前字符
        
        -- 检查是否到达未配对的最后一个反引号
        if has_unpaired_backtick and backtick_pair_index == backtick_count - 1 and char == "`" then
        -- 最后一个未配对的反引号，从这里开始到末尾都不处理
        if current_segment ~= "" then
            table.insert(segments, {type = "text", content = current_segment})
            current_segment = ""
        end
        table.insert(segments, {type = "backtick", content = input:sub(i + 1)})  -- 反引号后的所有内容
        break
        elseif char == "`" then
        -- 不是最后一个未配对的反引号
        backtick_pair_index = backtick_pair_index + 1
        if not in_backtick then
            -- 开始反引号内容
            if current_segment ~= "" then  -- 遇到反引号，且之前不是在反引号当中,将之前积累的内容直接添加成片段
                table.insert(segments, {type = "text", content = current_segment})  -- 类型=文本，内容
                current_segment = ""
            end
            in_backtick = true
            backtick_content = ""
        else
            -- 结束反引号内容
            table.insert(segments, {type = "backtick", content = backtick_content})  -- 类型=反引号
            in_backtick = false
            backtick_content = ""
        end
        elseif in_backtick then
        backtick_content = backtick_content .. char
        elseif char:match(punct_pattern) then
        -- 遇到标点符号
        if current_segment ~= "" then
            table.insert(segments, {type = "text", content = current_segment})  -- 类型=文本
            current_segment = ""
        end
        table.insert(segments, {type = "punct", content = char})  -- 类型=标点
        else
        current_segment = current_segment .. char
        end
        
        i = i + 1
    end
    
    -- 处理最后一个片段
    if in_backtick then
        -- 未闭合的反引号内容
        table.insert(segments, {type = "backtick", content = backtick_content})
    elseif current_segment ~= "" then
        table.insert(segments, {type = "text", content = current_segment})
    end
    
    -- 输出调试信息
    log.info("切分结果:")
    for i, seg in ipairs(segments) do
        log.info(string.format("  片段%d: 类型=%s, 内容='%s'", i, seg.type, seg.content))
    end
    
    return segments
end

-- 测试用例
local function run_tests()
    log.info("=" .. string.rep("=", 50))
    log.info("开始反引号和标点符号切分测试")
    log.info("=" .. string.rep("=", 50))
    
    -- 测试用例数组
    local test_cases = {
        -- 基础测试
        {
            input = "hello,world",
            desc = "基础标点符号测试",
            expected = {
                {type = "text", content = "hello"},
                {type = "punct", content = ","},
                {type = "text", content = "world"}
            }
        },
        
        -- 单对反引号测试
        {
            input = "nihk`hello`wode",
            desc = "单对反引号测试",
            expected = {
                {type = "text", content = "nihk"},
                {type = "backtick", content = "hello"},
                {type = "text", content = "wode"}
            }
        },
        
        -- 多对反引号测试
        {
            input = "nihk`hello`wode`dream3`keyi",
            desc = "多对反引号测试",
            expected = {
                {type = "text", content = "nihk"},
                {type = "backtick", content = "hello"},
                {type = "text", content = "wode"},
                {type = "backtick", content = "dream3"},
                {type = "text", content = "keyi"}
            }
        },
        
        -- 单个未配对反引号测试
        {
            input = "nihk`hello`wode`dream3",
            desc = "单个未配对反引号测试",
            expected = {
                {type = "text", content = "nihk"},
                {type = "backtick", content = "hello"},
                {type = "text", content = "wode"},
                {type = "backtick", content = "dream3"}
            }
        },
        
        -- 复杂标点符号测试
        {
            input = "hello,world!how(are)you?",
            desc = "复杂标点符号测试",
            expected = {
                {type = "text", content = "hello"},
                {type = "punct", content = ","},
                {type = "text", content = "world"},
                {type = "punct", content = "!"},
                {type = "text", content = "how"},
                {type = "punct", content = "("},
                {type = "text", content = "are"},
                {type = "punct", content = ")"},
                {type = "text", content = "you"},
                {type = "punct", content = "?"}
            }
        },
        
        -- 反引号和标点符号混合测试
        {
            input = "hello,`world`!how-are_you",
            desc = "反引号和标点符号混合测试",
            expected = {
                {type = "text", content = "hello"},
                {type = "punct", content = ","},
                {type = "backtick", content = "world"},
                {type = "punct", content = "!"},
                {type = "text", content = "how"},
                {type = "punct", content = "-"},
                {type = "text", content = "are"},
                {type = "punct", content = "_"},
                {type = "text", content = "you"}
            }
        },
        
        -- 反引号内包含标点符号测试
        {
            input = "start`hello,world!`end",
            desc = "反引号内包含标点符号测试",
            expected = {
                {type = "text", content = "start"},
                {type = "backtick", content = "hello,world!"},
                {type = "text", content = "end"}
            }
        },
        
        -- 空反引号测试
        {
            input = "hello``world",
            desc = "空反引号测试",
            expected = {
                {type = "text", content = "hello"},
                {type = "backtick", content = ""},
                {type = "text", content = "world"}
            }
        },
        
        -- 只有反引号的测试
        {
            input = "`hello`",
            desc = "只有反引号的测试",
            expected = {
                {type = "backtick", content = "hello"}
            }
        },
        
        -- 单个反引号在末尾
        {
            input = "hello`world",
            desc = "单个反引号在末尾测试",
            expected = {
                {type = "text", content = "hello"},
                {type = "backtick", content = "world"}
            }
        },
        
        -- 英文字符串处理测试
        {
            input = "The`quick`brown,fox!jumps",
            desc = "英文字符串+反引号+标点符号混合测试",
            expected = {
                {type = "text", content = "The"},
                {type = "backtick", content = "quick"},
                {type = "text", content = "brown"},
                {type = "punct", content = ","},
                {type = "text", content = "fox"},
                {type = "punct", content = "!"},
                {type = "text", content = "jumps"}
            }
        },
        
        -- 英文编程相关语法测试
        {
            input = "function`getName`()=>name",
            desc = "英文编程语法测试",
            expected = {
                {type = "text", content = "function"},
                {type = "backtick", content = "getName"},
                {type = "punct", content = "("},
                {type = "punct", content = ")"},
                {type = "punct", content = "="},
                {type = "punct", content = ">"},
                {type = "text", content = "name"}
            }
        },
        
        -- 英文路径和文件名测试
        {
            input = "cd`/home/user`&&ls-la",
            desc = "英文路径和命令测试",
            expected = {
                {type = "text", content = "cd"},
                {type = "backtick", content = "/home/user"},
                {type = "punct", content = "&"},
                {type = "punct", content = "&"},
                {type = "text", content = "ls"},
                {type = "punct", content = "-"},
                {type = "text", content = "la"}
            }
        },
        
        -- 英文缩写和特殊字符测试
        {
            input = "U.S.A`is#1`in@world",
            desc = "英文缩写和特殊字符测试",
            expected = {
                {type = "text", content = "U"},
                {type = "punct", content = "."},
                {type = "text", content = "S"},
                {type = "punct", content = "."},
                {type = "text", content = "A"},
                {type = "backtick", content = "is#1"},
                {type = "text", content = "in"},
                {type = "punct", content = "@"},
                {type = "text", content = "world"}
            }
        },
        
        -- 数字和英文混合测试
        {
            input = "year`2024`has365days",
            desc = "数字和英文混合测试",
            expected = {
                {type = "text", content = "year"},
                {type = "backtick", content = "2024"},
                {type = "text", content = "has365days"}
            }
        },
        
        -- 复杂英文表达式测试
        {
            input = "Math.sqrt`x^2+y^2`<=radius",
            desc = "复杂英文表达式测试",
            expected = {
                {type = "text", content = "Math"},
                {type = "punct", content = "."},
                {type = "text", content = "sqrt"},
                {type = "backtick", content = "x^2+y^2"},
                {type = "punct", content = "<"},
                {type = "punct", content = "="},
                {type = "text", content = "radius"}
            }
        },
        
        -- 多层嵌套反引号测试（虽然不应该出现，但测试健壮性）
        {
            input = "a`hello`b`world`c`end",
            desc = "多层嵌套反引号结束测试",
            expected = {
                {type = "text", content = "a"},
                {type = "backtick", content = "hello"},
                {type = "text", content = "b"},
                {type = "backtick", content = "world"},
                {type = "text", content = "c"},
                {type = "backtick", content = "end"}
            }
        },
        
        -- URL 格式测试
        {
            input = "https://`example.com`/path?param=value",
            desc = "URL 格式测试",
            expected = {
                {type = "text", content = "https"},
                {type = "punct", content = ":"},
                {type = "punct", content = "/"},
                {type = "punct", content = "/"},
                {type = "backtick", content = "example.com"},
                {type = "punct", content = "/"},
                {type = "text", content = "path"},
                {type = "punct", content = "?"},
                {type = "text", content = "param"},
                {type = "punct", content = "="},
                {type = "text", content = "value"}
            }
        },
        
        -- 英文句子标点测试
        {
            input = "Hello,`world`!How(are)you?Fine&well.",
            desc = "英文句子完整标点测试",
            expected = {
                {type = "text", content = "Hello"},
                {type = "punct", content = ","},
                {type = "backtick", content = "world"},
                {type = "punct", content = "!"},
                {type = "text", content = "How"},
                {type = "punct", content = "("},
                {type = "text", content = "are"},
                {type = "punct", content = ")"},
                {type = "text", content = "you"},
                {type = "punct", content = "?"},
                {type = "text", content = "Fine"},
                {type = "punct", content = "&"},
                {type = "text", content = "well"},
                {type = "punct", content = "."}
            }
        }
    }
    
    -- 运行测试
    local total_tests = #test_cases
    local passed_tests = 0
    
    for i, test_case in ipairs(test_cases) do
        log.info("")
        log.info(string.format("测试 %d/%d: %s", i, total_tests, test_case.desc))
        log.info("输入: '" .. test_case.input .. "'")
        
        local result = split_and_convert_input(test_case.input)
        
        -- 验证结果
        local success = true
        if #result ~= #test_case.expected then
            log.error(string.format("片段数量不匹配！期望: %d, 实际: %d", #test_case.expected, #result))
            success = false
        else
            for j = 1, #result do
                if result[j].type ~= test_case.expected[j].type or result[j].content ~= test_case.expected[j].content then
                    log.error(string.format("片段 %d 不匹配！期望: type=%s, content='%s', 实际: type=%s, content='%s'", 
                        j, test_case.expected[j].type, test_case.expected[j].content, result[j].type, result[j].content))
                    success = false
                end
            end
        end
        
        if success then
            log.info("✅ 测试通过")
            passed_tests = passed_tests + 1
        else
            log.error("❌ 测试失败")
        end
    end
    
    -- 输出测试总结
    log.info("")
    log.info("=" .. string.rep("=", 50))
    log.info(string.format("测试完成！通过: %d/%d", passed_tests, total_tests))
    if passed_tests == total_tests then
        log.info("🎉 所有测试都通过了！")
    else
        log.error(string.format("⚠️  有 %d 个测试失败", total_tests - passed_tests))
    end
    log.info("=" .. string.rep("=", 50))
end

-- 运行测试
run_tests()