-- lua/script_backtick_translator.lua
-- 使用脚本翻译器处理反引号切分输入的translator
-- 通过text_splitter.split_by_backtick函数切分输入，对abc类型片段使用script_translator翻译

local text_splitter = require("text_splitter")
local logger_module = require("logger")
local debug_utils = require("debug_utils")

-- 创建当前模块的日志记录器
local logger = logger_module.create("script_backtick_translator", {
    enabled = false  -- 启用日志以便调试
})

local script_backtick_translator = {}

local backtick_delimiter_before = ""  -- 反引号分隔符
local backtick_delimiter_after = ""
local replace_punct_enabled = false

-- 只在选词完成后回调, 判断当前输入内容当中, 第一个字符是否反引号,
-- 如果是反引号片段,则再次发送一次确认，确认当前第一个候选项.
local function backtick_before(context)
    -- logger:info("选择通知器: 处理反引号片段自动上屏开始")
    -- 防止递归
    if context:get_option("_bt_auto") then
        return 
    end
    context:set_option("_bt_auto", true)

    -- 连续确认后续带有 backtick 标记的片段
    logger:info("选择通知器: 开始处理反引号片段自动上屏")
    logger:info("context:is_composing(): " .. tostring(context:is_composing()))
    if context:is_composing() then
        local composition = context.composition
        local segment  = composition:back()       -- 当前光标所在段
        -- debug_utils.print_segment_info(segment, logger)

        local input = context.input
        -- 对input进行切片
        local segment_input = input:sub(segment.start + 1, segment._end)  -- 获取当前段的输入内容
        logger:info("当前段的输入内容: " .. segment_input)

        -- 检查当前seg对应的input, 是否以反引号开头,如果是以反引号开头,则提取出反引号包裹的范围, 直接确认选择.
        if segment and segment_input:match("^`") then
            logger:info("当前段是反引号片段，选择第一个候选项")
            -- context:commit()
            if context:confirm_current_selection() then
                logger:info("确认当前选择成功")
            else
                logger:error("确认当前选择失败")
            end
        end     
    end

  context:set_option("_bt_auto", false)
end

function script_backtick_translator.init(env)
    logger:info("脚本反引号翻译器初始化开始")
    -- 清空日志文件
    logger:clear()

    local engine = env.engine
    local config = engine.schema.config

    -- 读取反引号分隔符配置
    backtick_delimiter_before = config:get_string("translator/backtick_delimiter_before") or ""
    backtick_delimiter_after = config:get_string("translator/backtick_delimiter_after") or ""
    replace_punct_enabled = config:get_string("translator/replace_punct_enabled") or false
    -- logger:info("反引号分隔符设置: '" .. backtick_delimiter_before .. "' '" .. backtick_delimiter_after .. "'")

    env.single_fuzhu = config:get_bool("aux_code/single_fuzhu") or false
    -- fuzhu_mode : "before"   # 辅助模式有三种: 1.single只当input中有三个字符的时候进行匹配 2. all全部都匹配
    env.fuzhu_mode = config:get_string("aux_code/fuzhu_mode") or ""

    -- 创建script_translator组件
    env.script_translator = Component.Translator(engine, "translator", "script_translator")
    env.user_dict_set_translator = Component.Translator(engine, "user_dict_set", "script_translator")

    if env.script_translator then
        logger:info("成功创建script_translator组件")
    else
        logger:error("创建script_translator组件失败")
    end
    
    if env.user_dict_set_translator then
        logger:info("成功创建user_dict_set_translator组件")
    else
        logger:error("创建user_dict_set_translator组件失败")
    end
    
    logger:info("脚本反引号翻译器初始化完成")

    -- 监听选词事件
    engine.context.select_notifier:connect(backtick_before)

end



-- 使用两个translator获取多个候选词，返回完整的Candidate列表
local function get_candidates(input, seg, env, max_count, allow_fallback)
    if not env.script_translator or not env.user_dict_set_translator then
        logger:error("script_translator 或 user_dict_set_translator未初始化")
        return {}
    end

    logger:info()
    logger:info("开始使用get_candidates获取候选词, 最大候选词数max_count: " .. max_count .. ", 允许长度不足补全: " .. tostring(allow_fallback))
    logger:info("查询两个translator，输入: " .. input .. ", 最大候选词数: " .. max_count)
    
    local valid_candidates = {}  -- 存储长度匹配的候选词
    local fallback_candidates = {}  -- 存储长度最长的候选词作为备选
    local segment_length = #input  -- segment的长度就是input的长度
    
    -- 先尝试从 script_translator 获取候选词
    logger:info("尝试从 script_translator 获取候选词...")
    local success1, translation1 = pcall(function()
        return env.script_translator:query(input, seg)
    end)
    
    if success1 and translation1 then
        local count1 = 0
        for cand in translation1:iter() do
            count1 = count1 + 1
            local cand_length = cand._end - cand.start
            logger:info(string.format("script_translator候选词 %d: '%s', 长度: %d, segment长度: %d", 
                count1, cand.text, cand_length, segment_length))
            
            if cand_length == segment_length then
                table.insert(valid_candidates, cand)
                logger:info(string.format("script_translator候选词长度匹配，添加: '%s'", cand.text))
                
                -- 如果已经找到足够的候选词，直接返回
                if #valid_candidates >= max_count then
                    logger:info("从script_translator已获取足够数量的候选词，直接返回")
                    return valid_candidates, false  -- 返回是否使用了fallback
                end
            else
                -- 只有允许fallback时才收集备选候选词
                if allow_fallback then
                    table.insert(fallback_candidates, {cand = cand, length = cand_length})
                    logger:info(string.format("script_translator候选词长度不匹配，添加到备选列表: '%s'", cand.text))
                else
                    logger:info(string.format("script_translator候选词长度不匹配，不允许fallback，跳过: '%s'", cand.text))
                end
            end
            
            -- 限制遍历数量，只遍历前max_count个
            if count1 >= max_count then
                logger:info("script_translator已遍历" .. max_count .. "个候选词，停止遍历")
                break
            end
        end
    else
        logger:error("调用script_translator失败: " .. tostring(translation1))
    end
    
    -- 如果第一个translator的候选词不足，尝试从 user_dict_set_translator 获取
    if #valid_candidates < max_count and env.user_dict_set_translator then
        logger:info("script_translator候选词不足，尝试从 user_dict_set_translator 获取...")
        local success2, translation2 = pcall(function()
            return env.user_dict_set_translator:query(input, seg)
        end)
        
        if success2 and translation2 then
            local count2 = 0
            for cand in translation2:iter() do
                count2 = count2 + 1
                local cand_length = cand._end - cand.start
                logger:info(string.format("user_dict_set_translator候选词 %d: '%s', 长度: %d, segment长度: %d", 
                    count2, cand.text, cand_length, segment_length))
                
                if cand_length == segment_length then
                    table.insert(valid_candidates, cand)
                    logger:info(string.format("user_dict_set_translator候选词长度匹配，添加: '%s'", cand.text))
                    
                    -- 如果已经找到足够的候选词，停止
                    if #valid_candidates >= max_count then
                        logger:info("已获取足够数量的候选词，停止获取")
                        break
                    end
                else
                    -- 只有允许fallback时才收集备选候选词
                    if allow_fallback then
                        table.insert(fallback_candidates, {cand = cand, length = cand_length})
                        logger:info(string.format("user_dict_set_translator候选词长度不匹配，添加到备选列表: '%s'", cand.text))
                    else
                        logger:info(string.format("user_dict_set_translator候选词长度不匹配，不允许fallback，跳过: '%s'", cand.text))
                    end
                end
                
                -- 限制遍历数量，只遍历前max_count个
                if count2 >= max_count then
                    logger:info("user_dict_set_translator已遍历" .. max_count .. "个候选词，停止遍历")
                    break
                end
            end
        else
            logger:error("调用user_dict_set_translator失败: " .. tostring(translation2))
        end
    elseif not env.user_dict_set_translator then
        logger:info("user_dict_set_translator未初始化")
    end
    
    local used_fallback = false
    
    -- 如果没有长度匹配的候选词，且允许fallback，使用长度最长的备选方案
    if #valid_candidates == 0 and #fallback_candidates > 0 and allow_fallback then
        logger:info("没有长度匹配的候选词，使用长度最长的备选方案")
        used_fallback = true
        
        -- 按长度降序排序
        table.sort(fallback_candidates, function(a, b)
            return a.length > b.length
        end)
        
        -- 选择长度最长的max_count个候选词
        for i = 1, math.min(#fallback_candidates, max_count) do
            table.insert(valid_candidates, fallback_candidates[i].cand)
            logger:info(string.format("使用备选候选词 %d: '%s', 长度: %d", 
                i, fallback_candidates[i].cand.text, fallback_candidates[i].length))
        end
    end
    
    if #valid_candidates == 0 then
        logger:info("未获取到任何候选词，返回空列表")
    else
        logger:info("共获取到 " .. #valid_candidates .. " 个候选词" .. (used_fallback and " (使用了fallback)" or ""))
        for i, cand in ipairs(valid_candidates) do
            logger:info(string.format("最终候选词 %d: '%s'", i, cand.text))
        end
    end
    logger:info() 
    return valid_candidates, used_fallback
end

function script_backtick_translator.func(input, seg, env)
    local context = env.engine.context

    logger:info("")
    logger:info("")
    logger:info("开始处理输入: " .. input)

    -- 检查输入如果长度是1,则不处理
    if #input == 1 then
        logger:info("输入长度为1，不处理")
        return
    end

    -- 检查输入是否包含反引号标签
    if not seg:has_tag("backtick") then
        logger:info("没有包含backtick标签，不处理")
        return
    end
    logger:info("含有backtick标签, 进入反引号translator")
    -- if not input:match("`") then
    --     logger:info("输入不包含反引号，不处理")
    --     return
    -- end
    
    -- 使用text_splitter.split_by_backtick切分输入
    -- 这里输入的input应该不是完整的input,而是剩余的seg当中的input,所以返回的也是这个结果,但是我需要确认前边已经有多少内容被确认了. 
    local segments = text_splitter.split_by_backtick_with_log(input, backtick_delimiter_before, backtick_delimiter_after, logger)
    
    if not segments or #segments == 0 then
        logger:error("切分失败或无结果")
        return
    end

    -- 检查第一个片段是否为backtick类型，若是则直接commit_text并返回
    if segments[1].type == "backtick" then
        -- 还要考虑新的可能性: 如果是只有一个反引号开头，如何判断
        -- 如果是单引号开头，然后后面跟着一些字母，或者其他内容，反引号暂时未闭合，如何处理？
        -- 如果是一个完整的反引号包裹的内容，如何处理？
        -- 判断,如果segments中只有一个元素,并且是backtick类型,

        -- 获取segment的基本信息
        local start_pos = seg.start    -- 片段开始位置
        local end_pos = seg._end       -- 片段结束位置  
        local length = seg.length      -- 片段长度
        local status = seg.status      -- 片段状态
        -- 打印信息
        logger:info(string.format("片段信息: start=%d, end=%d, length=%d, status=%s", start_pos, end_pos, length, status))
        -- 打印开始和结束位置
        logger:info(string.format("片段开始位置: %d, 结束位置: %d", segments[1].start, segments[1]._end))
        local cand_temp = Candidate("sentence", seg.start, seg.start + segments[1].length , segments[1].content, "   [英文]")
        yield(cand_temp)

        return
    end

    -- 处理每个片段，收集每个片段的候选词
    local segment_candidates = {}  -- 存储每个片段的候选词列表
    local used_fallback = false  -- 记录是否使用了fallback
    local fallback_length_diff = 0  -- 记录fallback导致的长度差异
    local delete_last_code = false  -- 紧挨着反引号的一个单独字母情况下
    local script_fail_code = 0  -- 反引号后面没有匹配成功的几位字母

    for i, segment in ipairs(segments) do
        local candidates_for_segment = {}
        
        if segment.type == "abc" then
            -- 文本片段：使用两个translator翻译
            logger:info(string.format("处理文本片段 %d: '%s'", i, segment.content))
            
            -- 判断是否允许使用fallback：只有最后一个segment且类型为abc时允许
            local is_last_segment = (i == #segments)
            local allow_fallback = is_last_segment
            logger:info(string.format("片段 %d, 是否最后一个: %s, 允许fallback: %s", i, tostring(is_last_segment), tostring(allow_fallback)))
            
            -- todo
            -- 判断是否开启辅助码all模式
            local segment_content = segment.content
            if env.single_fuzhu and env.fuzhu_mode == "all" then
                -- 当最后一个seg, 如果有奇数个字母, 则放弃最后一个, 不获取它的候选词

                -- 对于标点符号来说，是不能算在内的，首先判断是否存在标点符号，如果存在标点符号，就替换掉，然后再计算。
                if is_last_segment then
                    -- 检查输入是否包含标点符号
                    local has_punctuation = segment_content:match("[,.!?;:()%[%]<>/_=+*&^%%$#@~|%-'\"']") ~= nil

                    if has_punctuation then
                        logger:debug("有标点符号")
                        -- 删除segmente_input中的所有标点符号
                        local segment_content_nopunc = segment_content:gsub("[,.!?;:()%[%]<>/_=+*&^%%$#@~|%-'\"']", "")
                        logger:debug("删除标点符号后的segment_content: " .. segment_content_nopunc)
                        
                        if #segment_content_nopunc % 2 == 1 then
                            segment_content = segment_content:sub(1, -2)
                            delete_last_code = true
                            logger:info("调整后segment_content: " .. segment_content)
                        end
                    else
                        if #segment_content % 2 == 1 then
                            segment_content = segment_content:sub(1, -2)
                            delete_last_code = true
                            logger:info("调整后segment_content: " .. segment_content)
                        end
                        
                    end

                end

            end

            -- 如果 segment_content == "" 则不向candidates_for_segment 中添加候选词
            if segment_content == "" then
                -- 直接开始下一次循环
                goto continue
            else
                local candidates, segment_used_fallback = get_candidates(segment_content, seg, env, 2, allow_fallback)
                -- segment_used_fallback就是获取的候选项长度不足整个片段的长度. 当我把 wok 变成 wo传进去,长度应该还是满足的
                logger:info("get_candidates返回segment_used_fallback: " ..tostring(segment_used_fallback))
                
                -- 如果没有获取返回候选项, 说明传入的不是合并的拼音,则忽略这项
                if #candidates == 0 then
                    -- 输入了几个字母, cand._end就需要向前移动几位
                    script_fail_code = segment.length
                    goto continue
                end

                -- 如果当前segment使用了fallback，更新全局fallback状态
                if segment_used_fallback then
                    used_fallback = true
                    logger:info("used_fallback: " ..tostring(used_fallback))
                    -- 计算长度差异（最长候选词长度 - segment长度）

                    -- 这个地方整个长度计算是错误的: 应该是长度 segment.length 大于 候选词长度, 
                    -- 对于整个分词例如 nihkdd 没有找到完整的候选词,只匹配了 nihk, 因此候选词的长度更低
                    if #candidates > 0 then
                        local cand = candidates[1]
                        local cand_length = cand._end - cand.start
                        fallback_length_diff = #segment.content - cand_length
                        logger:info(string.format("使用fallback，fallback_length_diff差异: %d", fallback_length_diff))
                    end
                end
                
                -- 遍历candidates并打印属性值
                logger:info("获取到 " .. #candidates .. " 个候选词" .. (segment_used_fallback and " (使用了fallback)" or "") .. ":")
                for index, cand in ipairs(candidates) do
                    logger:info(string.format("候选词 %d: '%s'", index, cand.text))
                    
                    -- 由于get_candidates已经完成长度检查，直接添加到候选列表
                    table.insert(candidates_for_segment, {
                        text = cand.text,

                        -- 如果减少了一位, 这里就是 wo, 
                        preedit = cand.preedit or segment.content,

                        -- 添加spans数据
                        spans = cand:spans()
                    })
                    logger:info(string.format("候选词 %d 已添加到segment候选列表", index))
                end
                
                -- -- 如果没有匹配的候选词，使用原内容
                -- if #candidates_for_segment == 0 then
                --     table.insert(candidates_for_segment, {
                --         text = segment.content,
                --         preedit = segment.content
                --     })
                --     logger:info("没有匹配的候选词，使用原内容")
                -- end                
                            
            end

    
        elseif segment.type == "backtick" then
            -- 反引号内容：固定一个候选项
            logger:info(string.format("处理反引号片段 %d: '%s'", i, segment.content))
            -- 对于反引号部分, 自己生成一个spans, backtick
            local backtick_spans = Spans()
            backtick_spans:add_span(segment.start, segment._end)

            table.insert(candidates_for_segment, {
                text = segment.content,
                preedit = segment.original or segment.content,
                spans = backtick_spans
            })
                    
            
        else
            -- 其他类型：保持原样
            logger:info(string.format("处理其他类型片段 %d: type=%s, content='%s'", i, segment.type, segment.content))
            local other_spans = Spans()
            other_spans:add_span(segment.start, segment._end)
            table.insert(candidates_for_segment, {
                text = segment.content,
                preedit = segment.content,
                spans = other_spans
            })
                    
        end

                                
        segment_candidates[i] = candidates_for_segment
        logger:info(string.format("片段 %d 收集到 %d 个候选项", i, #candidates_for_segment))

        ::continue::
    end
    
    -- 生成所有可能的组合
    local function generate_combinations(segment_lists, current_combination, current_index, all_combinations)
        if current_index > #segment_lists then
            -- 达到末尾，保存当前组合
            table.insert(all_combinations, current_combination)
            return
        end
        
        -- 遍历当前片段的所有候选词
        for _, candidate in ipairs(segment_lists[current_index]) do
            local new_combination = {}
            -- 复制当前组合
            for j = 1, #current_combination do
                new_combination[j] = current_combination[j]
            end
            -- 添加新的候选词
            table.insert(new_combination, candidate)
            
            -- 递归处理下一个片段
            generate_combinations(segment_lists, new_combination, current_index + 1, all_combinations)
        end
    end
    
    local all_combinations = {}
    generate_combinations(segment_candidates, {}, 1, all_combinations)
    
    logger:info("共生成 " .. #all_combinations .. " 个组合")
    
    -- 输出每个组合作为候选词，最多输出4个
    local output_count = 0
    local max_output = 4
    
    for combo_index, combination in ipairs(all_combinations) do
        if output_count >= max_output then
            logger:info("已达到最大输出数量限制 " .. max_output .. "，停止输出")
            break
        end
        
        local final_text = ""
        local final_preedit = ""
        
        for _, segment_cand in ipairs(combination) do
            final_text = final_text .. segment_cand.text
            final_preedit = final_preedit .. segment_cand.preedit
            -- 计算segment_cand的spans:
            -- 如果是abc类型的: spans应该是从0开始计算的, 当前片段长度10, 0-10,中间有一些分割点
            -- 如果是第一个段,则不用改变, 如果是第三段, 则应该在所有分割点信息当中添加上前两段的长度.

        end
        
        logger:info(string.format("组合 %d: text='%s', preedit='%s'", combo_index, final_text, final_preedit))
        
        -- 如果最终结果与原输入不同，则输出候选词
        if final_text ~= input and final_text ~= "" then
            -- 如果使用了fallback，需要调整候选词的结束位置
            local candidate_end = seg._end
            if delete_last_code then
                -- 如果删除了奇数个字母最后一个, 则seg向左移动一位
                candidate_end = candidate_end - 1
            end

            if script_fail_code > 0 then
                -- 最后一段abc如果没有匹配成功任何候选词的情况下, 向前移动
                candidate_end = candidate_end - script_fail_code
            end

            logger:info("used_fallback的值: " .. tostring(used_fallback) .. "  fallback_length_diff的值: " .. tostring(fallback_length_diff))
            if used_fallback and fallback_length_diff > 0 then
                logger:info(string.format("使用了fallback，调整候选词结束位置: %d -> %d (差异: %d)", seg._end, candidate_end, fallback_length_diff))
                candidate_end = seg._end - fallback_length_diff
            end
            
            local candidate = Candidate("sentence", seg.start, candidate_end, final_text, string.format("   [组合%d]", combo_index))
            candidate.preedit = final_preedit
            yield(candidate)
            output_count = output_count + 1
            logger:info(string.format("输出组合候选词 %d: text='%s', preedit='%s' (第%d个输出), end=%d", combo_index, final_text, final_preedit, output_count, candidate_end))
        end
    end

end

function script_backtick_translator.fini(env)
    env.notifier:disconnect()
    logger:info("脚本反引号翻译器结束运行")
end

return script_backtick_translator
