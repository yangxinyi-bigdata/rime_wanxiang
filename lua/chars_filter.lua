-- 字符集过滤器模块
-- 用于过滤输入候选项，只显示指定字符集内的汉字
local charsfilter = {}

-- 初始化函数，在模块加载时调用
function charsfilter.init(env)
    -- 使用 ReverseLookup 方法加载字符集，从 aipara_charset 方案中获取字符集定义
    env.charset = ReverseLookup("aipara_charset")
    -- 创建缓存表，用于存储字符检查结果，提高性能
    env.memo = {}
end

-- 清理函数，在模块卸载时调用
function charsfilter.fini(env)
    -- 清空字符集引用
    env.charset = nil
    -- 清空缓存表
    env.memo = nil
    -- 手动触发垃圾回收，释放内存
    collectgarbage()
end

-- 主过滤函数，处理候选项列表
function charsfilter.func(t_input, env)
    -- 获取字符集过滤开关状态
    local extended = env.engine.context:get_option("charset_filter")

    -- 如果字符集过滤已关闭、字符集未加载或处于反查模式，则不进行过滤
    if extended or env.charset == nil or charsfilter.IsReverseLookup(env) then
        -- 直接输出所有候选项，不进行过滤
        for cand in t_input:iter() do
            yield(cand)
        end
    else
        -- 进行字符集过滤
        for cand in t_input:iter() do
            -- 如果是单个汉字且在指定字符集内，则输出该候选项
            if charsfilter.IsSingleChineseCharacter(cand.text) and charsfilter.InCharset(env, cand.text) then
                yield(cand)
            -- 如果不是单个汉字（可能是词组、标点符号等），直接放行
            elseif not charsfilter.IsSingleChineseCharacter(cand.text) then
                -- 对于非汉字字符，直接放行
                yield(cand)
            end
            -- 单个汉字但不在字符集内的候选项会被过滤掉（不输出）
        end
    end
end

-- 检查文本是否为单个汉字
-- 参数: text - 要检查的文本
-- 返回: boolean - 如果是单个汉字返回 true，否则返回 false
function charsfilter.IsSingleChineseCharacter(text)
    -- 检查文本长度是否为1且是汉字
    return utf8.len(text) == 1 and charsfilter.IsChineseCharacter(text)
end

-- 判断字符是否为汉字（包括各种扩展字符集）
-- 参数: text - 要检查的单个字符
-- 返回: boolean - 如果是汉字返回 true，否则返回 false
function charsfilter.IsChineseCharacter(text)
    -- 获取字符的 Unicode 码点
    local codepoint = utf8.codepoint(text)
    -- 检查码点是否在各个汉字Unicode区间内
    return (codepoint >= 0x4E00 and codepoint <= 0x9FFF)  -- CJK 统一汉字基本区
        or (codepoint >= 0x3400 and codepoint <= 0x4DBF)  -- CJK 统一汉字扩展A区
        or (codepoint >= 0x20000 and codepoint <= 0x2A6DF) -- CJK 统一汉字扩展B区
        or (codepoint >= 0x2A700 and codepoint <= 0x2B73F) -- CJK 统一汉字扩展C区
        or (codepoint >= 0x2B740 and codepoint <= 0x2B81F) -- CJK 统一汉字扩展D区
        or (codepoint >= 0x2B820 and codepoint <= 0x2CEAF) -- CJK 统一汉字扩展E区
        or (codepoint >= 0x2CEB0 and codepoint <= 0x2EBE0) -- CJK 统一汉字扩展F区
        or (codepoint >= 0x30000 and codepoint <= 0x3134A) -- CJK 统一汉字扩展G区
        or (codepoint >= 0x31350 and codepoint <= 0x323AF) -- CJK 统一汉字扩展H区
        or (codepoint >= 0x2EBF0 and codepoint <= 0x2EE5F) -- CJK 统一汉字扩展I区
        or (codepoint >= 0xF900 and codepoint <= 0xFAFF)  -- CJK 兼容汉字
        or (codepoint >= 0x2F800 and codepoint <= 0x2FA1F) -- CJK 兼容汉字补充
        or (codepoint >= 0x2E80 and codepoint <= 0x2EFF)  -- CJK 部首补充
        or (codepoint >= 0x2F00 and codepoint <= 0x2FDF)  -- 康熙部首
end

-- 检查文本中的所有字符是否都在指定字符集内
-- 参数: env - 环境对象，包含字符集信息
-- 参数: text - 要检查的文本
-- 返回: boolean - 如果所有字符都在字符集内返回 true，否则返回 false
function charsfilter.InCharset(env, text)
    -- 遍历文本中的每个字符
    for i, codepoint in utf8.codes(text) do
        -- 如果任何一个字符不在字符集内，返回 false
        if not charsfilter.CodepointInCharset(env, codepoint) then
            return false
        end
    end
    -- 所有字符都在字符集内，返回 true
    return true
end

-- 检查单个字符码点是否在字符集内（带缓存优化）
-- 参数: env - 环境对象，包含字符集信息和缓存
-- 参数: codepoint - 字符的Unicode码点
-- 返回: boolean - 如果字符在字符集内返回 true，否则返回 false
function charsfilter.CodepointInCharset(env, codepoint)
    -- 如果已经缓存过该字符的处理结果，直接返回缓存结果
    if env.memo[codepoint] ~= nil then
        return env.memo[codepoint]
    end

    -- 将码点转换为字符
    local char = utf8.char(codepoint)
    -- 在字符集中查找该字符，如果查找结果不为空字符串，说明字符在字符集内
    local res = env.charset:lookup(char) ~= ""
    -- 将结果缓存起来，避免重复查找
    env.memo[codepoint] = res
    return res
end

-- 检查当前是否处于反查模式
-- 参数: env - 环境对象
-- 返回: boolean - 如果处于反查模式返回 true，否则返回 false
function charsfilter.IsReverseLookup(env)
    -- 获取当前输入上下文的最后一个段落
    local seg = env.engine.context.composition:back()
    -- 如果没有段落，说明不在反查模式
    if not seg then
        return false
    end
    -- 检查段落是否包含反查相关的标签
    return seg:has_tag("radical_lookup")      -- 部件反查
        or seg:has_tag("reverse_stroke")      -- 笔画反查
        or seg:has_tag("add_user_dict")       -- 添加用户词典
end

-- 返回模块对象
return charsfilter
