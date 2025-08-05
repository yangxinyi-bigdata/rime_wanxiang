考虑是否要重构,先把当前的状态梳理一下吧,这个可能工作量很大,

关联文件:
[[cloud_input_processor.lua]]
[[backtick_segment.lua]]
[[backtick_translator.lua]]
[[README_script_backtick_translator]]
[[aux_code_filter_v3.lua]]
[[cloud_ai_filter_v2.lua]]
[[lua/punct_eng_chinese_filter.lua]]
[[lua/smart_cursor_processor.lua]]
[[lua/spans_manager.lua]]
[[lua/text_splitter.lua]]

关键词:
backtick
backtick_prompt

这家伙基本上和所有文件都有关联, 重构成本恐怕太高了.
refactor