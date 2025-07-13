-- 引入日志工具模块
local logger_module = require("logger")
-- 引入文本切分模块
local text_splitter = require("text_splitter")

-- 创建当前模块的日志记录器
local logger = logger_module.create("test_quotes", {
    enabled = true  -- 可以通过这里控制日志开关
})

-- 向前移动搜索字符长度个数 - 1
-- ni hk wo de wo 光标位置10, 搜索wo, 
local str = "nihkwodewo"

local search_str = "w"

-- local search_start_pos = #str - #search_str - 1 
local search_start_pos = #str - #search_str + 1

print(search_start_pos)

-- 10 - 2 - 1 =7

local found_pos = string.find(str, search_str, search_start_pos, true)

print(found_pos)

-- 我希望当搜索的时候如果光标在 local str = "nihkw|odewo"
-- 




print( tostring(has_punctuation_no_backtick("我", logger)) )

print( tostring(has_punctuation_no_backtick("你好的", logger)) )

print( tostring(has_punctuation_no_backtick("你好", logger)) )