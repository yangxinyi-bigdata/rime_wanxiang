# Script rawenglish Translator

这是一个Rime输入法的Lua翻译器，用于处理包含反引号的混合输入。

## 功能特性

- 使用 `text_splitter.split_by_rawenglish()` 函数智能切分输入
- 对文本片段（abc类型）使用 `script_translator` 进行翻译，保存text和preedit
- 对反引号内容（rawenglish类型）text为处理后内容（包含分隔符），preedit保持原始反引号形式
- 将所有片段的text和preedit分别拼接，形成最终候选词的text和preedit
- 完整的日志记录功能便于调试

## 工作原理

1. **输入切分**: 使用 `text_splitter.split_by_rawenglish(input, delimiter)` 将输入按反引号切分
2. **类型处理**:
   - `abc` 类型: 使用 `script_translator` 翻译，获取第一个候选词的text和preedit
   - `rawenglish` 类型: text为处理后内容（包含分隔符），preedit保持原始反引号形式
3. **结果拼接**: 将所有片段的text拼接成最终候选词的text，将所有片段的preedit拼接成最终候选词的preedit
4. **输出候选**: 使用 `yield()` 输出包含完整text和preedit的候选词

## 使用示例

### 输入示例
```
wokeyi`hello my love`keai
```

### 处理过程
1. 切分结果:
   - 片段1: type=abc, content='wokeyi'
   - 片段2: type=rawenglish, content=' hello my love ' (包含分隔符)
   - 片段3: type=abc, content='keai'

2. 翻译处理:
   - 'wokeyi' → text:'我可以', preedit:'wo ke yi' (通过script_translator)
   - '`hello my love`' → text:' hello my love ', preedit:'`hello my love`' (text带分隔符，preedit保持原始反引号形式)
   - 'keai' → text:'可爱', preedit:'ke ai' (通过script_translator)

3. 最终结果: 
   - text: '我可以 hello my love 可爱'
   - preedit: 'wo ke yi`hello my love`ke ai'

## 配置方法

### 1. 在schema文件中添加翻译器

```yaml
engine:
  translators:
    - script_rawenglish_translator  # 新增
    - script_translator
    - table_translator

lua_translator@script_rawenglish_translator:
  function: script_rawenglish_translator.func
  option_name: script_rawenglish_translate  # 可选开关
```

### 2. 配置反引号分隔符（可选）

```yaml
translator:
  rawenglish_delimiter: " "  # 空格分隔符，也可以设置为其他字符或留空
```

## 文件结构

- `script_rawenglish_translator.lua` - 主翻译器实现
- `text_splitter.lua` - 文本切分模块（已扩展split_by_rawenglish_with_log函数）
- `test_script_rawenglish_translator.lua` - 测试脚本
- `script_rawenglish_translator_config_example.yaml` - 配置示例

## 核心组件

### Component.Translator
```lua
env.script_translator = Component.Translator(env.engine, "translator", "script_translator")
```
在 `init()` 函数中创建，用于调用原生的script_translator功能。

### 查询翻译
```lua
local translation = env.script_translator:query(input, seg)
```
Segment参数主要提供标签信息和位置上下文，不影响候选项结果。

## 调试功能

脚本内置完整的日志记录功能，可以通过日志查看：
- 输入切分过程
- 各片段的处理结果（包括text和preedit）
- script_translator的调用情况
- 最终拼接结果（text和preedit）

## 注意事项

1. 确保已正确配置 `script_translator`
2. 反引号分隔符可根据需要调整
3. 日志功能便于调试，生产环境可关闭
4. 支持复杂的反引号嵌套和未配对情况

## 测试方法

运行测试脚本验证功能：
```lua
dofile("lua/test_script_rawenglish_translator.lua")
```
