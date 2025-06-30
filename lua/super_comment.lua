--@amzxyz https://github.com/amzxyz/rime_wanxiang
--由于comment_format不管你的表达式怎么写，只能获得一类输出，导致的结果只能用于一个功能类别
--如果依赖lua_filter载入多个lua也只能实现一些单一的、不依赖原始注释的功能，有的时候不可避免的发生一些逻辑冲突
--所以此脚本专门为了协调各式需求，逻辑优化，实现参数自定义，功能可开关，相关的配置跟着方案文件走，如下所示：
--将如下相关位置完全暴露出来，注释掉其它相关参数--
--  comment_format: {comment}   #将注释以词典字符串形式完全暴露，通过super_comment.lua完全接管。
--  spelling_hints: 10          # 将注释以词典字符串形式完全暴露，通过super_comment.lua完全接管。
--在方案文件顶层置入如下设置--
--#Lua 配置: 超级注释模块
--super_comment:                     # 超级注释，子项配置 true 开启，false 关闭
--  # 以下为 pro 版专用配置
--  fuzhu_code: true                 # 启用辅助码提醒，用于辅助输入练习辅助码，成熟后可关闭
--  # 以下为通用配置
--  candidate_length: 1              # 候选词辅助码提醒的生效长度，0为关闭  但同时清空其它，应当使用上面开关来处理
--  corrector: true                  # 启用错音错词提醒，例如输入 geiyu 给予 获得 jǐ yǔ 提示
--  corrector_type: "{comment}"      # 新增一个提示类型，比如"【{comment}】"
--  fuzhu_type: moqi, flypy, zrm, jdh, tiger, wubi, hanxin tone fuzhu(分包使用时代表整体分号后面)
local wanxiang = require('wanxiang')
local patterns = {
    fuzhu = "[^;];(.+)$",
    tone = "([^;]*);",
    moqi = "[^;]*;([^;]*);",
    flypy = "[^;]*;[^;]*;([^;]*);",
    zrm = "[^;]*;[^;]*;[^;]*;([^;]*);",
    jdh = "[^;]*;[^;]*;[^;]*;[^;]*;([^;]*);",
    tiger = "[^;]*;[^;]*;[^;]*;[^;]*;[^;]*;([^;]*);",
    wubi = "[^;]*;[^;]*;[^;]*;[^;]*;[^;]*;[^;]*;([^;]*);",
    hanxin = "[^;]*;[^;]*;[^;]*;[^;]*;[^;]*;[^;]*;[^;]*;([^;]*)"
}
-- #########################
-- # 辅助码拆分提示模块 (chaifen)
-- PRO 专用
-- #########################
local CF = {}
function CF.init(env)
    if wanxiang.is_pro_scheme(env) then -- pro 版直接初始化
        CF.get_dict(env)
    end
end

function CF.fini(env)
    env.chaifen_dict = nil
    collectgarbage()
end

function CF.get_dict(env)
    if env.chaifen_dict == nil then
        env.chaifen_dict = ReverseLookup("wanxiang_lookup")
    end
    return env.chaifen_dict
end

function CF.get_comment(cand, env)
    local dict = CF.get_dict(env)
    if not dict then return "" end

    local raw = dict:lookup(cand.text)
    if raw == "" then return "" end
    -- 跳过 tone 类型
    local fuzhu_type = env.settings.fuzhu_type or ""
    if fuzhu_type == "tone" then
        return ""
    end
    -- 辅助码类型 → 圈字映射
    local mark_map = {
        hanxin = "Ⓐ",
        jdh    = "Ⓑ",
        tiger  = "Ⓒ",
        flypy  = "Ⓓ",
        moqi   = "Ⓔ",
        zrm    = "Ⓕ",
        wubi   = "Ⓖ"
    }
    local fuzhu_type = env.settings.fuzhu_type or ""
    local mark = mark_map[fuzhu_type]
    if not mark then return raw end  -- 如果没有匹配的圈字，返回整个 raw

    -- 拆分各字注释段（按空格、或用 %s 拆分多个注释块）
    local segments = {}
    for segment in raw:gmatch("[^%s]+") do
        table.insert(segments, segment)
    end
    -- 遍历查找包含指定圈字的片段
    for _, seg in ipairs(segments) do
        if seg:find(mark, 1, true) then
            -- 去除圈字标志，返回剩余内容
            return seg:gsub(mark, "", 1)
        end
    end
    return raw  -- 如果没有任何片段含圈字，也返回原始内容
end

-- #########################
-- # 错音错字提示模块 (Corrector)
-- #########################
local CR = {}
local corrections_cache = nil -- 用于缓存已加载的词典
function CR.init(env)
    CR.style = env.settings.corrector_type or '{comment}'
    --if corrections_cache then return end
    local auto_delimiter = env.settings.auto_delimiter
    local is_pro = wanxiang.is_pro_scheme(env)
    -- 根据方案选择加载路径
    local path = (is_pro and "zh_dicts_pro/corrections.dict.yaml") or "zh_dicts/corrections.dict.yaml"
    local file, close_file, err = wanxiang.load_file_with_fallback(path)
    if not file then
        log.error(string.format("[super_comment]: 加载失败 %s，错误: %s", path, err))
        return
    end
    corrections_cache = {}
    for line in file:lines() do
        if not line:match("^#") then
            local text, code, weight, comment = line:match("^(.-)\t(.-)\t(.-)\t(.-)$")
            if text and code then
                text = text:match("^%s*(.-)%s*$")
                code = code:match("^%s*(.-)%s*$")
                comment = comment and comment:match("^%s*(.-)%s*$") or ""
                comment = comment:gsub("%s+", auto_delimiter)
                code = code:gsub("%s+", auto_delimiter)
                corrections_cache[code] = { text = text, comment = comment }
            end
        end
    end
    close_file()
end

function CR.get_comment(cand)
    -- 使用候选词的 comment 作为 code，在缓存中查找对应的修正
    local correction = nil
    if corrections_cache then
        correction = corrections_cache[cand.comment]
    end
    if correction and cand.text == correction.text then
        -- 用新的注释替换默认注释
        local final_comment = CR.style:gsub("{comment}", correction.comment)
        return final_comment
    end
    return nil
end

-- ################################
-- 部件组字返回的注释（radical_pinyin）
-- ################################
---@return string
local function get_az_comment(_, env, initial_comment)
    if not initial_comment or initial_comment == "" then return "" end
    local final_comment = nil
    local auto_delimiter = env.settings.auto_delimiter or " "
    -- 拆分各字注释段
    local segments = {}
    for segment in initial_comment:gmatch("[^%s]+") do
        table.insert(segments, segment)
    end
    local semicolon_count = select(2, segments[1]:gsub(";", "")) -- 使用第一个段判断
    local pinyins = {}
    local fuzhu = nil
    for _, segment in ipairs(segments) do
        local pinyin = segment:match("^[^;]+")
        local fz = nil

        if semicolon_count == 0 then
            -- 无分号，只收集拼音
            fz = nil
        elseif semicolon_count == 1 then
            -- 一个分号，取后段
            fz = segment:match(";(.+)$")
        else
            -- 多个分号，使用模式提取
            local pattern = patterns[env.settings.fuzhu_type]
            if pattern then
                fz = segment:match(pattern)
            end
        end

        if pinyin then table.insert(pinyins, pinyin) end
        if not fuzhu and fz and fz ~= "" then fuzhu = fz end
    end
    -- 拼接结果
    if #pinyins > 0 then
        local pinyin_str = table.concat(pinyins, ",")
        if fuzhu then
            final_comment = string.format("〔音%s 辅%s〕", pinyin_str, fuzhu)
        else
            final_comment = string.format("〔音%s〕", pinyin_str)
        end
    end
    return final_comment or ""
end
-- #########################
-- # 辅助码提示或带调全拼注释模块 (Fuzhu)
-- #########################
local function get_fz_comment(cand, env, initial_comment)
    local length = utf8.len(cand.text)
    if length > env.settings.candidate_length then
        return ""
    end
    local auto_delimiter = env.settings.auto_delimiter or " "
    local segments = {}
    for segment in string.gmatch(initial_comment, "[^" .. auto_delimiter .. "]+") do
        table.insert(segments, segment)
    end

    -- 根据 option 动态决定是否强制使用 tone
    local use_tone = env.engine.context:get_option("tone_hint")
    local fuzhu_type = use_tone and "tone" or env.settings.fuzhu_type

    local first_segment = segments[1] or ""
    local semicolon_count = select(2, first_segment:gsub(";", ""))
    local fuzhu_comments = {}
    -- 没有分号的情况
    if semicolon_count == 0 then
        return initial_comment:gsub(auto_delimiter, " ")
    else   -- 有分号的情况根据类型选择
        local pattern = patterns[fuzhu_type]
        if pattern then
            for _, segment in ipairs(segments) do
                local match = segment:match(pattern)
                if match then
                    table.insert(fuzhu_comments, match)
                end
            end
        else
            return ""
        end
    end
    -- 最终拼接输出，fuzhu用 `,`，tone用 /连接
    if #fuzhu_comments > 0 then
        if fuzhu_type == "tone" then
            return table.concat(fuzhu_comments, " ")
        else
            return table.concat(fuzhu_comments, "/")
        end
    else
        return ""
    end
end


-- #########################
-- 主函数：根据优先级处理候选词的注释
-- #########################
local ZH = {}
function ZH.init(env)
    local config = env.engine.schema.config
    local delimiter = config:get_string('speller/delimiter') or " '"
    local auto_delimiter = delimiter:sub(1, 1)
    env.settings = {
        delimiter = delimiter,
        auto_delimiter = auto_delimiter,
        corrector_enabled = config:get_bool("super_comment/corrector") or true,
        corrector_type = config:get_string("super_comment/corrector_type") or "{comment}",
        candidate_length = tonumber(config:get_string("super_comment/candidate_length")) or 1,
        fuzhu_type = config:get_string("super_comment/fuzhu_type") or ""
    }
    CR.init(env)
end
function ZH.fini(env)
    -- 清理
    CF.fini(env)
end
function ZH.func(input, env)
    local is_radical_mode = wanxiang.is_in_radical_mode(env)
    local index = 0
    local input_str = env.engine.context.input
    local should_skip_candidate_comment = input_str and input_str:match("^[VRNU/]")
    local is_comment_hint = env.engine.context:get_option("fuzhu_hint")
    local is_tone_comment = env.engine.context:get_option("tone_hint")
    local is_chaifen_enabled = env.engine.context:get_option("chaifen_switch")

    for cand in input:iter() do
        index = index + 1

        -- -- 豁免百度云候选词
        -- if cand.type == "baidu_cloud" then
        --     yield(cand)
        --     goto continue
        -- end
        if should_skip_candidate_comment then
            yield(cand)
            goto continue
        end

        local initial_comment = cand.comment
        local final_comment = initial_comment

        -- ① 辅助码注释或者声调注释
        if is_comment_hint or is_tone_comment then
            local fz_comment = get_fz_comment(cand, env, initial_comment)
            if fz_comment then
                final_comment = fz_comment
            end
        else
            final_comment = ""
        end

        -- ② 拆分注释
        if is_chaifen_enabled then
            local cf_comment = CF.get_comment(cand, env)
            if cf_comment and cf_comment ~= "" then  --不为空很重要
                final_comment = cf_comment
            end
        end

        -- ③ 错音错字提示
        if env.settings.corrector_enabled then
            local cr_comment = CR.get_comment(cand)
            if cr_comment and cr_comment ~= "" then
                final_comment = cr_comment
            end
        end

        -- ④ radical 模式提示
        if is_radical_mode then
            local az_comment = get_az_comment(cand, env, initial_comment)
            if az_comment and az_comment ~= "" then
                final_comment = az_comment
            end
        end

        -- 应用注释
        if final_comment ~= initial_comment then
            cand:get_genuine().comment = final_comment
        end

        yield(cand)
        ::continue::
    end
end
return ZH