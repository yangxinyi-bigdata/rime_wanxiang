-- 百度云输入获取,curl版本
local json = require("json")
-- 引入日志工具模块
local logger_module = require("logger")

-- 创建当前模块的日志记录器
local logger = logger_module.create("baidu_translator_curl", {
    enabled = true  -- 可以通过这里控制日志开关
})
-- local http = require("simplehttp")
-- http.TIMEOUT = 0.5

local function make_url(input, bg, ed)
   return 'https://olime.baidu.com/py?input=' .. input ..
      '&inputtype=py&bg='.. bg .. '&ed='.. ed ..
      '&result=hanzi&resultcoding=utf-8&ch_en=0&clientinfo=web&version=1'
end


-- local function double_pinyin_to_full_pinyin(input)
--    local mspy2qp_table = { ["oa"] = "a", ["ol"] = "ai", ["oj"] = "an", ["oh"] = "ang", ["ok"] = "ao", ["ba"] = "ba", ["bl"] = "bai", ["bj"] = "ban", ["bh"] = "bang", ["bk"] = "bao", ["bz"] = "bei", ["bf"] = "ben", ["bg"] = "beng", ["bi"] = "bi", ["bm"] = "bian", ["bd"] = "biang", ["bc"] = "biao", ["bx"] = "bie", ["bn"] = "bin", ["b;"] = "bing", ["bo"] = "bo", ["bu"] = "bu", ["ca"] = "ca", ["cl"] = "cai", ["cj"] = "can", ["ch"] = "cang", ["ck"] = "cao", ["ce"] = "ce", ["cz"] = "cei", ["cf"] = "cen", ["cg"] = "ceng", ["ia"] = "cha", ["il"] = "chai", ["ij"] = "chan", ["ih"] = "chang", ["ik"] = "chao", ["ie"] = "che", ["if"] = "chen", ["ig"] = "cheng", ["ii"] = "chi", ["is"] = "chong", ["ib"] = "chou", ["iu"] = "chu", ["iw"] = "chua", ["iy"] = "chuai", ["ir"] = "chuan", ["id"] = "chuang", ["iv"] = "chui", ["ip"] = "chun", ["io"] = "chuo", ["ci"] = "ci", ["cs"] = "cong", ["cb"] = "cou", ["cu"] = "cu", ["cr"] = "cuan", ["cv"] = "cui", ["cp"] = "cun", ["co"] = "cuo", ["da"] = "da", ["dl"] = "dai", ["dj"] = "dan", ["dh"] = "dang", ["dk"] = "dao", ["de"] = "de", ["dz"] = "dei", ["df"] = "den", ["dg"] = "deng", ["di"] = "di", ["dw"] = "dia", ["dm"] = "dian", ["dc"] = "diao", ["dx"] = "die", ["dn"] = "din", ["d;"] = "ding", ["dq"] = "diu", ["ds"] = "dong", ["db"] = "dou", ["du"] = "du", ["dr"] = "duan", ["dv"] = "dui", ["dp"] = "dun", ["do"] = "duo", ["oe"] = "e", ["oz"] = "ei", ["of"] = "en", ["og"] = "eng", ["or"] = "er", ["fa"] = "fa", ["fj"] = "fan", ["fh"] = "fang", ["fz"] = "fei", ["ff"] = "fen", ["fg"] = "feng", ["fc"] = "fiao", ["fo"] = "fo", ["fs"] = "fong", ["fb"] = "fou", ["fu"] = "fu", ["ga"] = "ga", ["gl"] = "gai", ["gj"] = "gan", ["gh"] = "gang", ["gk"] = "gao", ["ge"] = "ge", ["gz"] = "gei", ["gf"] = "gen", ["gg"] = "geng", ["gs"] = "gong", ["gb"] = "gou", ["gu"] = "gu", ["gw"] = "gua", ["gy"] = "guai", ["gr"] = "guan", ["gd"] = "guang", ["gv"] = "gui", ["gp"] = "gun", ["go"] = "guo", ["ha"] = "ha", ["hl"] = "hai", ["hj"] = "han", ["hh"] = "hang", ["hk"] = "hao", ["he"] = "he", ["hz"] = "hei", ["hf"] = "hen", ["hg"] = "heng", ["hm"] = "hm",  ["hs"] = "hong", ["hb"] = "hou", ["hu"] = "hu", ["hw"] = "hua", ["hy"] = "huai", ["hr"] = "huan", ["hd"] = "huang", ["hv"] = "hui", ["hp"] = "hun", ["ho"] = "huo", ["ji"] = "ji", ["jw"] = "jia", ["jm"] = "jian", ["jd"] = "jiang", ["jc"] = "jiao", ["jx"] = "jie", ["jn"] = "jin", ["j;"] = "jing", ["js"] = "jiong", ["jq"] = "jiu", ["ju"] = "ju", ["jr"] = "juan", ["jt"] = "jue", ["jp"] = "jun", ["ka"] = "ka", ["kl"] = "kai", ["kj"] = "kan", ["kh"] = "kang", ["kk"] = "kao", ["ke"] = "ke", ["kz"] = "kei", ["kf"] = "ken", ["kg"] = "keng", ["ks"] = "kong", ["kb"] = "kou", ["ku"] = "ku", ["kw"] = "kua", ["ky"] = "kuai", ["kr"] = "kuan", ["kd"] = "kuang", ["kv"] = "kui", ["kp"] = "kun", ["ko"] = "kuo", ["la"] = "la", ["ll"] = "lai", ["lj"] = "lan", ["lh"] = "lang", ["lk"] = "lao", ["le"] = "le", ["lz"] = "lei", ["lg"] = "leng", ["li"] = "li", ["lw"] = "lia", ["lm"] = "lian", ["ld"] = "liang", ["lc"] = "liao", ["lx"] = "lie", ["ln"] = "lin", ["l;"] = "ling", ["lq"] = "liu", ["ls"] = "long", ["lb"] = "lou", ["lu"] = "lu", ["lr"] = "luan", ["lt"] = "lue", ["lp"] = "lun", ["lo"] = "luo", ["ly"] = "lv", ["ma"] = "ma", ["ml"] = "mai", ["mj"] = "man", ["mh"] = "mang", ["mk"] = "mao", ["me"] = "me", ["mz"] = "mei", ["mf"] = "men", ["mg"] = "meng", ["mi"] = "mi", ["mm"] = "mian", ["mc"] = "miao", ["mx"] = "mie", ["mn"] = "min", ["m;"] = "ming", ["mq"] = "miu", ["mo"] = "mo", ["mb"] = "mou", ["mu"] = "mu", ["na"] = "na", ["nl"] = "nai", ["nj"] = "nan", ["nh"] = "nang", ["nk"] = "nao", ["ne"] = "ne", ["nz"] = "nei", ["nf"] = "nen", ["ng"] = "neng", ["ni"] = "ni", ["nw"] = "nia", ["nm"] = "nian", ["nd"] = "niang", ["nc"] = "niao", ["nx"] = "nie", ["nn"] = "nin", ["n;"] = "ning", ["nq"] = "niu", ["ns"] = "nong", ["nb"] = "nou", ["nu"] = "nu", ["nr"] = "nuan", ["nt"] = "nue", ["np"] = "nun", ["no"] = "nuo", ["nv"] = "nv", ["oo"] = "o", ["ob"] = "ou", ["pa"] = "pa", ["pl"] = "pai", ["pj"] = "pan", ["ph"] = "pang", ["pk"] = "pao", ["pz"] = "pei", ["pf"] = "pen", ["pg"] = "peng", ["pi"] = "pi", ["pw"] = "pia", ["pm"] = "pian", ["pc"] = "piao", ["px"] = "pie", ["pn"] = "pin", ["p;"] = "ping", ["po"] = "po", ["pb"] = "pou", ["pu"] = "pu", ["qi"] = "qi", ["qw"] = "qia", ["qm"] = "qian", ["qd"] = "qiang", ["qc"] = "qiao", ["qx"] = "qie", ["qn"] = "qin", ["q;"] = "qing", ["qs"] = "qiong", ["qq"] = "qiu", ["qu"] = "qu", ["qr"] = "quan", ["qt"] = "que", ["qp"] = "qun", ["rj"] = "ran", ["rh"] = "rang", ["rk"] = "rao", ["re"] = "re", ["rf"] = "ren", ["rg"] = "reng", ["ri"] = "ri", ["rs"] = "rong", ["rb"] = "rou", ["ru"] = "ru", ["rw"] = "rua", ["rr"] = "ruan", ["rv"] = "rui", ["rp"] = "run", ["ro"] = "ruo", ["sa"] = "sa", ["sl"] = "sai", ["sj"] = "san", ["sh"] = "sang", ["sk"] = "sao", ["se"] = "se", ["sz"] = "sei", ["sf"] = "sen", ["sg"] = "seng", ["ua"] = "sha", ["ul"] = "shai", ["uj"] = "shan", ["uh"] = "shang", ["uk"] = "shao", ["ue"] = "she", ["uz"] = "shei", ["uf"] = "shen", ["ug"] = "sheng", ["ui"] = "shi", ["ub"] = "shou", ["uu"] = "shu", ["uw"] = "shua", ["uy"] = "shuai", ["ur"] = "shuan", ["ud"] = "shuang", ["uv"] = "shui", ["up"] = "shun", ["uo"] = "shuo", ["si"] = "si", ["ss"] = "song", ["sb"] = "sou", ["su"] = "su", ["sr"] = "suan", ["sv"] = "sui", ["sp"] = "sun", ["so"] = "suo", ["ta"] = "ta", ["tl"] = "tai", ["tj"] = "tan", ["th"] = "tang", ["tk"] = "tao", ["te"] = "te", ["tz"] = "tei", ["tg"] = "teng", ["ti"] = "ti", ["tm"] = "tian", ["tc"] = "tiao", ["tx"] = "tie", ["t;"] = "ting", ["ts"] = "tong", ["tb"] = "tou", ["tu"] = "tu", ["tr"] = "tuan", ["tv"] = "tui", ["tp"] = "tun", ["to"] = "tuo", ["wa"] = "wa", ["wl"] = "wai", ["wj"] = "wan", ["wh"] = "wang", ["wz"] = "wei", ["wf"] = "wen", ["wg"] = "weng", ["wo"] = "wo", ["ws"] = "wong", ["wu"] = "wu", ["xi"] = "xi", ["xw"] = "xia", ["xm"] = "xian", ["xd"] = "xiang", ["xc"] = "xiao", ["xx"] = "xie", ["xn"] = "xin", ["x;"] = "xing", ["xs"] = "xiong", ["xq"] = "xiu", ["xu"] = "xu", ["xr"] = "xuan", ["xt"] = "xue", ["xp"] = "xun", ["ya"] = "ya", ["yl"] = "yai", ["yj"] = "yan", ["yh"] = "yang", ["yk"] = "yao", ["ye"] = "ye", ["yi"] = "yi", ["yn"] = "yin", ["y;"] = "ying", ["yo"] = "yo", ["ys"] = "yong", ["yb"] = "you", ["yu"] = "yu", ["yr"] = "yuan", ["yt"] = "yue", ["yp"] = "yun", ["za"] = "za", ["zl"] = "zai", ["zj"] = "zan", ["zh"] = "zang", ["zk"] = "zao", ["ze"] = "ze", ["zz"] = "zei", ["zf"] = "zen", ["zg"] = "zeng", ["va"] = "zha", ["vl"] = "zhai", ["vj"] = "zhan", ["vh"] = "zhang", ["vk"] = "zhao", ["ve"] = "zhe", ["vz"] = "zhei", ["vf"] = "zhen", ["vg"] = "zheng", ["vi"] = "zhi", ["vs"] = "zhong", ["vb"] = "zhou", ["vu"] = "zhu", ["vw"] = "zhua", ["vy"] = "zhuai", ["vr"] = "zhuan", ["vd"] = "zhuang", ["vv"] = "zhui", ["vp"] = "zhun", ["vo"] = "zhuo", ["zi"] = "zi", ["zs"] = "zong", ["zb"] = "zou", ["zu"] = "zu", ["zr"] = "zuan", ["zv"] = "zui", ["zp"] = "zun", ["zo"] = "zuo" }
--    -- 这里可以添加具体的双拼转全拼的实现逻辑
--   local result_table = {}
--   for i = 1, #input, 2 do
--     local pair = input:sub(i, i + 1)
--     if i + 1 > #input then
--       pair = input:sub(i)
--     end
--     table.insert(result_table, mspy2qp_table[pair] or pair)
--   end
--   return table.concat(result_table, "")
-- end

-- 封装 curl 发送网络请求 
local function http_get(url)
   local handle = io.popen("curl -m 0.5 -s '" .. url .. "'")
   local result = handle:read("*a")
   handle:close()
   return result
end

local translator = {}

function translator.init(env)
    -- 初始化时清空日志文件
    logger:clear()
    logger:info("云输入处理器初始化完成")
end

function translator.func(input, seg, env)
    local engine = env.engine
    local context = engine.context
   
   -- 判断是否存在标点符号或者长度超过设定值,如果是在seg后面添加promp说明
   
      -- 在segment后面添加prompt
      local composition = context.composition
      if(not composition:empty()) then
         -- 获得队尾的 Segment 对象
         local segment = composition:back()
         if segment then
            local prompt_text = "     ▶ 回车AI转换" 
            -- 有几种可能呢? 两个参数,有可能设置了cloud_translate_prompt,但是segment.prompt还没有设置
            -- 有可能设置了cloud_translate_prompt变成flase,但是segment.prompt之前设置过了
            -- 有可能cloud_translate_prompt是false,segment.prompt也没有设置
            -- 有可能设置了cloud_translate_prompt,之前segment.prompt也设置过了
            if context:get_option("cloud_translate_prompt") then
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
                
            elseif not context:get_option("cloud_translate_prompt") then
               if segment.prompt == prompt_text then
                  segment.prompt = ""
               end
            end
         end
   
      end

   --  logger:info("处理输入: " .. tostring(context:get_option("cloud_translate")))
    if not context:get_option("cloud_translate") then
      -- 查看有没有云翻译的标识, 没有的话直接退出
      return
    else
      context:set_option("cloud_translate", false)  -- 重置选项，避免重复触发
    end

    -- 如果input当中存在标点符号,则对input进行切分处理,以标点符号为边界
   local url = make_url(input, 0, 5)
   logger:info("构建的百度云输入法API请求URL: " .. url)
   -- local reply = http.request(url)
   local reply = http_get(url)
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
         logger:info("处理候选词: " .. candidate_data[1] .. ", 拼音长度: " .. candidate_data[2] .. ", 拼音: " .. candidate_data[3].pinyin)
         local candidate = Candidate("baidu_cloud", seg.start, seg.start + candidate_data[2], candidate_data[1], "   [百度云]")
         candidate.quality = 2  -- 设置候选词优先级
         
         -- 检查拼音是否匹配输入的前缀
         logger:info("检查拼音前缀匹配: " .. candidate_data[3].pinyin)
         local pinyin_without_apostrophe = string.gsub(candidate_data[3].pinyin, "'", "")
         local input_prefix = string.sub(input, 1, candidate_data[2])
         logger:info("输入前缀: " .. input_prefix .. ", 拼音无单引号: " .. pinyin_without_apostrophe)
         if pinyin_without_apostrophe == input_prefix then
            -- 设置预编辑文本，将单引号替换为空格便于显示
            candidate.preedit = string.gsub(candidate_data[3].pinyin, "'", " ")
         end
         
         -- 输出候选词
         yield(candidate)
      end
   end   
end


function translator.fini(env)
    logger:info("云输入处理器结束运行")
end


return translator
