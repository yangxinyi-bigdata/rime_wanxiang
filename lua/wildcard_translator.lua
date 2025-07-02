-- 通配符翻译器，支持在词典中使用通配符模式
-- 使用方法：在词典中添加包含STAR的模式，STAR代表*通配符

local wildcard_translator = {}

-- 初始化通配符词典
function wildcard_translator.init(env)
    env.wildcard_dict = {}
    
    -- 从词典文件加载通配符规则（这里用示例数据）
    env.wildcard_dict["abcSTAR"] = {
        {text = "ABC开头匹配", comment = "通配符"},
        {text = "ABC系列", comment = "模式匹配"}
    }
    env.wildcard_dict["STARxyz"] = {
        {text = "以XYZ结尾", comment = "通配符"},
        {text = "XYZ后缀", comment = "模式匹配"}
    }
    env.wildcard_dict["aSTARz"] = {
        {text = "a开头z结尾", comment = "通配符"}
    }
    env.wildcard_dict["北京STAR"] = {
        {text = "北京市", comment = "地名通配符"}
    }
    env.wildcard_dict["STAR大学"] = {
        {text = "某某大学", comment = "学校通配符"}
    }
end

-- 通配符转正则表达式（STAR -> .*）
local function wildcard_to_regex(pattern)
    -- 转义正则表达式特殊字符
    local regex = pattern:gsub("[%^%$%(%)%%%.%[%]%+%-%?]", "%%%1")
    -- 将STAR转换为.*
    regex = regex:gsub("STAR", ".*")
    return "^" .. regex .. "$"
end

-- 检查输入是否匹配通配符模式
local function matches_pattern(input, pattern)
    local regex = wildcard_to_regex(pattern)
    return rime_api.regex_match(input, regex)
end

function wildcard_translator.func(input, seg, env)
    -- 遍历所有通配符模式
    for pattern, candidates in pairs(env.wildcard_dict) do
        if matches_pattern(input, pattern) then
            -- 如果匹配，生成候选项
            for _, cand_data in ipairs(candidates) do
                local cand = Candidate("wildcard", seg.start, seg._end, cand_data.text, cand_data.comment)
                cand.quality = 100  -- 设置权重
                yield(cand)
            end
        end
    end
end

return wildcard_translator
