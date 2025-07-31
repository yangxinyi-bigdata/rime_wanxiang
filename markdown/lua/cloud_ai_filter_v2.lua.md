在这里添加代码即可跳过. 如果是多段segment的话,前边的一般不需要,就在这里跳过.
```
    if cand_type == "punct" or cand_type:sub(-7) == "ai_chat" then
        logger.info("cand_type: punct or ai_chat cand_text: " .. cand_text)
        -- 输出原始候选词
        yield(first_original_cand)

        for cand in translation:iter() do
            logger.info(string.format(
                "punct剩余选词信息: text=%s, preedit=%s, start=%s, end=%s, type=%s, comment=%s",
                tostring(cand.text), tostring(cand.preedit), tostring(cand.start), tostring(cand._end),
                tostring(cand.type), tostring(cand.comment)))
            yield(cand)
        end

        return        
    else
        logger.info("cand_type:  " .. cand_type)
    end
    
```