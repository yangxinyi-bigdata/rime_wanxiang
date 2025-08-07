-- lua/baidu_translator.lua 修改成filter版本,通过百度云接口获取云输入法拼音词组,并添加到候选词中第一位中来
-- 百度云输入获取translator版本,开发到一半发现没什么用，放弃继续开发


local json = require("json")
local http = require("simplehttp")
http.TIMEOUT = 0.5
-- 引入日志工具模块
local logger_module = require("logger")
-- 引入文本切分模块
local text_splitter = require("text_splitter")
local debug_utils = require("debug_utils")

-- 创建当前模块的日志记录器
local logger = logger_module.create("baidu_translator", {
    enabled = true  -- 启用日志以便测试
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
local rawenglish_delimiter_before = ""  -- 反引号分隔符
local rawenglish_delimiter_after = ""
local replace_punct_enabled = false

function translator.init(env)
   -- 初始化时清空日志文件
   logger.clear()
   logger.info("云输入处理器初始化完成")

   local config = env.engine.schema.config
   -- 加载自然码映射表
   ziranma_mapping_config = config:get_map("speller/ziranma_to_quanpin")
   
   -- 读取反引号分隔符配置
    rawenglish_delimiter_before = config:get_string("translator/rawenglish_delimiter_before") or ""
    rawenglish_delimiter_after = config:get_string("translator/rawenglish_delimiter_after") or ""

    replace_punct_enabled = config:get_string("translator/replace_punct_enabled") or false
    -- logger.info("反引号分隔符设置: '" .. rawenglish_delimiter_before .. "' '" .. rawenglish_delimiter_after .. "'")

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
      logger.error("双拼转全拼失败:  " .. tostring(result))
      return input  -- 出错时返回原始输入
   end
end

-- 获取云输入结果的函数（同步调用）
local function get_cloud_result(pinyin_text)
   if pinyin_text == "" then return "" end
   
   local full_pinyin = double_pinyin_to_full_pinyin(pinyin_text)
   logger.info("片段 '" .. pinyin_text .. "' 转换后的全拼: " .. full_pinyin)
   
   local url = make_url(full_pinyin, 0, 5)
   local reply = http.request(url)
   local parse_success, baidu_response = pcall(json.decode, reply)
   
   if parse_success and baidu_response.status == "T" and baidu_response.result and baidu_response.result[1] and baidu_response.result[1][1] then
      local result = baidu_response.result[1][1][1]
      logger.info("片段 '" .. pinyin_text .. "' 云输入结果: " .. result)
      return result
   else
      logger.info("片段 '" .. pinyin_text .. "' 云输入无结果，保持原样")
      return pinyin_text
   end
end

function translator.func(input, seg, env)
   local engine = env.engine
   local context = engine.context

   logger.info("开始执行lua/baidu_translator.lua")

   -- 判断是否存在标点符号或者长度超过设定值,如果是在seg后面添加prompt说明
   local segment = ""

   -- 在segment后面添加prompt
   local composition = context.composition
   if(not composition:empty()) then
      -- 获得队尾的 Segment 对象
      segment = composition:back()
      if segment then
         -- logger.info("当前cloud_convert_prompt状态: ".. tostring(context:get_option("cloud_convert_prompt")))
         
         -- 定义两种提示文本
         local cloud_prompt_text = "     ▶ 回车AI转换"
         local rawenglish_prompt_text = "     ▶ 反引号模式"
         
         -- 获取两个状态
         local rawenglish_prompt = context:get_property("rawenglish_prompt")
         local cloud_convert_flag = context:get_property("cloud_convert_flag")
         
         -- 判断显示哪个提示（rawenglish_prompt 优先级更高）
         if rawenglish_prompt == "1" then
            -- rawenglish_prompt 优先级最高
            if segment.prompt ~= rawenglish_prompt_text then
               segment.prompt = rawenglish_prompt_text
               logger.info("设置反引号提示: " .. rawenglish_prompt_text)
            end
         elseif cloud_convert_flag == "1" then
            -- 只有在 rawenglish_prompt 为 0 时才显示 cloud_convert_flag 的提示
            if segment.prompt ~= cloud_prompt_text then
               segment.prompt = cloud_prompt_text
               logger.info("设置云输入提示: " .. cloud_prompt_text)
            end

         end
      end

   end

   if not context:get_option("cloud_convert") then
      -- 查看有没有云翻译的标识, 没有的话直接退出
      return
   else
   context:set_option("cloud_convert", false)  -- 重置选项，避免重复触发
   end


   -- 检查输入是否包含标点符号或反引号
   local has_punctuation = input:match("[,.!?;:()%[%]<>/_=+*&^%%$#@~|%-`'\"']") ~= nil
   
   if not has_punctuation then
      -- 纯英文字母输入，使用原来的方式直接调用百度云接口
      logger.info("检测到纯英文字母输入，使用传统百度云处理方式")
      
      local full_pinyin = double_pinyin_to_full_pinyin(input)
      logger.info("输入 '" .. input .. "' 转换后的全拼: " .. full_pinyin)
      
      local url = make_url(full_pinyin, 0, 5)
      local reply = http.request(url)
      local parse_success, baidu_response = pcall(json.decode, reply)


      -- local new_spans = seg:spans()
      -- logger.info("Segment spans count: " .. new_spans.count)
      -- logger.info("spans Start: " .. new_spans._start .. ", spans End: " .. new_spans._end)
      
      -- -- 获取所有分割点
      -- local vertices = new_spans.vertices
      -- for i, vertex in ipairs(vertices) do
      --    logger.info("spans Vertex " .. i .. ": " .. vertex)
      -- end


      if parse_success and baidu_response.status == "T" and baidu_response.result and baidu_response.result[1] then
         
         -- 添加百度云候选词
         for candidate_index, candidate_data in ipairs(baidu_response.result[1]) do
            logger.info("添加百度云候选词: " .. candidate_data[1])

            -- local cloud_candidate = Candidate("", segment.start, segment._end, candidate_data[1], "   [云输入]")
            local cloud_candidate = Candidate("phrase", seg.start, seg._end, candidate_data[1], "   [云输入]")
            
            -- input 每两个字母中间添加一个空格
            local formatted_input = ""
            for i = 1, #input, 2 do
                -- 获取当前的两个字符
                local pair = input:sub(i, i + 1)
                formatted_input = formatted_input .. pair
                -- 如果不是最后一对字符，添加空格
                if i + 2 <= #input then
                    formatted_input = formatted_input .. " "
                end
            end
            
            cloud_candidate.preedit = formatted_input
            logger.info("设置preedit为格式化后的input: " .. formatted_input)
            
            -- cloud_candidate.quality = 0.01
            
            yield(cloud_candidate)
            return 
         end

   
      else
         logger.info("百度云接口无结果，输出原始候选词")
         return
      end
   else
      -- 包含标点符号或反引号，使用智能切分处理
      logger.info("检测到标点符号或反引号，使用智能切分处理方式")

      -- 切分并处理输入（添加错误捕获）
      local segments = {}
      local final_result = ""
      
      local success, result = pcall(function()
         -- 是否替换中文标点符号
         return text_splitter.split_and_convert_input_with_log_and_delimiter(input, logger, rawenglish_delimiter_before, rawenglish_delimiter_after, replace_punct_enabled)
      end)
      
      if success and result then
         segments = result
         logger.info("成功运行切分函数，获得 " .. #segments .. " 个片段")
         for i, seg in ipairs(segments) do
            logger.info(string.format("片段 %d: type=%s, content='%s'", i, seg.type, seg.content))
         end
      else
         logger.error("切分函数运行失败: " .. tostring(result))
         logger.info("降级到原始处理方式")
         -- 降级处理：将整个输入当作纯文本处理
         segments = {{type = "abc", content = input}}
      end
      
      -- 处理每个片段（添加错误捕获）
      for i, segment in ipairs(segments) do
         local segment_success, segment_result = pcall(function()
            if segment.type == "abc" then
               -- 文本片段：进行双拼转换和云输入
               logger.info(string.format("处理文本片段 %d: '%s'", i, segment.content))
               return get_cloud_result(segment.content)
            elseif segment.type == "punct" then
               -- 标点符号：直接添加
               logger.info(string.format("处理标点片段 %d: '%s'", i, segment.content))
               return segment.content
            elseif segment.type == "rawenglish_combo" then
               -- 反引号内容：不处理，直接添加
               logger.info(string.format("处理反引号片段 %d: '%s'", i, segment.content))
               return segment.content
            else
               logger.info(string.format("未知片段类型 %d: type=%s, content='%s'", i, segment.type, segment.content))
               return segment.content
            end
         end)
         
         if segment_success and segment_result then
            final_result = final_result .. segment_result
            logger.info(string.format("片段 %d 处理成功，结果: '%s'", i, segment_result))
         else
            logger.error(string.format("片段 %d 处理失败: %s", i, tostring(segment_result)))
            -- 失败时使用原始内容
            final_result = final_result .. (segment.content or "")
         end
      end
      
      logger.info("智能切分最终结果: " .. final_result)
      
      -- 检查是否有智能合成结果
      if final_result ~= "" then
         -- 先保存第一个原始候选词
         local first_original_cand = translation:iter()()
         local original_preedit = first_original_cand and first_original_cand.preedit or ""
         
         -- 创建智能合成候选词
         logger.info("创建智能合成候选词: " .. final_result)
         local candidate = Candidate("sentence", segment.start, segment._end, final_result, "   [云输入]")
         candidate.preedit = original_preedit
         yield(candidate)
         
         -- 输出原始候选词
         if first_original_cand then
            yield(first_original_cand)
         end
         
         for cand in translation:iter() do
            yield(cand)
         end
      else
         -- 没有智能合成结果，输出原有候选词
         logger.info("没有智能合成结果，输出原始候选词")
         for cand in translation:iter() do
            yield(cand)
         end
      end
   end
end


function translator.fini(env)
    logger.info("云输入处理器结束运行")
end


return translator
