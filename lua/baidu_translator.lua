-- 百度云输入获取
local json = require("json")
local http = require("simplehttp")
http.TIMEOUT = 0.5

local function make_url(input, bg, ed)
   return 'https://olime.baidu.com/py?input=' .. input ..
      '&inputtype=py&bg='.. bg .. '&ed='.. ed ..
      '&result=hanzi&resultcoding=utf-8&ch_en=0&clientinfo=web&version=1'
end

local function translator(input, seg, env)
    local engine = env.engine
    local context = engine.context
    if not context:get_option("cloud_translate") then
      -- 查看有没有云翻译的标识, 没有的话直接退出
      return
    else 
      context:set_option("cloud_translate", false)  -- 重置选项，避免重复触发
    end

   -- 构建百度云输入法API请求URL
   local url = make_url(input, 0, 5)
   -- 发送HTTP请求获取云端候选词
   local reply = http.request(url)
   
   -- 安全解析JSON响应数据
   local parse_success, baidu_response = pcall(json.decode, reply)
   -- 检查响应状态和结果是否有效
   if baidu_response.status == "T" and baidu_response.result and baidu_response.result[1] then
      -- 遍历百度返回的候选词列表
      for candidate_index, candidate_data in ipairs(baidu_response.result[1]) do
         -- 创建候选词对象
         -- candidate_data[1]: 汉字文本
         -- candidate_data[2]: 拼音长度
         -- seg.start: 输入起始位置
         local candidate = Candidate("simple", seg.start, seg.start + candidate_data[2], candidate_data[1], "   [百度云]")
         candidate.quality = 2  -- 设置候选词优先级
         
         -- 检查拼音是否匹配输入的前缀
         local pinyin_without_apostrophe = string.gsub(candidate_data[3].pinyin, "'", "")
         local input_prefix = string.sub(input, 1, candidate_data[2])
         if pinyin_without_apostrophe == input_prefix then
            -- 设置预编辑文本，将单引号替换为空格便于显示
            candidate.preedit = string.gsub(candidate_data[3].pinyin, "'", " ")
         end
         
         -- 输出候选词
         yield(candidate)
      end
   end   
end

return translator
