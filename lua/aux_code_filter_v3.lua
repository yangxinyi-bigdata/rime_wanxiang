-- 对双拼进行形码的输入
-- 参考: https://github.com/HowcanoeWang/rime-lua-aux-code
-- 升级版本的辅助码匹配,之前只想到匹配第一个字,或者最后一个字,但是发现可以全部都匹配,候选词当中的所有字都进行匹配, 把匹配上的放到前边来.
-- v3升级, 考虑input当中有标点符号的情况.计算计算奇数个和偶数个的时候,删掉所有标点符号.
-- 最后三个字母匹配, 过滤掉长度超过的
-- 候选项当中, 和所有候选项，进行匹配，如果匹配上辅助码的就放到前边来

local logger_module = require("logger")
local debug_utils = require("debug_utils")

-- 创建日志记录器
local logger = logger_module.create("aux_code_filter_v3", {
    enabled = false
})

local aux_code_filter = {}
local last_segment_input = ""

function aux_code_filter.init(env)
    
    logger.clear()
    logger.info("aux_code_filter_v3 init")
    logger.info("=" .. string.rep("=", 60))
    
    local engine = env.engine
    local config = engine.schema.config

    
    env.single_fuzhu = config:get_bool("aux_code/single_fuzhu") or false
    -- fuzhu_mode : "before"   # 辅助模式有三种: 1.single只当input中有三个字符的时候进行匹配 2.before,最后一个辅助码和最前边两个 input 字母进行匹配 3. after,最后一个辅助码和最后两个 input 字母进行匹配
    env.fuzhu_mode = config:get_string("aux_code/fuzhu_mode") or ""
    env.shuangpin_zrm_txt = config:get_string("aux_code/shuangpin_zrm_txt") or ""
    logger.info("shuangpin_zrm_txt: " .. env.shuangpin_zrm_txt)
    aux_code_filter.aux_hanzi_code, aux_code_filter.aux_code_hanzi = aux_code_filter.readAuxTxt(env.shuangpin_zrm_txt)

    ----------------------------
    -- 每一次选词上屏, 判断aux_code_filter.set_fuzhuma的值, 如果存在辅助码就把辅助码删除掉 --
    -- 原来这就是通知消息存在的意义,因为选词之后要进行一些处理,将最后一个辅助码删除掉
    ----------------------------
    env.notifier = engine.context.select_notifier:connect(function(context)
        -- 应该是如何处理了辅助码需要进行
        if not aux_code_filter.set_fuzhuma then
            return
        end
        
        -- 添加错误捕获
        local success, error_msg = pcall(function()
            -- 尝试删除最后一个辅助码
            local input = context.input
            logger.info("select_notifier函数: 选词上屏,输入文本: " .. input)

            -- 删除最后一个辅助码
            context:pop_input(1)
            aux_code_filter.set_fuzhuma = false -- 重置标志位

            input = context.input
            logger.info("删除辅助码后input: " .. input)

            -- 检查删除辅助码后的情况
            local segmentation = context.composition:toSegmentation()
            local confirmed_position = segmentation:get_confirmed_position()
            local unconfirmed_length = #input - confirmed_position
            
            logger.info("confirmed_position=" .. confirmed_position .. ", unconfirmed_length=" .. unconfirmed_length)
            
            -- 当没有未确认的字符时，直接上屏
            if unconfirmed_length == 0 then
                logger.info("没有剩余未确认字符,直接上屏")
                context:commit()
            end

        end)
        
        if not success then
            logger.error("选词上屏处理过程中发生错误: " .. tostring(error_msg))
            -- 重置标志位确保不影响后续操作
            aux_code_filter.set_fuzhuma = false
        end
    end)
    
end

----------------
-- 阅读辅码文件, 功能是将字典文件读取到缓存当中aux_code_filter.cache
-- 貌似不需要更改 --
----------------
function aux_code_filter.readAuxTxt(txtpath)
    if aux_code_filter.cache and aux_code_filter.cache_aux_code_hanzi then
        logger.info("aux_code_filter有缓存")
        return aux_code_filter.cache, aux_code_filter.cache_aux_code_hanzi
    end

    local defaultFile = '20250612_phrases_shuangpin_org.txt'
    local userPath = rime_api.get_user_data_dir() .. "/lua/aux_code/"
    local fileAbsolutePath = userPath .. txtpath .. ".txt"

    local file = io.open(fileAbsolutePath, "r") or io.open(userPath .. defaultFile, "r")
    if not file then
        logger.error("不能打开辅助码文件")
        return {}
    end

    local aux_hanzi_code = {}
    local aux_code_hanzi = {}
    for line in file:lines() do
        line = line:match("[^\r\n]+") -- 去掉換行符，不然 value 是帶著 \n 的
        local key, value = line:match("([^=]+)=(.+)") -- 分割 = 左右的變數
        if key and value then
            aux_hanzi_code[key] = aux_hanzi_code[key] or {}
            table.insert(aux_hanzi_code[key], value)
            -- 将后面的字母作为key, 汉字作为value
            aux_code_hanzi[value] = aux_code_hanzi[value] or {}
            table.insert(aux_code_hanzi[value], key)
        end
    end
    file:close()
    -- 確認 code 能打印出來
    -- for key, value in pairs(aux_code_filter.aux_code) do
    --     log.info(key, table.concat(value, ','))
    -- end

    aux_code_filter.cache = aux_hanzi_code
    aux_code_filter.cache_aux_code_hanzi = aux_code_hanzi
    logger.info("aux_code_filter.cache读取成功")
    return aux_code_filter.cache, aux_code_filter.cache_aux_code_hanzi
end



-- 提取出当前候选词的中文, 和输入的匹配码, 返回是否匹配成功? 
local function fuzhuma_match(match_char, match_code)
    -- 进行辅助码匹配
    -- logger.info("匹配字符: " .. match_char)
    local fuzhuma = aux_code_filter.aux_hanzi_code[match_char] -- 找到字符的辅助码
    if fuzhuma then -- 辅助码存在, 这个字是存在辅助码的
        for _, code in ipairs(fuzhuma) do  -- 对这个字符的所有辅助码进行遍历,为这个一个字符可能有多个不同的辅助码
            if code:sub(3,3) == match_code then  -- 如果辅助码和输入的最后一个字母相同,则匹配成功
                logger.info("匹配成功: match_char: " .. match_char .. "  match_code: " ..match_code)
                return 1
            elseif code:sub(3,3) == "" then
                return 2
            end
        end
    end 

    return 
end

------------------
-- filter 主函数 --
------------------
function aux_code_filter.func(translation, env)
    logger.info("aux_code_filter func")
    local context = env.engine.context
    local input = context.input

    logger.info("")
    logger.info("=== 开始分析lua/aux_code_filter.lua ===")

    
    -- 如果是在反引号模式中, 也不进入, 如果input长度小于3 或者是偶数,也不进入
    -- 如果是剩余的segmente_input小于3,还进不进入呢？按说也应该不进入, 只是我需要在选词之后, 保持set_fuzhuma为真
    -- `haha`w 这个时候,也是反引号模式,应该直接进入下面这个分支, 但要区分 hahaw
    -- 关键是之前设置,如果选词之后只剩一个字母,那么应该删除这个字母,怎么办呢?选词之后,也是只剩一个字母
    logger.info("backtick_prompt: " .. context:get_property("backtick_prompt"))
    if not env.single_fuzhu or #input <=2 or context:get_property("backtick_prompt") == "1" then        
        logger.debug("当前输入#input偶数个或者长度小于等于2, set_fuzhuma设置为false")
        aux_code_filter.set_fuzhuma = false
        for cand in translation:iter() do
            yield(cand)
        end
        return
    end

    local segmentation = context.composition:toSegmentation()
    local current_start = segmentation:get_current_start_position()
    local current_end = segmentation:get_current_end_position()
    local confirmed_position = segmentation:get_confirmed_position()
    local segmente_input = input:sub(current_start + 1, current_end)
    logger.info("segmente_input: " .. segmente_input)

    -- 当#segmente_input为偶数进不来, 只有1能进来, 这时候也就是剩余一个辅助码, 但是在触发选词通知回调函数之前还会运行两次这个代码
    -- 如果在一次选词之后剩余一个字母,那么这个字母是辅助码，马上准备要删掉,也没什么作用.
    if #segmente_input == 1 then
        -- 分成两种情况1. 直接input就是segmente_input, 没有选词过, 则三个字母, 选择了前两个字母, 保留set_fuzhuma的值, 会删除辅助码,然后上屏
        -- 情况2: 多个字,选择了一部分, 如果5个字选择了4个,那么剩余3个,不会进入这个分支, set_fuzhuma原来是true, 选词会出发删除一个辅助码,剩余两个字符.
        -- 情况3: 如果5个字选择了5个字, 进入这个分支,保留set_fuzhuma的值, 会删除辅助码,然后上屏
        
        logger.info("剩余#segmente_input == 1, 什么都不做直接返回, 保持set_fuzhuma : " .. tostring(aux_code_filter.set_fuzhuma))

        -- for cand in translation:iter() do
        --     yield(cand)
        -- end
        return
    end

    local has_backtick = segmente_input:match("`") ~= nil
    if has_backtick then
        -- 将segmente_input中的反引号``包裹的片段删除
        segmente_input = segmente_input:gsub("`[^`]*`", "")
        logger.debug("删除反引号包裹片段后的segmente_input: " .. segmente_input)
        -- -- 如果删除反引号片段之后,只剩下一个字母, 不应该触发删除辅助码
        -- aux_code_filter.set_fuzhuma = false
    end

    -- 检查输入是否包含标点符号
    local last_three_has_punctuation = false
    local has_punctuation = segmente_input:match("[,.!?;:()%[%]<>/_=+*&^%%$#@~|%-'\"']") ~= nil
    if has_punctuation then
        logger.debug("有标点符号")
        last_three_has_punctuation = segmente_input:sub(-3):match("[,.!?;:()%[%]<>/_=+*&^%%$#@~|%-'\"']") ~= nil
        -- 删除segmente_input中的所有标点符号
        segmente_input = segmente_input:gsub("[,.!?;:()%[%]<>/_=+*&^%%$#@~|%-'\"']", "")
        logger.debug("删除标点符号后的segmente_input: " .. segmente_input)
    else
        -- 没有标点符号, 那就是正常长句, 对于这种和原来的处理方案一样
    end

    -- 重新检查删除标点符号后的长度
    if #segmente_input % 2 == 0 or #segmente_input == 1 then
        logger.debug("segmente_input长度是偶数或者长度为1,直接返回")
        aux_code_filter.set_fuzhuma = false
        for cand in translation:iter() do
            yield(cand)
        end
        return

    else
        -- 这个分支是删除标点符号之后,是奇数个字母,应该进行辅助码匹配.

    end
    
    -- local last_three_has_punctuation = segmente_input:sub(-3):match("[,.!?;:()%[%]<>/_=+*&^%%$#@~|%-`'\"']") ~= nil

    debug_utils.print_segmentation_info(segmentation, logger)

    local success, error_msg = pcall(function()

        if last_three_has_punctuation then
            -- 如果最后三位有标点符号,直接输出默认数据, 但我还是希望将超长度的过滤掉
            return false
        end

        logger.info("开始辅助码匹配,输入文本: " .. segmente_input)
        -- 最后一个辅助码
        local last_code = segmente_input:sub(-1)
        logger.info("last_char: " ..last_code)
        -- local auxCodes = aux_code_filter.aux_code[aux_chat] 
        -- 更新逻辑：没有匹配上就不出现再候选框里，提升性能
        local insert_second = {}  -- 没有辅助码的优先字
        local insert_last = {}

        -- 无论哪种模式，只要是三个 input 都走这个分支，这个分支结束后直接退出
        -- 如果是存在标点符号, wo,d, 变成 wo,d 那么就会把wo也进行辅助码匹配. 所以这里添加判断, 最后三位字母没有标点情况下.
        if #segmente_input == 3 then
            -- 标记使用了辅助码
            -- logger.info("set_fuzhuma 设置为true")
            aux_code_filter.set_fuzhuma = true
            -- 开始对所有候选项进行遍历
            local has_match_flag = false
            for cand in translation:iter() do
                
                -- 只对候选词字符为1个汉字的时候进行匹配
                if utf8.len(cand.text) == 1 then
                    -- logger.info("候选项为单个字: " .. cand.text)
                    -- 可能返回1,2,nil
                    if fuzhuma_match(cand.text, last_code) == 1 then
                        -- 向后扩展一位,将辅助码也包含进来
                        cand._end = cand._end + 1
                        cand.preedit = cand.preedit .. last_code
                        has_match_flag = true
                        yield(cand)
                    elseif fuzhuma_match(cand.text, last_code) == 2 then
                        -- wow进入这个分支, 我 握 两个字会排在前边, 但是我不想让辅助码蓝
                        table.insert(insert_second, cand)
                    else
                        table.insert(insert_last, cand)
                    end                  
                    
                end
            end
            
            -- 没有辅助码的字
            for _, cand in ipairs(insert_second) do
                yield(cand)
            end

            -- 把沒有匹配上的待選給添加上
            for _, cand in ipairs(insert_last) do            
                yield(cand)
            end

            -- 返回true, 说明处理过了,不用再输出候选词
            return true

        else
            -- #segmente_input > 3 并且为奇数的分支
            logger.info("env.fuzhu_mode: " .. env.fuzhu_mode )
            if env.fuzhu_mode == "single" then
                logger.info("进入只匹配前三个分支, 直接返回true")
                return true
            end

            -- 标记使用了辅助码, 标记这个就是在选词之后删除辅助码, 如果辅助码已经包含进去了,就不用标记了.
            logger.info("set_fuzhuma 设置为true")
            aux_code_filter.set_fuzhuma = true

            -- all模式, 对候选词中的所有字都进行匹配,只要匹配上了就输出,问题是从第一个开始,还是最后一个开始
            if env.fuzhu_mode == "all" then

                logger.info("当前输入是奇数个, 开始辅助码匹配候选词中所有字模式模式")
                -- 开始对所有候选项进行遍历
                local count = 0
                
                -- 创建按匹配位置分组的候选词列表
                local matched_by_position = {}  -- matched_by_position[1] 存储第一个字符匹配的候选词

                -- 最后一个辅助码替换完成, 只替换一个选项
                local last_replace_flag = false
                for cand in translation:iter() do
                    count = count + 1
                
                    -- 改成计算segment的覆盖范围有没有到最后一个字符
                    -- debug_utils.print_candidate_info(cand, count, logger)
                    -- current_end_position: 5 segment._end : 4 寻找这两个相差一个的,就是没有添加最后这个字母的候选项

                    logger.info("cand_text: " .. cand.text)
                    local left_position = current_end - cand._end
                    logger.info("left_position = current_end - cand._end: " .. left_position)
                    
                    if left_position == 0 then
                        -- 这些就是最后一个字母参与到组词的数据
                    elseif left_position == 1 then
                        -- 这些就是最后一个字母没有参与到组词的, 但是其他字母全部匹配的数据
                        -- 但是这个可能有很多个, 所以不能全部处理, 处理一个就可以了, 所以本分支无论如何只进入一次.
                        -- 当处理的时候有几种可能？有可能找到辅助码替换,有可能没有找到辅助码替换, 找到的,剩余再找到的就直接放到later里面.
                        -- 没找到的呢? 就将所有都放到later里面

                        -- 1. 对于第一个候选项直接放弃
                        -- 对于第2个候选项,直接进行替换最后一个字符
                        -- 1. 第一个候选词不对，这个候选词已经包含了最后一个字，并且进行了组合，我们要得是第二个候选项
                        -- 1. 首先获取当前候选词内容，切片提取最后一个字对应的字母
                        -- 2. 这两个字母,拼接上最后一个字母,合并成三个字母,到字典当中查找出对应的汉字
                        -- 2. 将这个汉字替换到候选词的最后一个字上面
                        -- 4. 如果没有找到这个汉字的话, 则保留最后一个汉字
                  
                        if not last_replace_flag then
                            -- 只替换第一个, 然后last_replace_flag改成true,这个分支后面的就不处理了
                            last_replace_flag = true

                            -- 提取最后三个字符 
                            local cand_text = cand.text
                            logger.info("cand_text: " .. cand_text)
                            local last_three_code = input:sub(-3)
                            logger.info("last_three_code: " .. last_three_code)
                            -- 从字典中查找对应的文字
                            local chinese_char_list = aux_code_filter.aux_code_hanzi[last_three_code]
                            
                            if chinese_char_list and #chinese_char_list > 0 then
                                logger.info("set_fuzhuma 设置为false")
                                -- 获取最后一个字符的位置
                                local last_char_index = utf8.offset(cand_text, -1)

                                -- 获取除了最后一个字符之外的部分
                                local text_without_last = cand_text:sub(1, last_char_index - 1)
                                
                                -- 对每个匹配的汉字都生成一个候选项
                                for i, chinese_char in ipairs(chinese_char_list) do
                                    logger.info("第" .. i .. "个匹配的汉字: " .. chinese_char)
                                    -- 拼接新的文本
                                    local new_text = text_without_last .. chinese_char
                                    -- 创建新的候选词
                                    local new_cand = Candidate(cand.type, cand.start, cand._end, new_text, cand.comment)
                                    -- 向后扩展一位,将辅助码也包含进来
                                    new_cand.preedit = cand.preedit
                
                                    yield(new_cand)
                                end

                            else
                                logger.info("最后三个字符未查找到匹配的汉字")
                                yield(cand)
                                -- table.insert(insert_last, cand)
                            end
                        
                        else 
                            table.insert(insert_last, cand)
                        end
                        

                    else
                        -- 剩余的长度不足以覆盖全部输入的候选项, 从匹配到字符的顺序进行依次排列
                        local cand_text = cand.text
                        local matched_position = 0
                        local count_char = 0
                        local match_flag = false
                        -- 遍历候选词中的每个字符
                        for pos, code in utf8.codes(cand_text) do
                            count_char = count_char + 1
                            local char = utf8.char(code)

                            -- 这个地方忘记改了, 有可能返回1,返回2,1就是匹配成功,2是匹配到常用字上面了
                            if fuzhuma_match(char, last_code) == 1 then
                                matched_position = count_char
                                break  -- 只要有一个字符匹配就可以了
                            -- elseif fuzhuma_match(char, last_code) == 2 then
                            --     -- 要不要匹配常用字呢？不用了把
                            end
                        end
                        
                        if matched_position == 0 then
                            -- 没有匹配
                            table.insert(insert_last, cand)
                        else
                            -- 有匹配，按位置存储
                            if not matched_by_position[matched_position] then
                                matched_by_position[matched_position] = {}
                            end
                            table.insert(matched_by_position[matched_position], cand)
                        end
                    end
                end

                -- 按照匹配位置从前到后输出候选词
                -- 获取所有匹配位置并排序
                local positions = {}
                for pos, _ in pairs(matched_by_position) do
                    table.insert(positions, pos)
                end
                table.sort(positions)
                logger.info("匹配候选词并排序成功,现在开始输出候选词")
                -- 按位置顺序输出（第1个字符匹配的、第2个字符匹配的、第3个字符匹配的...）
                for _, pos in ipairs(positions) do
                    logger.info("输出第" .. pos .. "个字符匹配的候选词")
                    for _, cand in ipairs(matched_by_position[pos]) do
                        logger.info("匹配成功的候选词" .. cand.text .. " 匹配位置: " .. tostring(pos))
                        yield(cand)
                    end
                end

                -- 把沒有匹配上的候选项添加上
                for _, cand in ipairs(insert_last) do
                    yield(cand)
                end

                return true
            elseif env.fuzhu_mode == "before" then
                logger.info("当前输入是奇数个, 开始辅助码匹配第一个字模式模式")
                -- 开始对所有候选项进行遍历
                local count = 0
                for cand in translation:iter() do
                    count = count + 1
                    
                    -- 提取第一个字符
                    local the_char = ""
                    local cand_text = cand.text
                    the_char = utf8.char(utf8.codepoint(cand_text, 1))

                    if count == 1 then
                        -- 第一个候选项直接输出，不进行辅助码匹配
                        yield(cand)
                    elseif fuzhuma_match(the_char, last_code) then
                        cand._end = cand._end + 1
                        cand.preedit = cand.preedit .. last_code
                        yield(cand)
                    else
                        table.insert(insert_last, cand)
                    end
                        
                end
                -- 把沒有匹配上的待選給添加上
                for _, cand in ipairs(insert_last) do
                    yield(cand)
                end

                return true
            elseif env.fuzhu_mode == "after" then
                logger.info("当前输入是奇数个, 开始辅助码匹配最后一个字模式模式")
                -- 开始对所有候选项进行遍历
                local count = 0
                for cand in translation:iter() do
                    count = count + 1
                    
                    -- 提取第一个字符
                    local the_char = ""
                    local cand_text = cand.text

                    -- 提取最后一个字符
                    -- logger.info("cand_text: " .. cand_text)
                    local index = utf8.offset(cand_text, -1)
                    the_char = cand_text:sub(index)

                    if count == 1 then
                        -- 第一个候选项直接输出，不进行辅助码匹配
                        yield(cand)
                    elseif fuzhuma_match(the_char, last_code) then
                        yield(cand)
                    else
                        table.insert(insert_last, cand)
                    end
                        
                end
                -- 把沒有匹配上的待選給添加上
                for _, cand in ipairs(insert_last) do
                    yield(cand)
                end

                return true
            end
            
        end

    end)

    if not success then
        logger.error("aux_code_filter.func 执行过程中发生错误: " .. tostring(error_msg))
        -- 发生错误时回退到显示所有候选项，确保输入法正常工作
        for cand in translation:iter() do
            -- 过滤掉长度匹配到最后一个辅助码的
            local left_position = current_end - cand._end
            if left_position ~= 0 then
                yield(cand)
            else
                
            end
        end
    elseif error_msg == false then
        -- 没有进入到辅助码合适的字符, 直接输出原来的候选词
        for cand in translation:iter() do

            -- 过滤掉长度匹配到最后一个辅助码的
            local left_position = current_end - cand._end
            if left_position ~= 0 then
                yield(cand)
            else
                
            end
            
        end
    end

end

function aux_code_filter.fini(env)
    env.notifier:disconnect()
end

return aux_code_filter

