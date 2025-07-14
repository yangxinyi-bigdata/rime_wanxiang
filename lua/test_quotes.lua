local text_splitter = require("text_splitter")
local logger_module = require("logger")

-- 创建当前模块的日志记录器
local logger = logger_module.create("test_quotes", {
    enabled = true -- 启用日志以便调试
})

-- 英文标点符号到中文标点符号的映射表
local punct_map = {
    [","] = "，", -- 逗号
    ["."] = "。", -- 句号
    ["?"] = "？", -- 问号  
    ["!"] = "！", -- 感叹号
    [":"] = "：", -- 冒号
    [";"] = "；", -- 分号
    ["("] = "（", -- 左括号
    [")"] = "）", -- 右括号
    -- ["["] = "【",    -- 左方括号
    -- ["]"] = "】",    -- 右方括号
    ["{"] = "｛", -- 左花括号
    ["}"] = "｝", -- 右花括号
    ["<"] = "《", -- 左书名号
    [">"] = "》" -- 右书名号
}

-- local text_splitter = {}
-- 标点符号替换函数, 对于传递进来的坐标范围进行替换
local function replace_punct_skip_pos(text, chinese_pos_str, logger)
    -- chinese_pos = "chinese_pos:3,6,"
    -- chinese_pos = "chinese_pos:1,1,9,12,"
    -- 我希望对于text中的标点符号进行替换, chinese_pos中是一个字符串,判断chinese_pos应该以"chinese_pos:"开头, 然后后面每一对数字代表了中文字符的坐标
    -- 只有当坐标位置在中文字符范围内的时候,才将标点符号从英文替换成中文标点符号.
    -- 对于英文双引号,如果是第一次遇到则替换成中文前引号“, 第二次遇到替换成中文后引号”.

    -- 检查坐标字符串格式
    if not chinese_pos_str or not chinese_pos_str:match("^chinese_pos:") then
        logger:info("坐标字符串格式不正确或为空，不进行替换")
        return
    end
    -- 解析坐标范围
    local ranges = {}
    local pos_data = chinese_pos_str:gsub("^chinese_pos:", "")
    -- 一次性匹配两个数字作为一对
    for start_num, end_num in pos_data:gmatch("(%d+),(%d+)") do
        table.insert(ranges, {
            start = tonumber(start_num),
            _end = tonumber(end_num)
        })
    end

    local final_text = ""
    local last_end_num = 0
    local double_quote_open = true

    -- 切片上一段中文后面的英文字符串 你好 hello 我的美人     " hello 你好,我的美人"
    -- 1,2,10,13   8,14,
    local chinese_first = false
    for i, range in ipairs(ranges) do
        local start_num = range.start
        local end_num = range._end
        print("start_num: " .. start_num .. " end_num: " .. end_num)

        -- 如果是第一段, 如果不是从1开始的,说明前边是英文段. 如果是从1开始的,则不用判断前边英文段了
        -- 如果第一段是中文, 那么对于后面的英文来说,第一段应该不存在
        local english_str = ""
        if start_num == 1 then
            -- 说明是从中文开始的, 不需要处理英文段
            chinese_first = true
        else
            -- 两种情况会进入这里, 第一种情况: 从英文开始的, 这种情况下chinese_first = false,那么应该从1开始取到这里
            if not chinese_first then
                english_str = text_splitter.utf8_utils_sub(text, 1, start_num - 1)
            else
                -- 进入这里说明, 第一段是中文, start_num ~= 1 那么一定不是第一段中文, 这时候应该使用上一段的结尾和这一段的开头
                english_str = text_splitter.utf8_utils_sub(text, last_end_num + 1, start_num - 1)
                print("english_str: " .. english_str)
            end
            final_text = final_text .. english_str
            print("final_text: " .. final_text)

        end

        local chinese_str = text_splitter.utf8_utils_sub(text, start_num, end_num)
        
        print("chinese_str: " .. chinese_str)
        if text_splitter.has_punctuation_no_backtick(chinese_str, logger) then
            for eng_punct, chn_punct in pairs(punct_map) do
                chinese_str = chinese_str:gsub(eng_punct:gsub("([%(%)%.%+%-%*%?%[%]%^%$%%])", "%%%1"), chn_punct)
            end
            chinese_str, double_quote_open = text_splitter.replace_quotes_record_single(chinese_str, double_quote_open)
        end


        logger:debug("chinese_str: " .. chinese_str)
        final_text = final_text .. chinese_str
        last_end_num = end_num

    end

    -- 有可能最后一个中文段后面还有英文段, 如何判断呢? 
    if last_end_num < utf8.len(text) then
        local remaining_str = text_splitter.utf8_utils_sub(text, last_end_num + 1, -1)
        final_text = final_text .. remaining_str
    end

    -- 还需要对引号段进行判断, 引号段需要如何替换呢? 

    return final_text

end

--[[ text= "你好 hello 我的美人" 则chinese_pos_str="1,2,10,13,"

text= " hello 你好,我的美人"
则chinese_pos_str="8,14," ]]
local text= "你好,宝贝 hello 我的美人."
local chinese_pos_str="chinese_pos:1,5,13,17,"

local text= " hello 你好,我的美人"
local chinese_pos_str="chinese_pos:8,14,"

local text= " hello, boy,this! 这是,真的!"
local chinese_pos_str="chinese_pos:19,24,"

local text= " hello, boy,this! 这是,真的! but it's not ok."
local chinese_pos_str="chinese_pos:19,24,"

local text= " hello\"boy\",this! 这是,\"真的\""
local chinese_pos_str="chinese_pos:19,25,"

-- 
local text= "他说:\" hello\"boy\",this! 这是\",\"真的\""
local chinese_pos_str="chinese_pos:1,4,23,30,"

local result = replace_punct_skip_pos(text, chinese_pos_str, logger)
print(result)