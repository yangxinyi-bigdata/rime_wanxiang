-- lua/baidu_filter.lua 修改成filter版本,通过百度云接口获取云输入法拼音词组,并添加到候选词中第一位中来
-- 百度云输入获取filter版本
local json = require("json")
local http = require("simplehttp")
http.TIMEOUT = 0.5
-- 引入日志工具模块
local logger_module = require("logger")

-- 创建当前模块的日志记录器
local logger = logger_module.create("baidu_filter", {
    enabled = false  -- 可以通过这里控制日志开关
})
-- local http = require("simplehttp")
-- http.TIMEOUT = 0.5

local function make_url(input, bg, ed)
   return 'https://olime.baidu.com/py?input=' .. input ..
      '&inputtype=py&bg='.. bg .. '&ed='.. ed ..
      '&result=hanzi&resultcoding=utf-8&ch_en=0&clientinfo=web&version=1'
end



-- 封装 curl 发送网络请求 
local function http_get(url)
   local handle = io.popen("curl -m 0.5 -s '" .. url .. "'")
   local result = handle:read("*a")
   handle:close()
   return result
end

local translator = {}

local ziranma_mapping_config = {}  -- 自然码映射表

function translator.init(env)
   -- 初始化时清空日志文件
   logger:clear()
   logger:info("云输入处理器初始化完成")

   local config = env.engine.schema.config
   -- 加载自然码映射表
   ziranma_mapping_config = config:get_map("speller/ziranma_to_quanpin")

   -- if ziranma_mapping_config then
   --    logger:info("开始打印自然码映射表...")
   --    local count = 0
   --    local success, error_msg = pcall(function()
   --       -- 创建一个新的表来存储映射
   --       local temp_mapping = {}
         
   --       -- 获取所有的键
   --       local keys = ziranma_mapping_config:keys()
   --       if keys then
   --          for _, key in ipairs(keys) do
   --             -- 使用 get_value 方法获取对应的值
   --             local value = ziranma_mapping_config:get_value(key)
   --             if value then
   --                local quanpin = value:get_string()
   --                temp_mapping[key] = quanpin
   --                logger:info(string.format("自然码映射: %s -> %s", key, quanpin))
   --                count = count + 1
   --             end
   --          end
   --       end
         
   --       -- 成功加载后，替换全局映射表
   --       ziranma_mapping = temp_mapping
   --    end)
      
   --    if success then
   --       logger:info(string.format("自然码映射表加载完成，共 %d 项", count))
   --    else
   --       logger:error(string.format("加载自然码映射表时发生错误: %s", error_msg))
   --    end
   -- else
   --    logger:error("未找到自然码映射配置")
   -- end
end

local function double_pinyin_to_full_pinyin(input)
   local success, result = pcall(function()
      -- 这里可以添加具体的双拼转全拼的实现逻辑
      local result_table = {}
      for i = 1, #input, 2 do
         local pair = input:sub(i, i + 1)
         if i + 1 > #input then
            pair = input:sub(i)
         end
         -- 使用 get_value 方法获取配置值
         local value = ziranma_mapping_config:get_value(pair)
         if value then
            table.insert(result_table, value:get_string())
         else
            -- 如果没有找到映射，使用原始值
            table.insert(result_table, pair)
         end
      end
      return table.concat(result_table, "")
   end)
   
   if success then
      return result
   else
      logger:error("双拼转全拼失败:  " .. tostring(result))
      return input  -- 出错时返回原始输入
   end
end

function translator.func(translation, env)
    local engine = env.engine
    local context = engine.context
    local input = context.input
    
   -- 判断是否存在标点符号或者长度超过设定值,如果是在seg后面添加prompt说明
   local segment = ""

   -- 在segment后面添加prompt
   local composition = context.composition
   if(not composition:empty()) then
      -- 获得队尾的 Segment 对象
      segment = composition:back()
      if segment then
         -- logger:info("当前cloud_translate_prompt状态: ".. tostring(context:get_option("cloud_translate_prompt")))
         local prompt_text = "▶ 回车AI转换"
         if context:get_property("cloud_translate_flag") == "1" then
            logger:info("云输入法转换提示已启用")
            if segment.prompt ~= prompt_text then
               -- 使用更醒目的格式，添加视觉分隔符
               -- segment.prompt = "[     🤖 回车AI转换]"
               -- 备选格式（可以根据需要切换）:
               segment.prompt = prompt_text
               -- segment.prompt = "     🤖 回车AI转换"
               -- segment.prompt = "    [AI] 回车转换"
               -- segment.prompt = " → AI转换"
               -- segment.prompt = " ⚡ AI转换"
               -- logger:info("通过segmentation成功设置prompt")
            end
               
         else
            if segment.prompt == prompt_text then
               segment.prompt = ""
            end
         end
      end

   end

   if not context:get_option("cloud_translate") then
      -- 查看有没有云翻译的标识, 没有的话直接退出
      for cand in translation:iter() do
         yield(cand)  -- 输出原有候选词
      end
      return
   else
   context:set_option("cloud_translate", false)  -- 重置选项，避免重复触发
   end

   -- 将双拼转换成全拼
   local full_pinyin = double_pinyin_to_full_pinyin(input)
   logger:info("转换后的全拼: " .. full_pinyin)
   -- 如果input当中存在标点符号,则对input进行切分处理,以标点符号为边界
   local url = make_url(full_pinyin, 0, 5)
   
   logger:info("构建的百度云输入法API请求URL: " .. url)
   -- 发送HTTP请求获取云端候选词
   -- local reply = http_get(url) -- curl的方法
   local reply = http.request(url)
   -- 安全解析JSON响应数据
   local parse_success, baidu_response = pcall(json.decode, reply)
   -- 检查响应状态和结果是否有效
   if baidu_response.status == "T" and baidu_response.result and baidu_response.result[1] then
         -- 先保存第一个原始候选词
      local first_original_cand = nil
      local original_preedit = ""
      
      -- 获取第一个原始候选词
      for cand in translation:iter() do
         first_original_cand = cand
         original_preedit = cand.preedit
         
         break
      end
      
      -- 遍历百度返回的候选词列表
      for candidate_index, candidate_data in ipairs(baidu_response.result[1]) do
         -- 创建候选词对象
         -- candidate_data[1]: 汉字文本
         -- candidate_data[2]: 拼音长度
         -- 当前有候选词,还有env,context上下文这里是想要提交一个候选词, 候选词对应录入拼音片段的哪一部分,如何获取呢? 
         -- 应该对应的是整个片段吧? 也就是^ 这个符号前边的所有片段,也就是segment
         logger:info("处理候选词: " .. candidate_data[1] .. ", 拼音长度: " .. candidate_data[2] .. ", 拼音: " .. candidate_data[3].pinyin)
         local candidate = Candidate("sentence", segment.start, segment._end, candidate_data[1], "   [百度云]")
         
         -- 检查拼音是否匹配输入的前缀
         logger:info("检查拼音前缀匹配: " .. candidate_data[3].pinyin)

         -- "小酸瓜和小黄瓜的故事" "xiao'suan'gua'he'xiao'huang'gua'de'gu'shi" 32个字母,但原来input中的字母数量并不是
         -- 这行代码是要干什么?  从总的输入字母当中切片出候选词对应的部分? 但在双拼和全拼的关系中这个代码不对了
         -- 这部分应该是为了生成对应的preedit, 当我按下回车的时候,获得了返回结果,那么我是希望一个什么样的preedit呢? 
         -- 是返回的双拼,还是现在的全拼内容? 如果是双拼,双拼在哪里,应该在原来的input当中, input当中还需要每两个字符添加一个空格,才能和原来的效果一致.
         -- 如果是全拼,就直接填充上去就可以. 但如果不是把整个input发送出去进行转换呢? 
 
         -- 使用原始候选词的 preedit
         candidate.preedit = original_preedit
         yield(candidate)  -- 输出云候选词
      end

      -- 输出第一个原始候选词
      if first_original_cand then
         yield(first_original_cand)
      end

      for cand in translation:iter() do
         yield(cand)  -- 输出原有候选词
      end

   else -- 百度云没有相应正确结果,则直接输出原有候选词
      for cand in translation:iter() do
         yield(cand)  -- 输出原有候选词
      end
   end
end


function translator.fini(env)
    logger:info("云输入处理器结束运行")
end


return translator
