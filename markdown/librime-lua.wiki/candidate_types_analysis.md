# Rime 候选词类型 (Candidate Type) 完整说明

根据 librime 源代码分析，候选词的 `type` 属性包含以下完整类型：

## 主要候选词类型

### 1. **"completion"**
- **定义**: 编码未完整的候选词
- **特征**: `remaining_code_length != 0`
- **质量**: `quality` 会减1分（在源码中：`incomplete ? -1 : 0`）
- **用途**: 提示用户可能的完整输入，引导继续输入

### 2. **"user_table"** 
- **定义**: 用户字典中的候选词
- **特征**: 来自用户字典，会随用户输入更新权重
- **质量**: `quality` 会加0.5分（在源码中：`is_user_phrase ? 0.5 : 0`）
- **用途**: 个性化候选词，会学习用户输入习惯

### 3. **"table"**
- **定义**: 静态字典中的候选词  
- **特征**: 来自固定词典，不会更新权重
- **用途**: 基础词汇，输入法的核心词库

### 4. **"sentence"**
- **定义**: 由造句功能生成的句子候选词
- **特征**: 通过词图（WordGraph）和诗人（Poet）算法组合生成
- **标识**: 通常带有统一符号标记（kUnitySymbol = " ☯ "）
- **用途**: 智能造句，提高长句输入效率

## 辅助候选词类型

### 5. **"user_phrase"**
- **定义**: 用户字典中的短语
- **特征**: 用户自定义或学习产生的短语
- **用途**: 个性化短语输入

### 6. **"phrase"** 
- **定义**: 一般短语或词组
- **特征**: 来自词典的标准短语
- **用途**: 常用词组输入

### 7. **"punct"**
- **定义**: 标点符号候选词
- **来源**: 
  - `engine/segmentors/punct_segmentor`
  - `symbols:/patch/recognizer/patterns/punct`
- **用途**: 标点符号输入

### 8. **"simplified"**
- **定义**: 简化字候选词
- **特征**: 可能由繁简转换产生
- **用途**: 繁简转换功能

### 9. **"uniquified"**
- **定义**: 经过去重合并处理的候选词
- **特征**: 合并了重复的候选词
- **用途**: 避免候选词列表中的重复项

### 10. **"thru"**
- **定义**: 直通字符
- **特征**: ASCII字符直接输出
- **场景**: 在 `commit_history` 中记录被拒绝的ASCII字符
- **用途**: 记录直接输出的字符

## 源代码关键位置

根据 `table_translator.cc` 源代码分析：

```cpp
// 在 TableTranslation::Peek() 方法中
bool incomplete = e->remaining_code_length != 0;
auto type = incomplete ? "completion" : is_user_phrase ? "user_table" : "table";

// 在 SentenceTranslation::Peek() 方法中  
auto result = New<Phrase>(
    translator_ ? translator_->language() : NULL,
    is_user_phrase ? "user_table" : "table",  // 句子中的词也区分用户词典和静态词典
    start_,
    start_ + code_length,
    entry);
```

## 质量权重计算

根据源代码，不同类型的候选词会影响其显示优先级：

```cpp
phrase->set_quality(exp(e->weight) +
                   options_->initial_quality() +
                   (incomplete ? -1 : 0) +        // completion 类型减1分
                   (is_user_phrase ? 0.5 : 0));   // user_table 类型加0.5分
```

## 实际应用

在 Lua 脚本中可以通过候选词类型进行不同的处理：

```lua
function filter(input, env)
   for cand in input:iter() do
      if cand.type == "completion" then
         -- 处理未完成的候选词
      elseif cand.type == "user_table" then
         -- 处理用户词典候选词
      elseif cand.type == "sentence" then
         -- 处理句子候选词
      end
      yield(cand)
   end
end
```

这个完整的类型系统帮助输入法实现智能的候选词管理和优先级排序。
