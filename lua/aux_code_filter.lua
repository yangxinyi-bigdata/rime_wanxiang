-- 对双拼进行形码的输入
-- 参考: https://github.com/HowcanoeWang/rime-lua-aux-code
-- 重新梳理一下这个代码应该能够实现的功能, 就是当输入码大于三个的时候，截取最后的三个输入码，
-- 用前两个输入码正常匹配双拼词库，用最后一个输入码去匹配辅助码。

local logger_module = require("logger")
local debug_utils = require("debug_utils")

-- 创建日志记录器
local logger = logger_module.create("aux_code_filter", {
    enabled = true
})

local aux_code_filter = {}


-- 初始化函数,初始化中应该做什么? 将辅助码读取进来
function aux_code_filter.init(env)
    
    logger:clear()
    logger:info("aux_code_filter init")
    logger:info("=" .. string.rep("=", 60))
    
    local engine = env.engine
    local config = engine.schema.config

    
    env.single_fuzhu = config:get_bool("aux_code/single_fuzhu") or false
    -- fuzhu_mode : "before"   # 辅助模式有三种: 1.single只当input中有三个字符的时候进行匹配 2.before,最后一个辅助码和最前边两个 input 字母进行匹配 3. after,最后一个辅助码和最后两个 input 字母进行匹配
    env.fuzhu_mode = config:get_string("aux_code/fuzhu_mode") or ""
    env.txtpath = config:get_string("aux_code/txtpath") or ""
    logger:info("txtpath: " .. env.txtpath)
    aux_code_filter.aux_code = aux_code_filter.readAuxTxt(env.txtpath)

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
            logger:info("select_notifier函数: 选词上屏,输入文本: " .. input)

            -- 删除最后一个辅助码
            context:pop_input(1)
            aux_code_filter.set_fuzhuma = false -- 重置标志位

            input = context.input
            logger:info("删除辅助码后input: " .. input)

            -- 检查删除辅助码后的情况
            local segmentation = context.composition:toSegmentation()
            local confirmed_position = segmentation:get_confirmed_position()
            local unconfirmed_length = #input - confirmed_position
            
            logger:info("confirmed_position=" .. confirmed_position .. ", unconfirmed_length=" .. unconfirmed_length)
            
            -- 当没有未确认的字符时，直接上屏
            if unconfirmed_length == 0 then
                logger:info("没有剩余未确认字符,直接上屏")
                context:commit()
            end

        end)
        
        if not success then
            logger:error("选词上屏处理过程中发生错误: " .. tostring(error_msg))
            -- 重置标志位确保不影响后续操作
            aux_code_filter.set_fuzhuma = false
        end
    end)


    ----------------------------
    -- 这个是每一次用户进行选词到时候执行的回调函数
    -- 也就是每一次选词, 比如说原来有10个字符,选词后前面四个选完了,剩下6个要继续选择
    -- 原来这段功能是把辅助码去除掉,如果还有要匹配的字母,就将剩余的内容重新拼接上辅助码,然后上屏
    -- 现在我的功能和原来完全不一样了,在我的每一次选词之后, 本来就应该对剩余的所有进行匹配,所以每一次选词之后,不需要做什么特殊的事?
    ----------------------------
    
end

----------------
-- 阅读辅码文件, 功能是将字典文件读取到缓存当中aux_code_filter.cache
-- 貌似不需要更改 --
----------------
function aux_code_filter.readAuxTxt(txtpath)
    if aux_code_filter.cache then
        return aux_code_filter.cache
    end

    local defaultFile = 'ziranma_20250612_phrases_unique.txt'
    local userPath = rime_api.get_user_data_dir() .. "/lua/aux_code/"
    local fileAbsolutePath = userPath .. txtpath .. ".txt"

    local file = io.open(fileAbsolutePath, "r") or io.open(userPath .. defaultFile, "r")
    if not file then
        logger:error("不能打开辅助码文件")
        return {}
    end

    local auxCodes = {}
    for line in file:lines() do
        line = line:match("[^\r\n]+") -- 去掉換行符，不然 value 是帶著 \n 的
        local key, value = line:match("([^=]+)=(.+)") -- 分割 = 左右的變數
        if key and value then
            auxCodes[key] = auxCodes[key] or {}
            table.insert(auxCodes[key], value)
        end
    end
    file:close()
    -- 確認 code 能打印出來
    -- for key, value in pairs(aux_code_filter.aux_code) do
    --     log.info(key, table.concat(value, ','))
    -- end

    aux_code_filter.cache = auxCodes
    logger:info("aux_code_filter.cache读取成功")
    return aux_code_filter.cache
end

-- first_char第一个汉字 例如 时, 最后一个辅助码 例如 o
-- 提取出当前候选词的中文, 和输入的匹配码, 返回是否匹配成功? 
local function fuzhuma_match(match_char, match_code)
    -- 进行辅助码匹配
    -- logger:info("匹配字符: " .. match_char)
    local fuzhuma = aux_code_filter.aux_code[match_char] -- 找到字符的辅助码
    if fuzhuma then -- 辅助码存在, 这个字是存在辅助码的
        local success_flag = false
        for _, code in ipairs(fuzhuma) do  -- 对这个字符的所有辅助码进行遍历,为这个一个字符可能有多个不同的辅助码
            if code == match_code then  -- 如果辅助码和输入的最后一个字母相同,则匹配成功
                logger:info("匹配成功: match_char: " .. match_char .. "  match_code: " ..match_code)
                return true
            end
        end
    end

    return false
end

------------------
-- filter 主函數 --
------------------
function aux_code_filter.func(translation, env)
    logger:info("aux_code_filter func")
    local context = env.engine.context
    local input = context.input
    local segmentation = context.composition:toSegmentation()
    local current_start = segmentation:get_current_start_position()
    local current_end = segmentation:get_current_end_position()
    local segmente_input = input:sub(current_start + 1, current_end)

    logger:info("")
    logger:info("=== 开始分析lua/aux_code_filter.lua ===")
    logger:info("segmente_input: " .. segmente_input)
    debug_utils.print_segmentation_info(segmentation, logger)

    -- 如果是在反引号模式中, 也不进入, 如果input长度小于3 或者是偶数,也不进入
    -- 如果是剩余的segmente_input小于3,还进不进入呢？按说也应该不进入, 只是我需要在选词之后, 保持set_fuzhuma为真
    if not env.single_fuzhu or #segmente_input <3 or #segmente_input % 2 == 0 or context:get_property("backtick_prompt") == 1 then
        -- 使用更精确的判断：检查当前段是否是选词后的剩余
        local confirmed_position = segmentation:get_confirmed_position()
        local current_start = segmentation:get_current_start_position()
        
        -- 只有当当前段紧跟在确认位置之后，且confirmed_position > 0时，才认为是选词后的剩余
        local is_remainder_after_selection = (confirmed_position > 0 and current_start == confirmed_position)
        
        if is_remainder_after_selection then
            logger:info("176选词后紧跟的剩余短字符，confirmed_position=" .. confirmed_position .. ", current_start=" .. current_start .. "，保持 set_fuzhuma 状态: " .. tostring(aux_code_filter.set_fuzhuma))
        else
            -- 直接输入的短字符或长句选词后新输入的字符，重置标志位
            if aux_code_filter.set_fuzhuma then
                logger:info("180直接输入或新输入的短字符，confirmed_position=" .. confirmed_position .. ", current_start=" .. current_start .. "，set_fuzhuma设置为false: "  .. tostring(aux_code_filter.set_fuzhuma))
                aux_code_filter.set_fuzhuma = false
            end
        end
        
        for cand in translation:iter() do
            yield(cand)
        end
        return false
    end

    local success, error_msg = pcall(function()

        logger:info("开始辅助码匹配,输入文本: " .. segmente_input)
        -- 最后一个辅助码
        local last_code = segmente_input:sub(-1)
        logger:info("last_char: " ..last_code)
        -- local auxCodes = aux_code_filter.aux_code[aux_chat] 
        -- 更新逻辑：没有匹配上就不出现再候选框里，提升性能
        local insertLater = {}

        -- 无论哪种模式，只要是三个 input 都走这个分支，这个分支结束后直接退出
        if #segmente_input == 3 then
            -- 开始对所有候选项进行遍历
            local has_match_flag = false
            for cand in translation:iter() do
                
                -- 只对候选词字符为1个汉字的时候进行匹配
                if utf8.len(cand.text) == 1 then
                    -- logger:info("候选项为单个字: " .. cand.text)
                    if fuzhuma_match(cand.text, last_code) then
                        cand._end = cand._end + 1
                        cand.preedit = cand.preedit .. last_code
                        has_match_flag = true
                        yield(cand)
                    else
                        table.insert(insertLater, cand)
                    end
                    
                end
            end
            -- 把沒有匹配上的待選給添加上
            for _, cand in ipairs(insertLater) do
                if has_match_flag then
                    cand._end = cand._end + 1
                    cand.preedit = cand.preedit .. last_code
                else
                    -- 标记使用了辅助码
                    if not aux_code_filter.set_fuzhuma then
                        logger:info("set_fuzhuma 设置为true")
                        aux_code_filter.set_fuzhuma = true
                    end
                end
                -- end
                -- cand._end = cand._end + 1
                -- cand.preedit = cand.preedit .. last_code
                yield(cand)
            end

            return true

        else
            -- #segmente_input > 3 并且为奇数的分支
            -- fuzhu_mode : "before"   # 辅助模式有三种: 1.single只当input中有三个字符的时候进行匹配 2.before,最后一个辅助码和最前边两个 input 字母进行匹配 3. after,最后一个辅助码和最后两个 input 字母进行匹配
            logger:info("env.fuzhu_mode: " .. env.fuzhu_mode )
            if env.fuzhu_mode == "single" then
                logger:info("进入只匹配前三个分支, 直接返回true")
                return true
            end

            -- 标记使用了辅助码
            if not aux_code_filter.set_fuzhuma then
                aux_code_filter.set_fuzhuma = true
            end

            if env.fuzhu_mode == "before" then
                logger:info("当前输入是奇数个, 开始辅助码匹配第一个字模式模式")
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
                        table.insert(insertLater, cand)
                    end
                        
                end
                -- 把沒有匹配上的待選給添加上
                for _, cand in ipairs(insertLater) do
                    yield(cand)
                end

                return true
            elseif env.fuzhu_mode == "after" then
                logger:info("当前输入是奇数个, 开始辅助码匹配最后一个字模式模式")
                -- 开始对所有候选项进行遍历
                local count = 0
                for cand in translation:iter() do
                    count = count + 1
                    
                    -- 提取第一个字符
                    local the_char = ""
                    local cand_text = cand.text

                    -- 提取最后一个字符
                    -- logger:info("cand_text: " .. cand_text)
                    local index = utf8.offset(cand_text, -1)
                    the_char = cand_text:sub(index)

                    if count == 1 then
                        -- 第一个候选项直接输出，不进行辅助码匹配
                        yield(cand)
                    elseif fuzhuma_match(the_char, last_code) then
                        yield(cand)
                    else
                        table.insert(insertLater, cand)
                    end
                        
                end
                -- 把沒有匹配上的待選給添加上
                for _, cand in ipairs(insertLater) do
                    yield(cand)
                end

                return true
            end
            
        end

    end)

    if not success then
        logger:error("aux_code_filter.func 执行过程中发生错误: " .. tostring(error_msg))
        -- 发生错误时回退到显示所有候选项，确保输入法正常工作
        for cand in translation:iter() do
            yield(cand)
        end
    elseif error_msg == false then
        -- 没有进入到辅助码合适的字符, 直接输出原来的候选词
        for cand in translation:iter() do
            yield(cand)
        end
    end

end

function aux_code_filter.fini(env)
    env.notifier:disconnect()
end

return aux_code_filter

