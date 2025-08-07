看起来非常不错的Python前端方案.
官方网站: https://nicegui.io/#about

### 文档页面
https://nicegui.io/documentation

我发现使用NiceGUI作为前端全面优于使用当前的Electron方案, 我希望放弃当前的Electron, 全面转向使用NiceGui, 帮我基于当前的Vue和Electron中的代码, 开发NiceGUI的前端代码.
对于当前Electron+Vue中的功能并不需要全部迁移, 只需要迁移frontend/src/views/RimeSettings.vue, frontend/src/views/Settings.vue,frontend/src/views/components/AiAssistantConfig.vue 中的功能即可.
对于键盘监听, 候选框之类的功能是废弃的功能, 已经变成通过rime输入法实现了.
现在帮我更新NiceGUI代码实现上述功能.

先完善NiceGUI网站页面的基本功能: 
1. 首先打开原来的Web看看两者功能区别.
2. 