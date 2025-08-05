欢迎来到 librime-lua wiki！


安装
===

weasel
---

1. 准备[编译文件](https://github.com/hchunhui/librime-lua#build)（或者在[actions](https://github.com/hchunhui/librime-lua/actions)中的最新构建产物）。

2. 解压 `rime-xxxx-Windows.7z/dist/lib/rime.dll` 文件，并覆盖到 weasel 安装目录下的 `rime.dll` 文件。

使用方法
===
1. 创建 `PATH_TO_RIME_USER_DATA_DIR/rime.lua`：

    ```lua
    function date_translator(input, seg)
       if (input == "date") then
          --- Candidate(类型, 开始位置, 结束位置, 文本, 注释)
          yield(Candidate("date", seg.start, seg._end, os.date("%Y年%m月%d日"), " 日期"))
       end
    end
    
    function single_char_first_filter(input)
       local l = {}
       for cand in input:iter() do
          if (utf8.len(cand.text) == 1) then
             yield(cand)
          else
             table.insert(l, cand)
          end
       end
       for i, cand in ipairs(l) do
          yield(cand)
       end
    end
    ```

    更多示例：[rime.lua](https://github.com/hchunhui/librime-lua/tree/master/sample/rime.lua)

    文档：[wiki](https://github.com/hchunhui/librime-lua/wiki/Scripting)

2. 在你的输入方案中引用 Lua 函数：

    ```yaml
    engine:
      ...
      translators:
        ...
        - lua_translator@date_translator
        - lua_translator@other_lua_function1
        ...
      filters:
        ...
        - lua_filter@single_char_first_filter
        - lua_filter@other_lua_function2
    ```

3. 部署并尝试


构建
===

构建依赖
---
  - librime >= 1.5.0
  - LuaJIT 2 / Lua 5.1 / Lua 5.2 / Lua 5.3 / Lua 5.4

说明
---
1. 准备源代码

   将源代码移动到 librime 的 `plugins` 目录：
   ```
   mv librime-lua $PATH_TO_RIME_SOURCE/plugins/lua
   ```

   或者你可以使用 `install-plugins.sh` 脚本自动获取 librime-lua：
   ```
   cd $PATH_TO_RIME_SOURCE
   bash install-plugins.sh hchunhui/librime-lua
   ```

2. 安装依赖

   安装 Lua 的开发文件：
   ```
   # 对于 Debian/Ubuntu：
   sudo apt install liblua5.3-dev   # 或者 libluajit-5.1-dev
   ```
   构建系统将使用 `pkg-config` 来搜索 Lua。

   构建系统也支持在 `thirdparty` 目录中从源代码构建 Lua。
   可以使用以下命令下载 `thirdparty` 目录：
   ```
   cd $PATH_TO_RIME_SOURCE/plugins/lua
   git clone https://github.com/hchunhui/librime-lua.git -b thirdparty --depth=1 thirdparty
   ```

3. 构建

   按照 librime 的构建说明进行：
   ```
   # 在 Linux 上，合并构建
   make merged-plugins
   sudo make install
   ```

   有关 RIME 插件的更多信息，
   请参见[这里](https://github.com/rime/librime/tree/master/sample)。