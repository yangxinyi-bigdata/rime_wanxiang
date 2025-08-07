考虑是否要重构,先把当前的状态梳理一下吧,这个可能工作量很大,

关联文件:
[[cloud_input_processor.lua]]
[[rawenglish_segment.lua]]
[[rawenglish_translator.lua]]
[[README_script_rawenglish_translator]]
[[aux_code_filter_v3.lua]]
[[cloud_ai_filter_v2.lua]]
[[lua/punct_eng_chinese_filter.lua]]
[[lua/smart_cursor_processor.lua]]
[[lua/spans_manager.lua]]
[[lua/text_splitter.lua]]

关键词:
rawenglish
rawenglish_prompt

这家伙基本上和所有文件都有关联, 重构成本恐怕太高了.
refactor
这家我的天发生了什么为什么突然之间`

原来会出现报错