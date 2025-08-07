ai_para_input_method
para_ai_input_methos
### 1. 删除的配置

aipara_stroke 笔画反查删除:
reverse_stroke 

aipara_radical  部件拆字反插
radical_lookup
radical_reverse
lookup

super_comment
super_tips


### 出现的辅助码commet处理
我自己开发的aux_code_filter_v3竟然也受到了影响.
为什么当辅助码出现的时候, 没有匹配上长句呢? 那说明长句根本就没有产生.

分析:
辅助码到底是如何工作的? 
set_fuzhu_schema
__include: 间接辅助

speller:
当中的algebra
```
  comment_format:          # 清空comment提示
    - xform/.*//           # 清空所有comment信息

  spelling_hints: 0          # 关闭拼写提示
  comment_format:            # 清空comment提示
    - xform/.*//             # 清空所有comment信息

```


```
set_cn_en:                     #中英混输
  user_dict: en_dicts/zrm      #可选的值有：en_dicts/pinyin， en_dicts/zrm， en_dicts/flypy ，en_dicts/mspy， en_dicts/sogou， en_dicts/pinyin

# 中英混合词汇
cn_en:
  dictionary: ""
  __include: set_cn_en
  db_class: stabledb
  enable_completion: true
  enable_sentence: false
  initial_quality: 0.5
  comment_format:
    - xform/^.+$//
```
　

### 输入第一个字母后的候选词提示
考虑是否需要这个功能：当输入 a 的时候，除了第一个候选词以外，后面的候选词都是 ai ， ar 之类的，并且在备注中说明这是什么。
对于双拼这个没问题，但是对于全拼来说可能会存在不好的体验。
这个到时候再说吧。


这样，标题和正文之间的间隔就会变宽。如果需要进一步微调，可以修改 `margin-bottom` 的数值。

1. 考虑其它的组件对这个的影响，会不会产生 bug 。
2. 对于相同字母开头的 ai, ar, ac 等等，是不是要加候选词提示。
3. 如何实现用户可以自定义配置，自己添加候选词，自己设置触发符号。
4. 用户可以配置要不要输出题问的内容。
5. 用户可以配置要不要使用前缀，还是在 python 服务端只要开启了，就可以自动实现功能。
6. 考虑在ai提问状态下,用户按下回车,会如何发送百度候选词,返回的候选词如何添加. 应该和原来的一样,只是confirm光标位置不对劲的原因.
7. 考虑中文标点符号如何进行替换的,如何赦免。ai返回的可能是直接的markdown语法,英文不是在反引号包裹当中,所以可能产生错误的替换， ai 的结果没必要替换。
8. 考虑ai返回结果之后,用户可能进行的各种各样的操作，都能正确的处理。
9. 当前出现的bug, ai返回内容过程中半路突然切换了中英文.
10. 将云输入法也改成流式处理.

### 当前开发流程
1. 在cloud_input_processor.lua中,是遇到虚拟快捷键,重新刷新候选词
2. lua/ai_talk_segmentor.lua中匹配特定的输入内容,然后添加tags的segment.
3. lua/ai_talk_translator.lua中1. 遇到ai_talk这类标签,生成一个候选词提示.
4. ai_reply这类标签,持续刷新候选词.

- [x] 首先测试一下每个新的配置是否能够生效
	- [x] 发现奇数长度的无法触发。
	- [x] 确认是辅助码功能冲突,应该添加豁免.
	- [x] 测试不同的消息发送过来的效果
也不能全部豁免，因为我后面的内容还需要使用辅助码.
所以这里应该,对于标记成seg为ai的seg的部分进行豁免.
所以检查前边的seg为这些的标签,我已经添加了标签"ai_reply",和, "ai_talk",
所以检查seg当中,如果存在, "ai_talk"的部分,应该进行豁免.

- [x] ai回复的消息,对中英标点符号进行豁免

- [x] 测试一下连续对话功能, 添加猫娘功能.
- [x] 候选词的个数有没有办法动态修改呢？

两个思路：
- [ ] ai应该主动式的聊天,也就是随机的触发聊天,怎么触发呢? 应该在停止聊天的时候,光标停留在那里的时候,随机的触发,如何判断呢?应该将当前输入法的状态记录下来,发送到python端,也就是当输入法处于not is_composing,而且已经有一段时间的时候,会自动触发. 另外应该判断当前是否处于一个能够输入内容的状态当中,如果不能的话就不行了.关键是这个怎么判断呢?
- [ ] 另外一个思路是当前触发上屏通知的时候,应该将上屏的内容持续不断的发送到服务端保存起来,然后在云输入法的时候,可以用于根据上下文触发. 另外还可以用于和ai对话聊天的时候一个参考信息,ai看到了我在输入的内容,也就大概知道我在干什么了,聊天对话的时候可以更加的有效.
- [ ] 在万象输入法的配置基础上更新成自己的配置文件,把那些没用的功能删除
- [x] 配置大模型带网络搜索功能的问答
配置大模型带网络搜索,这个应该有很多api都有这个功能了,问一下.
openai的大模型api是否支持连接网络搜索功能,如果支持,如何实现?

今天尝试对大模型对话功能进行优化.
实现网络对话功能,但是说实话这个功能可能并没有那么重要.



- [x] 应该可以设置使用 Enter,还是Shift+Enter,或者是Space, 或者是不发送任何按键.适配于不同的软件.

- [ ] 各种ai能力的对应开头应该是可以进行配置的,用户可以根据自己的喜好自定义各种开头. 不仅如此，用户还可以新增自己喜欢的提示词，例如加一个猫娘什么的。用户还可以自己配置某一个对话是不是连续的对话。使用s:开头的对话可以进行网络搜索。
	这个应该是在python那边配置,然后python那边添加配置文件,以及添加对应的提示词即可.
- [ ] 从新梳理ai对话的方法,让其达到可以使用的程度.

- [x] tab光标跳转又出现问题了，非常奇怪，明天看看怎么回事？

接下来应该搞一个什么功能？

- [ ] 考虑把所有ai_assistant配置中的冒号去掉,添加到代码中.
- [ ] 除此之外，用户应该也可以配置到底要不要输出前边的前缀，例如可以开启翻译模式，那么不需要在前边输入特定的标识符，也可以一直自动触发翻译结果。
- [ ] 翻译模式在服务端中开启之后的功能.
- [ ] 对menu中各个方法功能进行测试.

## AI模式常开功能开发
**功能畅享:** 
当服务端开启某个开关,则rime这边输入中文文本,点击上屏之后,这个上屏的动作应该被拦截.然后清空所有输入内容,然后服务端接收到这个文本内容,然后进行粘贴.
看来这个功能必须修改rime这边的配置,rime这边应该有一个配置开关,开启之后,则上屏动作会被拦截,转而将准备上屏的文本发送给服务端.
服务端翻译之后,将内容发送回给rime.
rime这边的开关状态是动态变化的,不需要重新加载配置,所以应该是实时监控的,如果服务端开启了,会给rime这边发送一个虚拟按键,虚拟按键会激活和服务端的通信,从而改变option开关的配置.
开关改变之后,则上屏动作会被拦截.

**最终形态:**
1. 在服务端点击配置开关,以及翻译形态.
2. 在rime中输入文本,空格或者数字键上屏之后,会情况当前输入,然后弹出翻译的内容.

**开发流程:**
1. 在服务端添加一个接口,当接受到某个类型的消息的时候,不再发送回车键,而是直接发送消息.
2. 在服务端UI中添加一个开关,可以设置当前的模式,有翻译模式,对话模式, 猫娘模式等等,任意一个模式都可以配置, 配置了之后, 在config中添加配置,翻译的状态配置.
3. 在rime配置中添加一个属性,这个属性如果存在某个值,就是处于某种ai对话模式当中.
4. 在服务端打开翻译配置之后,实时触发一个快捷键,将开关配置发送给rime,并在后续只要没有关闭就一直监控rime发送过来的开关状态,如果开关不对,就发送过去修改开关状态的命令.
5. 在rime中添加一个按键拦截,如果翻译开关处于打开的状态,则拦截输入按键,变成清空输入文本,然后将上屏内容通过翻译功能发送给服务端.
6. 工作方式都是一样的,所以所有配置的ai对话模式都是可以通过启动之后,进行工作. 所以应该是设置一个属性,字符串,有多个不同的值,而不是仅仅一个true或者false的开关,或者也可以是一系列的开关,先判断开关, 在判断属性字符串? 

步骤
1. 还是先搞 python 端吧,在python端UI页面当中,添加一个配置,
2. rime当中先搞,rime如何获取这个属性的值呢? 不管怎么获取,反正先判断这个属性的值,然后只要有这个属性的某种值存在就要进行拦截.

rime提示词:
首先这个值的属性信息应该从哪里获取? 应该是从服务器进行获取,在每次和服务器通信的过程中,服务器会发过来命令,如果存在设置这个属性的命令,就会设置这个属性. 
然后应该每次将这个属性的值发送给服务端.

KEEPON_CHAT_TRIGGER
keepon_chat_trigger
1. 读取配置中的上屏按钮,如果用户输入的是所有的上屏按钮,都应该获取到这个按钮,然后分析这个按钮按下去之后,会不会触发上屏操作,也就是候选词长度是不是一直延伸到末尾.
2. 如果是延伸到末尾,则应该进行拦截,然后计算出将要上屏的文本,然后发送socket的ai指令.
3. 然后清空当前input即可.
keepon_chat_trigger这个属性的值先不用着急去开发,可以先实现服务端和客户端之间的这个属性的功能传递,然后有了这个属性的值再去进行下一步的开发.

4. 首先在src/rime_config_manager/config_manager.py当中提取rime配置文件wanxiang_pro.schema.yaml中的ai_assistant.chat_triggers中的所有配置项.

我希望通过服务端来管理rime配置文件wanxiang_pro.schema.yaml中的ai_assistant中的所有配置项. 所以应该在UI页面当中读取到当前的ai_assistant的配置项, 然后可以在前端中可以新增一个ai_assistant的配置, 或者删除一个配置项,来对rime中的ai_assistant进行管理.
rime的配置文件在/Users/yangxinyi/Library/Rime/aipara_pro.schema.yaml中, 本项目中的Rime文件是备份使用.

我在rime输入法中添加了一个属性keepon_chat_trigger, 当属性被设置的时候, 例如属性设置为: "cat_ai_chat", 用户的所有对话,不需要添加前缀"ac:"就会自动触发和猫娘对话的功能.
帮我在src/rime_config_manager/prompt_manager.py当中添加一个配置保存当前启用哪个ai对话功能, 例如 KEEPON_CHAT_TRIGGER: "translate_ai_chat".
然后在frontend/src/views/RimeSettings.vue和frontend/src/views/components/AiAssistantIntegratedConfig.vue中添加对于这个配置项的管理.
rime输入法会将当前KEEPON_CHAT_TRIGGER的属性值同步到服务端来, 服务端接收到属性值之后, 应该和服务端中设置的这个属性的值进行比较, 如果属性的值不同, 以服务端设置为准, 则需要给rime中发送一条更改属性值的命令, 在src/rime_socket_serve.py的"_处理Rime状态"函数中, 以及pending_commands = self._检查待处理配置变更(client_id)中进行命令的处理.

注意事项:
1. 在前端开发中应该使用Electron的后端IPC访问方式.
2. 后端的访问端口是8000
3. 前端会自动更新不需要重新启动
4. 后端不会自动更新,修改完代码之后需要重启服务器

我希望将在rime_option_intime分支中开发的实时和rime同步配置的代码重新添加到本分支中来, 相关代码已经复制到了src/temp文件夹当中,可以参考这部分代码进行添加. 
但是原来同步的那些简体,中英文等配置不再需要实时同步,而是新添加的ENABLE_CHAT_TRIGGER功能需要实时同步, rime会在每次发送过来的状态信息当中说明当前这个属性的值, 如果发现属性的值,和服务器当中配置的不同,则应该进行修改.

　
**20250804**
今天开发流程：
集中在 rime 这边的代码开发
1. 首先判断输入的字符是不是env.alternative_select_keys中的字符
2. 如果是则判断当前这个选词按键输入之后,会不会完成一次完整的输入法输入,也就是完成上屏操作.
3. 如果是完成上屏操作,则应该将这个按键拦截不再发送,同时获取即将上屏的文本, 调用lua/ai_assistant_translator.lua中的向服务端发送消息的代码:


如果是对于这种情况呢? 
在连续ai对话过程中, 如果获取了一个回复,  但是没有输入空格上屏.
然后再输入新的内容, 这是个时候再按空格上屏, 则因为标签没有匹配到ai_reply,则会变成一个粘贴的命令? 

对了,因为现在这样输入很容易忘记,还不如自动在前边添加 猫娘对话: 这样的内容, 不就方便多了吗? 
两种方案都保留下来,后面根据情况测试使用哪个.

- [x] 上屏的空格按键没有拦截啊
- [ ] 想一下是不是把云提示词和英文原文上屏的功能,换成两个不同的按键,因为现在有一些不安全感,很容易搞错.
- [x] 现在是直接清空,应该可以通过配置文件控制,不清空,而是正常上屏.
- [ ] 对menu的add_translation, Translation应该是一个由Candidate组成的table,不知道能不能自己合并table,估计够呛.
- [ ] 自动空格上屏
- [ ] 现在属性状态的同步总是有延迟,应该要第一时间生效,也就是可以考虑我主动发送一个虚拟快捷键,来让rime马上更新状态.
- [x] 研究一下配置直接动态修改,似乎没有必要去重新部署rime直接动态修改就可以了.
	- [x] 对整个配置的处理进行彻底的重构, 甚至在init里面都不需要重新读入配置, 直接在一个脚本里面都托管了也可以


配置实时动态更新
1. 当配置更新之后, 服务端会发送一个快捷键, 快捷键会添加一个开关,或者属性,并且会触发配置的实时更新.
2. 每个函数当中,


- [ ] 发现修改了输入模式之后,但是不生效的问题,似乎换一个别的软件生效了,但是ob中依然不生效.

- [x] 原来的翻译函数中对AI Trans那部分的处理可以删除了
	- [x] 整个翻译功能应该都不需要了,直接替换成原来老的就可以了.
- [x] 还有另外一种方案: 就是当keepon_chat_trigger属性设置了,直接在前边添加"AI回复"这类的内容,然后自动触发原来的逻辑,就可以了.
- [x] 现在测试又没办法发现这个问题了: ai对话模式当中,进入英文模式时空格失效.
- [x] at: ok n 这样输入的时候,删除键不好使.
	- [x] 重构这部分的处理, 迁移到seg当中,
- [x] 英文模式中的单引号,会导致bug,应该让英文模式下的单引号，不具备分词的能力。
- [ ] nihk`1 " 输入这个的时候, 双引号被替换成了中文双引号,应该在英文模式中跳过的,应该也是bug了
应该是这个坐标范围没有计算对
```
-- 标点符号替换函数, 对于传递进来的坐标范围进行替换
function text_splitter.replace_punct_skip_pos(text, chinese_pos_str, logger)

在上面的匹配中就应该发现这个标点符号是英文段落中的, 实际上是没有标点符号的,算了太麻烦.还是原来的思路吧.
if cand.text and text_splitter.has_punctuation_no_rawenglish(cand.text, logger) then
```
这两个 bug 先修复一下。
这两个怎么回事来着？


- [ ] 新重构的英文模式,辅助码会出现问题,明天修复一下
- [x] AI翻译: this is very good 你就是一个很好的人, 前面的英文部分没有发送过去
	- [x] 先看看英文模式我有没有标记片段,应该标记了吧? 
	- [x] 如果最后一段是英文呢? 又能不能成功发送呢.

突然想到了,要不然我还是用 commit通知消息, 
engine:commit_text(final_commit_text) 这个应该也会触发上屏通知啊.
所以我用这个就可以了.
不对啊,这个也是我计算出来的啊.


ok 我们 fuck 

- [x] 在ob中切换之后没有生效
切换没有生效应该如何测试呢?
首先确认服务端有没有发送过来命令, 然后查看rime输入法,确认rime有没有收到修改的命令.
我发现所有的配置都是可以动态修改的,所以是不需要重启的,看来我需要重启启动这个效果了, 其实也不用一直检查是否一致啊,可以让rime自己去检查是否一致,如果不一致就自己进行修改就可以了.



AI翻译:这就是为什么 I am the best one 。
That's why I am the best one.

AI翻译: this is why 我是最好的
I am the best.
AI翻译: this is why 我是最好的
这就是为什么我是最好的。
当没有英文的时候不会保存


分析都有哪些分支需要考虑:
和ai对话的功能中,有这么几种可能:
1. 使用前缀触发 at:, at:等, 或者在context:get_property('keepon_chat_trigger')属性的值存在的时候, 不需要输入任何字符则自动触发这种ai对话功能.
2. 1. ai对话中用户输入的文本不上屏, 2. ai对话中用户输入的文本去除掉前边的chat_names,例如"猫娘对话:"这部分内容,其他内容正常上屏. 3.用户输入的全部文本上屏
所以一共有6种可能性, 如果判断处于这些可能性呢? 

1.判断context:get_property('keepon_chat_trigger')属性的值, 进入这个分支, 如果

但在context:get_property('keepon_chat_trigger')这个分支中可能根本就没有 "猫娘对话:" 这部分内容,也就不需要除去. 或者我换成另外一种对话方式则需要去除.
添加一个参数strip_chat_prefix,控制是否要去除前缀.

所以如果
context:get_property('keepon_chat_trigger')启用:
判断commit_input为true, 则再判断strip_chat_prefix, 如果strip_chat_prefix为true, 则拦截提交内容,清空,再重新手动上屏字符串.
如果strip_chat_prefix为false, 则什么都不用做,直接上屏就可以.

如果commit_input为false,则拦截提交,清空,并且向服务端发送消息,表示不用输入空格换行.

不管context:get_property('keepon_chat_trigger') 是否启用:
如果用户输入之前的内容代表标识: 例如 ac:
则判断commit_input为true, 则再判断strip_chat_prefix, 如果strip_chat_prefix为true, 则拦截提交内容,清空,再重新手动上屏字符串.
如果strip_chat_prefix为false, 则什么都不用做,直接上屏就可以.
如果commit_input为false,则拦截提交,清空,并且向服务端发送消息,表示不用输入空格换行.

如果要拦截就不能使用现在的commit_notifier


- [x] 将ai云输入法的功能，也变成流式的。这个可能会比较麻烦啊。
- [x] 重新梳理整个云输入法的流程, 把超时时间之类不合理的配置一下。
local stream_result = tcp_socket.read_translate_result(timeout)
read_translate_result 这个用上了超时时间

## (完成)ai云输入法的功能，也变成流式的
这个比较复杂，先梳理一个完整的思路。
1. 首先前边给服务器发送消息这部分应该是没有什么区别的, 还是直接tcp_socket.translate发送候选词.
2. 原来是parsed_data.cloud_candidates or parsed_data.ai_candidates获取返回的候选词,这部分应该不用修改,还是直接这样就可以。
3. 但是ai_candidates这个返回的会变成空的. 则输出的结果应该是 1.百度云,2.普通候选词.
4. 然后服务端发送ctrl+F11,刷新候选词, 使用read_latest_from_ai_socket接口持续获取最新的候选词内容.
5. 获取到候选词之后,便利当前候选词,将ai候选词添加到第二个位置.(但这时有一个很大的问题,当刷新候选词的时候,如何将百度候选词添加上去呢), 在第一次已经获取到了百度云的候选词,则这个时候应该不需要再发送消息,而是只需要读取新的消息,读取到的数据合并到

要不然就这样,持续不断的去返回消息,包括百度接口的返回结果和ai接口的返回结果,反正又没几个字.

我希望将lua/cloud_ai_filter_v2.lua中的云输入法功能也改成流式获取结果.
1. 参考lua/ai_assistant_translator.lua中的流式数据读取代码.
2. 将lua/tcp_socket_sync.lua中的function M.translate函数的发送数据和接收数据进行拆分成两个函数.
3. 在lua/cloud_ai_filter_v2.lua中每次触发只执行一次tcp_socket.translate函数.
4. 当收到lua/cloud_input_processor.lua的key_repr == "Control+F11"信号之后刷新候选词, 则再次执行cloud_ai_filter_v2.lua, 但不再执行tcp_socket.translate, 而是只执行拆分出来的读取数据功能.然后将读取到的数据parsed_data添加到候选词中.

我希望将"def 云翻译功能"函数改成流式获取模式, 当接收到rime发送过来的待翻译拼音之后, "_执行百度云翻译"和"_执行AI翻译_避免重复"两个函数不再同时返回,而是在百度云获取到结果之后,就立即返回一次.
然后将AI翻译改成流式接口接收大模型结果, 
然后每隔0.5s向rime返回一次消息,消息中包含原来百度的翻译结果,以及最新的大模型翻译结果.
参考"_异步AI对话流式响应"中的方式,每次发送消息之后发送快捷键"ctrl+F11",一直到所有大模型响应结果发送完成.


M.process_ai_socket_data_with_timeout() 这个是带超时的处理AI翻译服务TCP套接字数据（用于大模型等长时间等待的场景）


tcp_socket.read_latest_from_ai_socket()

现在让我来试一下这个东西到底好不好使，所以说不可能知道，在湘乡的空间里。

- [x] 还是应该把输入法这边的状态,输入内容,等等都同步到服务端,就算现在用不上,以后也肯定会用的上的.反正这也不算什么负担,并不会造成什么算力或者延迟,其他软件恐怕比这个多一百倍.
当前是在输入状态发生变化的时候发送,反正这个随时可以改,现在还是将输入法状态发送过去吧.
上屏的时候,输入的内容也发送过去.
都同步什么状态呢 ?
1. 当前的输入状态
2. 当前在


- [x] bug: tab键, 也不一定要跳过前边，但是必须的出现后选词，现在的问题是不会重新进行分词了.
- [x] 当我触发进入ai状态之后,辅助码,标点符号替换,英文模式,云输入法,spans光标跳转,等等全部都无法正常工作了,这是因为我在开发的时候,就没考虑到将来会有一个新的ai模式,导致根本处理不了这些情况.最好就是能够独立,如何独立呢?就是用segment分段进行处理,而不是直接处理整个segment,当处理segment的时候,如果segment已经被确认上屏了, 那么后面的按照原来的思路正常处理,就不会出现问题了.

- [x] bug: 在a:这种模式当中,英文模式失效了,哎,每次添加一个新功能，原来其他的各种功能都会受到影响? 怎么才能解耦呢? 
- [x] bug: 现在虽然有候选词了,但是tab光标没有成功获取到spans的信息

- [x] bug:在AI问答状态下,回车获取云候选词bug
- [x] 按下a之后,在后面添加prompt或者是候选词中添加 comment 
都试试.能不能自动化呢？
1. 从chat_triggers中读取所有keys, 然后过滤出所有value中含有"a.:"的数据
2. 拼接成一个字符串,当用户输入的是a的时候,将这个字符串添加到prompt中.看起来很简单嘛！
放在哪里呢？seg当中添加prompt,
- [x] 辅助码中输入 wzx和 lqwzyu之后再将光标移动到wz后面输入x,结果不同,排查错误原因。
所以这也是一个这类的错误，应该使用光标前边的内容.
刘wzx

竟然拼接出 xyu来了, 也就是最后三个字符, 所以主要是没有排除光标右边的导致的.
猫娘对话：你好啊 okde womfde ugho 奇怪了

- [x] ai对话模式下，在反引号的英文部分当中,tab光标跳转没有能够正确的跳转.
你 okok 我们
```
ni`okok`womf
```
逻辑是先获得第一段的Vertex  0,2
第二段 6
第三段 0,2,4
然后再累加计算绝对位置.

在ai模式下计算的时候应该跳过第一段。
但是现在很明显没有跳过,是整个进行计算的,所以出现了错误.
应该计算剩余片段的Vertex, 应该在前边累加上一个ai段的长度吧.

```
ac:nihk`okokok`wo
主要是因为前边这段不是abc,如果也是abc,就不存在问题.
所以是因为不是abc,没有参与运算.

[2025-07-31 17:43:42] [INFO] [rawenglish_translator:624] long_span.vertices 1: 3
[2025-07-31 17:43:42] [INFO] [rawenglish_translator:624] long_span.vertices 2: 4
[2025-07-31 17:43:42] [INFO] [rawenglish_translator:624] long_span.vertices 3: 5
[2025-07-31 17:43:42] [INFO] [rawenglish_translator:624] long_span.vertices 4: 7
[2025-07-31 17:43:42] [INFO] [rawenglish_translator:624] long_span.vertices 5: 12
[2025-07-31 17:43:42] [INFO] [rawenglish_translator:624] long_span.vertices 6: 15
[2025-07-31 17:43:42] [INFO] [rawenglish_translator:624] long_span.vertices 7: 17
```

    - lua_segmentor@*ai_assistant_segmentor     #AI对话自定义分词器，分割 a: 和拼音部分
    - abc_segmentor                        #标识常规的文字段落，加上 abc 这个 tag
    - lua_segmentor@*rawenglish_segment      #添加反引号分词器

首先分词流程: ac:nihk`okokok`wo
在ai_assistant_segmentor将ac:分词 后面 nihk`okokok`wo分词成abc.

cand候选词是rime算出来的, 考虑了前面的a:这部分. 算的是第二段.
而我的segment script类型是我自己算出来的,没有考虑 a:这部分
    local segments = text_splitter.split_by_rawenglish_with_log(input, rawenglish_delimiter_before,
        rawenglish_delimiter_after, logger)
    如果我把input改成整个input呢?


- [x] bug: 英文模式下,暴露chinese_pos
![[CleanShot 2025-07-29 at 22.22.36@2x.png]]

分析一下: 就是没有删除掉
- [x] bug: 当输入法触发了云输入法的提示消息，在输入内容，还在这个状态。
分析一下这个bug: 
很简单,就是当我输入了触发了之后,然后在结束输入之后应该将这个清空.

- [x] bug: ai对话状态下,如果触发了云输入法提示消息,按2没有反应, 和云输入法没关系,只要是选择2都没有反应, 是因为不能用整个input判断,需要裁切
应该用segmentation_input而不是整个 input 


- [x] bug: 在获取了一次大模型回复之后,再输入空格上屏了之前的内容.哦我想起来了,应该是我没有上屏直接退出了,所以那个属性的值还没有改.
分析：这个是哪来着？



```
        -- 我之前应该处理过这种情况,如果seg的类型不对的话,应该是直接跳过的.
        -- 按顺序创建候选词（保持返回结果的顺序）
        for i, cand_info in ipairs(ordered_candidates) do
            logger.info("创建候选词 " .. i .. ": " .. cand_info.text .. " (类型: " .. cand_info.type .. ")" ..
                            " segment._start :" .. segment._start .. " segment._end: " .. segment._end)
            if cand_info.type == "baidu_cloud" then
                cand_comment = "   [云输入]"
            elseif cand_info.type == "ai_cloud" then
                cand_comment = "   [AI识别]"
            end
            local candidate = Candidate(cand_info.type, segment._start, segment._end, cand_info.text, cand_comment)
            candidate.preedit = original_preedit
            yield(candidate)
        end
```


这个应该在哪里搞呢?
1. 首先看一下进入了哪个tab分支,应该是进入了,
获取到spans信息了,为什么呢,
因为设置了:
context:get_property(SPANS_VERTICES_KEY)
应该是在候选词中设置的。
如果说有人提出了声音，我再去调整也来得及，我才是真正的主角。
首先第一步: 
2. logger.debug("获取到spans信息") 有这个信息,说明一定是给了spans信息,也有可能是上一轮当中给的但是没有删除.
3. 现在我要确定是在哪里设置的spans信息.如果确定呢？一定是
4. 当前确定一定是在输入了冒号之后,才出现的spans信息.
分析一下,冒号是一个标点符号，我设置过，当内容中存在标点符号，则应该添加 spans 信息，所以应该是这个地方的问题。

如果说我对a:这种内容直接跳过的话,则如果说后面的内容当中存在标点符号，则会导致没有spans信息,然后tab光标无法进行跳转。
合理的应该是前边的设置成一个spans信息,然后后面的内容正常按照原来的方法生成spans信息.





- [x] 研究一下，出现的错误符号是怎么回事. 在vscode中会出现红色的错误符号，但是在其它应用中并没有看到错误符号。
- [x] obsidian中, 发现回复的英文前边有一个空格.发现所有的回复前边都有一个空格,以前好像没有？


修改:
我发现原来reply_messages中可能有重复内容, 而reply_messages代表的是ai回复之后,在input当中输入的内容,如果存在重复词,则会造成bug.
当前
lua/ai_talk_segmentor.lua中不再根据input == reply_message来添加tags, 而是使用input == xxx,
xxx代表, chat_triggers:中的ai_chat: "ai:" 在冒号前边添加reply, 变成 "ai_reply:" , 这样就不会出现重复值了. 
对于这段代码, 不再根据ai回复的类型添加input,修改get_current_ai_reply_message函数,变成获取对应的chat_triggers, 然后添加_reply的内容.
```
    if context:get_property("get_ai_stream") == "true" then

        if key_repr == "Control+F11" then
            logger.info("触发重新刷新候选词: ")
            if context.input == "" then
                local reply_message = get_current_ai_reply_message(env, context)
                context.input = reply_message
                logger.info("设置AI回复消息: " .. reply_message)
            end
            context:refresh_non_confirmed_composition()
            return kAccepted
        end

    end
```

对于lua/ai_talk_translator.lua中的检查所有配置的AI回复标签部分代码, 
reply_message = env.ai_assistant_config.reply_messages[trigger] or "AI助手:"
部分也需要进行修改.
而且生成的候选词的preedit要使用配置文件中的,reply_messages_preedit:
```
    if not matched_reply_tag and env.ai_assistant_config and env.ai_assistant_config.tag_to_trigger then
        for tag, trigger in pairs(env.ai_assistant_config.tag_to_trigger) do
            if segment:has_tag(tag) then
                matched_reply_tag = tag
                matched_trigger = trigger
                is_prefix_display = false  -- 这是回复显示
                -- 从配置中获取回复消息
                reply_message = env.ai_assistant_config.reply_messages[trigger] or "AI助手:"
                logger.info("检测到AI回复标签: " .. tag .. " (触发器: " .. trigger .. ")")
                break
            end
        end
    end

```

env.ai_assistant_config.reply_messages_preedit 添加进来的配置,应该添加到ai回复生成的候选词的preedit当中去.
同时我添加了配置chat_names ,代表出发了符号,例如用户输入"a:"时,应该触发的候选词内容.
```
  chat_names:
    simple_ai_chat: "AI提问:"
    ai_chat: "AI提问:"
    context_chat: "AI提问:"
    role_chat: "猫娘对话:"
    cat_chat: "猫娘对话:"
    translate_assistant: "AI翻译:"
    code_assistant: "AI编程:"
    write_assistant: "AI写作:"
    search_assistant: "AI搜索:"
    summarize: "AI总结:"
    explain: "AI解释:"
    improve: "AI改进:"
```
在lua/ai_talk_translator.lua的代码中, 对于"ar:"替换的候选词应该使用chat_names中的值, 而不是reply_messages
```
    -- 检查所有配置的AI触发器标签
    if env.ai_assistant_config and env.ai_assistant_config.chat_triggers then
        for trigger_name, trigger_prefix in pairs(env.ai_assistant_config.chat_triggers) do
            if segment:has_tag(trigger_name) then
                matched_reply_tag = trigger_name
                matched_trigger = trigger_name
                is_prefix_display = true  -- 这是前缀显示
                -- 从配置中获取回复消息，如果没有则使用触发器前缀
                reply_message = env.ai_assistant_config.reply_messages[trigger_name] or (trigger_prefix .. " AI助手")
                logger.info("检测到AI触发器标签: " .. trigger_name .. " (前缀显示)")
                break
            end
        end
    end
```



```


我在rime端添加了很多新的ai对话类型:
chat_type就是chat_triggers中的各种字段, 我希望在python服务端中根据传入的chat_type不同,调用不同的ai对话提示词,返回不同的结果.
然后再返回的json消息中也添加上对应的标识字段.

    -- 构建对话消息数据
    local chat_data = {
        messege_type = "chat",
        commit_text = commit_text, -- 对话内容
        chat_type = chat_type, -- AI对话类型
        timestamp = current_time
    }
{"messege_type":"chat","timestamp":1753775136955,"commit_text":"角色回复：你好，你是谁？","chat_type":"role_chat"}

  # 触发器配置：定义所有AI助手的前缀    
  chat_triggers:
    simple_ai_chat: "a:"          # 简单对话
    ai_chat: "ai:"                # AI对话
    context_chat: "ac:"           # 上下文对话
    role_chat: "ar:"              # 角色扮演对话
    translate_assistant: "t:"     # 中英翻译
    code_assistant: "code:"       # 编程助手
    write_assistant: "write:"     # 写作助手
    search_assistant: "s:"        # 搜索助手
    summarize: "sum:"             # 总结工具
    explain: "exp:"               # 解释工具
    improve: "imp:"               # 改进工具

在ai对话中的部分类型,例如context_chat,role_chat,等是需要连续对话的,也就是保存指定数量的历史对话消息.

```
AI翻译：什么是最美丽的东西？
What is the most beautiful thing?

猫娘对话:你好啊
喵~好的我的主人

- [x] 不再使用reply_tags,而是直接在chat_triggers的key中添加reply, 例如role_chat,变成role_chat_reply

- [x] 突然想到可以所有和大模型对话的功能都以a开头, 然后输入a,就会出现一系列的候选词提示,比如说ac, ab, ar,ai等等,然后我们选择对应的选项,就可以实现各种不同的功能.


- [x] 添加输入法问答模式.
- [x] 改成拦截上屏按键,然后使用粘贴功能将内容粘贴上去.
- [x] 添加输入法翻译模式.

- [x] bug: ai生成的内容,似乎不需要中文标点符号替换

- [x] 在 obsidian 中遇到 bug ，ai 回复过程中，输入框消失，并且显示切换到中文输入状态。




## 4.1 AI 写作状态机
为了满足用户对于稳健逻辑的需求，我们必须将整个交互过程建模为一个状态机。该状态机由 Lua 翻译器在 Rime 内部进行管理，可以使用一个全局表（table）来存储当前状态。

**状态定义**：

- `IDLE`：空闲状态，无输入或 AI 交互。
- `COMPOSING`：用户正在输入，但未触发 AI 请求。显示标准的 Rime 候选词。
- `AWAITING_AI`：已向代理发送请求，但尚未收到任何响应。UI 可显示“加载中”提示。
- `AI_STREAMING`：正在从代理接收词元流。AI 候选词可见且正在动态更新。
- `AI_COMPLETE`：词元流结束。AI 候选词变为一个静态、可选择的选项。
- `AI_SELECTED`：用户通过方向键或鼠标悬停等方式，高亮选中了 AI 候选词。


## 4.2 用户操作处理矩阵
下表是本报告的核心部分，它为编程实现提供了一份详尽、可操作的指南。该矩阵将每一种可能的用户输入，根据当前所处的状态，映射到特定的系统响应。这种方法强制对每一种交互可能性进行严谨和系统的分析，是“覆盖各种分支”和“减少 bug”的唯一途径，将设计从抽象概念转化为具体、可测试的规范。

| 用户操作                  | 当前状态                                         | 前提条件                  | 系统响应与逻辑                                                      | 新状态                         |
| --------------------- | -------------------------------------------- | --------------------- | ------------------------------------------------------------ | --------------------------- |
| 输入字符 (如 'a')          | `COMPOSING`                                  | -                     | 将字符追加到输入缓冲区。执行标准 Rime 查词。                                    | `COMPOSING`                 |
| 输入字符 (如 'a')          | `AI_STREAMING`, `AI_COMPLETE`, `AI_SELECTED` | -                     | 判定 AI 建议失效。向代理发送 `CANCEL` 消息。将新字符追加到缓冲区，并作为一次新的输入开始处理。       | `COMPOSING`                 |
| 按 `空格键`               | `AI_SELECTED`                                | AI 候选词被高亮选中。          | 将 AI 候选词的完整文本上屏。可选：向代理发送流结束消息用于分析。清空输入缓冲区。                   | `IDLE`                      |
| 按 `空格键`               | `COMPOSING`                                  | 一个非 AI 的 Rime 候选词被选中。 | 上屏选中的标准 Rime 候选词。                                            | `IDLE`                      |
| 按 `ESC`               | `AWAITING_AI`, `AI_STREAMING`                | -                     | 向代理发送 `CANCEL` 消息。移除任何与 AI 相关的 UI 提示（如加载动画）。恢复到标准 Rime 候选列表。 | `COMPOSING`                 |
| 按 `ESC`               | `AI_COMPLETE`, `AI_SELECTED`                 | -                     | 取消 AI 候选词的选择，并将其从候选列表中移除。恢复到标准 Rime 候选列表。                    | `COMPOSING`                 |
| 按 `退格键`               | `AI_STREAMING`, `AI_COMPLETE`, `AI_SELECTED` | -                     | 判定 AI 建议失效。向代理发送 `CANCEL` 消息。从缓冲区删除最后一个字符。执行新的标准查词。          | `COMPOSING`                 |
| 按 `回车键`               | `AI_SELECTED`                                | AI 候选词被高亮选中。          | 与 `空格键` 逻辑相同。上屏 AI 候选词。                                      | `IDLE`                      |
| 按 `PageDown`/`PageUp` | `AI_STREAMING`, `AI_COMPLETE`                | 候选菜单可见。               | 执行标准 Rime 翻页行为。如果 AI 候选词因此被高亮，则更新状态。                         | `AI_SELECTED` 或 `COMPOSING` |
| `鼠标点击` AI 候选词         | `AI_STREAMING`, `AI_COMPLETE`                | -                     | 选中并立即上屏该 AI 候选词。                                             | `IDLE`                      |
| Rime 窗口失去焦点           | `AWAITING_AI`, `AI_STREAMING`                | -                     | 向代理发送 `CANCEL` 消息。清理当前状态。                                    | `IDLE`                      |








