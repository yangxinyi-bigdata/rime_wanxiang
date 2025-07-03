# debug_translator.lua 使用说明

## 功能说明
debug_translator.lua 是一个调试翻译器，用于输出翻译器处理阶段的详细信息，包括：

- 输入信息（input字符串、长度等）
- Segment信息（状态、位置、tags、候选项等）
- Environment信息（引擎状态、上下文、选项等）
- Translation信息（候选项详情、质量等）

## 配置方法

### 1. 在schema文件中添加调试翻译器

在 `wanxiang_pro.schema.yaml` 的 `translators` 段落中添加：

```yaml
translators:
  - lua_translator@*debug_translator  # 调试翻译器
  - predict_translator                 # 预测候选的生成器
  - punct_translator                   # 标点翻译器
  # ...其他翻译器
```

### 2. 临时启用调试（推荐）

如果只想临时调试，可以将调试翻译器放在翻译器列表的开头：

```yaml
translators:
  - lua_translator@*debug_translator  # 临时调试，完成后删除此行
  - script_translator                  # 脚本翻译器
  # ...其他翻译器
```

### 3. 针对特定条件调试

可以在recognizer中设置特定的触发条件：

```yaml
recognizer:
  patterns:
    debug_mode: "^DEBUG.*$"  # 输入DEBUG开头的内容时触发调试

lua_translator@debug_translator:
  tag: debug_mode  # 只处理带有debug_mode标签的segment
```

## 输出信息说明

### 输入信息
- `input`: 当前输入的字符串
- `input length`: 输入长度

### Segment信息
- `status`: segment状态
- `start/_start/_end`: 位置信息
- `length`: segment长度
- `tags`: 相关的标签列表
- `selected_index`: 当前选中的候选项索引
- `prompt`: 提示信息

### Environment信息
- `schema_id`: 当前方案ID
- `context.input`: 上下文输入
- `context.caret_pos`: 光标位置
- `options`: 各种选项状态（中英文模式、标点模式等）
- `composition`: 编辑状态信息

### 候选项信息
- `type`: 候选项类型
- `start/_end`: 候选项位置范围
- `text`: 候选项文本
- `comment`: 注释信息
- `preedit`: 预编辑文本
- `quality`: 候选项质量权重
- `genuine`: 是否为真实候选项

## 使用场景

### 1. 调试segment范围问题
当出现像 `hlui`ok`keyi` 这样的segment范围异常时，可以：
1. 启用debug_translator
2. 输入相同的内容
3. 查看日志中的segment start/end信息
4. 分析哪个阶段导致范围异常

### 2. 调试候选项生成
- 查看哪些翻译器生成了候选项
- 检查候选项的质量和排序
- 分析候选项的preedit是否正确

### 3. 调试环境状态
- 检查各种选项的开关状态
- 查看上下文信息
- 分析composition状态

## 日志查看

调试信息会输出到日志文件：
```
/Users/yangxinyi/Library/Rime/log/debug_translator.log
```

可以实时监控日志：
```bash
tail -f /Users/yangxinyi/Library/Rime/log/debug_translator.log
```

## 注意事项

1. **性能影响**: 调试翻译器会产生大量日志，建议仅在调试时启用
2. **日志文件大小**: 长时间启用会产生大量日志，注意定期清理
3. **禁用方法**: 调试完成后记得在schema中注释掉或删除调试翻译器配置
4. **输出顺序**: 调试翻译器会输出一个调试候选项，不影响其他翻译器的正常工作

## 扩展功能

可以根据需要修改debug_translator.lua：
- 添加更多环境信息输出
- 过滤特定类型的segment或输入
- 自定义输出格式
- 添加性能计时信息
