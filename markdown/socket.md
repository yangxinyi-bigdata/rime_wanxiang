## socket 命名空间

`socket` 命名空间包含了 LuaSocket 的核心功能。

要获取 `socket` 命名空间，请运行：

```
-- 加载 socket 模块
local socket = require("socket")
```

socket.headers.**canonic**

`socket.headers.canonic` 表被 HTTP 和 SMTP 模块用于将小写字段名转换回它们的规范大小写形式。当一个小写字段名作为该表的键存在时，在字段名被发送出去时，相关联的值将被替换。

如果需要在运行时进行修改，你可以通过运行以下代码获取 `headers` 命名空间：

```
-- 加载 headers 模块
local headers = require("headers")
```

socket.**bind(**address, port [, backlog]**)**

这个函数是一个快捷方式，它创建并返回一个绑定到本地 `address` 和 `port` 的 TCP 服务器对象，准备接受客户端连接。可选地，用户还可以为 [`listen`](https://lunarmodules.github.io/luasocket/tcp.html#listen) 方法指定 `backlog` 参数（默认为 32）。

注意：返回的服务器对象将设置选项 "`reuseaddr`" 为 `**true**`。

socket.**connect[46](**address, port [, locaddr] [, locport] [, family]**)**

这个函数是一个快捷方式，它创建并返回一个连接到指定 `port` 上的远程 `address` 的 TCP 客户端对象。可选地，用户还可以指定要绑定的本地地址和端口（`locaddr` 和 `locport`），或将 socket 系列限制为 "`inet`" 或 "`inet6`"。如果不为 `connect` 指定 `family`，创建的是 tcp 还是 tcp6 连接取决于你的系统配置。定义了两个 connect 的变体作为简单的辅助函数来限制 `family`：`socket.connect4` 和 `socket.connect6`。

socket.**_DEBUG**

如果库是在启用调试支持的情况下编译的，这个常量将被设置为 `**true**`。

socket.**_DATAGRAMSIZE**

[`receive`](https://lunarmodules.github.io/luasocket/udp.html#receive) 和 [`receivefrom`](https://lunarmodules.github.io/luasocket/udp.html#receivefrom) 调用使用的默认数据报大小。（除非在编译时更改，否则值为 8192。）

socket.**gettime()**

返回以秒为单位的 UNIX 时间。你应该将此函数返回的值相减以获得有意义的值。

```
t = socket.gettime()
-- 执行一些操作
print(socket.gettime() - t .. " 秒已过")
```

socket.**newtry(**finalizer**)**

创建并返回一个*干净的* [`try`](https://lunarmodules.github.io/luasocket/socket.html#try) 函数，允许在抛出异常之前进行清理。这实现了 [LTN012，使用终结异常](https://github.com/lunarmodules/luasocket/blob/master/ltn013.md) 中描述的想法。

`Finalizer` 是一个将在 `try` 抛出异常之前被调用的函数。

该函数返回你定制的 `try` 函数。

注意：这个想法在 LuaSocket 中实现协议时节省了*大量*的工作：

```
foo = socket.protect(function()
    -- 连接到某处
    local c = socket.try(socket.connect("somewhere", 42))
    -- 创建一个在错误时关闭 'c' 的 try 函数
    local try = socket.newtry(function() c:close() end)
    -- 放心地执行所有操作，c 将被关闭
    try(c:send("hello there?\r\n"))
    local answer = try(c:receive())
    ...
    try(c:send("good bye\r\n"))
    c:close()
end)
```

socket.**protect(**func**)**

将抛出异常的函数转换为安全函数。此函数仅捕获由 [`try`](https://lunarmodules.github.io/luasocket/socket.html#try) 和 [`newtry`](https://lunarmodules.github.io/luasocket/socket.html#newtry) 函数抛出的异常。它不会捕获普通的 Lua 错误。这实现了 [LTN012，使用终结异常](https://github.com/lunarmodules/luasocket/blob/master/ltn013.md) 中描述的想法。

`Func` 是一个调用 [`try`](https://lunarmodules.github.io/luasocket/socket.html#try)（或 `assert`，或 `error`）来抛出异常的函数。

返回一个等效的函数，该函数在 [`try`](https://lunarmodules.github.io/luasocket/socket.html#try) 调用失败的情况下，不是抛出异常，而是返回 `**nil**` 后跟错误消息。

socket.**select(**recvt, sendt [, timeout]**)**

socket.select 是一个多路复用 I/O 监控函数，用于同时监视多个 socket 的状态变化。根据文档，它的功能如下：

1. 监控 socket 状态
- recvt：监控哪些 socket 有数据可读
- sendt：监控哪些 socket 可以立即写入数据
- timeout：等待状态改变的最大时间（秒）

2. 返回三个值：
- 准备好读取的 socket 列表
- 准备好写入的 socket 列表
- 错误消息（如果有）

等待多个 socket 改变状态。

`Recvt` 是一个包含要测试是否有字符可读的 socket 的数组。`sendt` 数组中的 socket 被监视以查看是否可以立即写入。`Timeout` 是等待状态改变的最大时间（以秒为单位）。`**nil**`、负数或省略的 `timeout` 值允许函数无限期地阻塞。`Recvt` 和 `sendt` 也可以是空表或 `**nil**`。数组中的非 socket 值（或具有非数字索引的值）将被静默忽略。

该函数返回一个准备读取的 socket 列表、一个准备写入的 socket 列表和一个错误消息。如果满足超时条件，错误消息为 "`timeout`"；如果对 `select` 的调用失败，则为 "`select failed`"；否则为 `**nil**`。返回的表具有双重键，既有整数索引，也有 socket 本身作为键，以简化测试特定 socket 是否已更改状态。

**注意：** `select` 可以监视的 socket 数量有限，由常量 [`socket._SETSIZE`](https://lunarmodules.github.io/luasocket/socket.html#setsize) 定义。根据系统的不同，默认情况下这个数字可能高达 1024 或低至 64。通常可以在编译时更改这个值。使用更多的 socket 调用 `select` 将引发错误。

**重要提示**：WinSock 中的一个已知错误会导致 `select` 在非阻塞 TCP socket 上失败。该函数可能会将 socket 返回为可写，即使该 socket *尚未*准备好发送。

**另一个重要提示**：在调用 accept 之前，在接收参数中使用服务器 socket 调用 select *不能*保证 [`accept`](https://lunarmodules.github.io/luasocket/tcp.html#accept) 会立即返回。使用 [`settimeout`](https://lunarmodules.github.io/luasocket/tcp.html#settimeout) 方法，否则 `accept` 可能会永远阻塞。

**还有一个提示**：如果你关闭一个 socket 并将其传递给 `select`，它将被忽略。

**使用 select 与非 socket 对象**：任何实现了 `getfd` 和 `dirty` 的对象都可以与 `select` 一起使用，允许来自其他库的对象在 `socket.select` 驱动的循环中使用。

socket.**_SETSIZE**

[`select`](https://lunarmodules.github.io/luasocket/socket.html#select) 函数可以处理的最大 socket 数量。

socket.**sink(**mode, socket**)**

从流 socket 对象创建一个 [LTN12](https://github.com/lunarmodules/luasocket/blob/master/ltn012.md) 接收器。

`Mode` 定义接收器的行为。以下选项可用：

- `"http-chunked"`：在应用*分块传输编码*后通过 socket 发送数据，完成后关闭 socket；
- `"close-when-done"`：通过 socket 发送所有接收到的数据，完成后关闭 socket；
- `"keep-open"`：通过 socket 发送所有接收到的数据，完成后保持 socket 打开。

`Socket` 是用于发送数据的流 socket 对象。

该函数返回具有适当行为的接收器。

socket.**skip(**d [, ret1, ret2 ... retN]**)**

丢弃一定数量的参数并返回剩余的参数。

`D` 是要丢弃的参数数量。`Ret1` 到 `retN` 是参数。

该函数返回 `retd+1` 到 `retN`。

注意：此函数可用于避免创建虚拟变量：

```
-- 从 SMTP 服务器回复中获取状态码和分隔符
local code, sep = socket.skip(2, string.find(line, "^(%d%d%d)(.?)"))
```

socket.**sleep(**time**)**

在给定的时间内冻结程序执行。

`Time` 是要休眠的秒数。如果 `time` 为负数，函数立即返回。

socket.**source(**mode, socket [, length]**)**

从流 socket 对象创建一个 [LTN12](https://github.com/lunarmodules/luasocket/blob/master/ltn012.md) 源。

`Mode` 定义源的行为。以下选项可用：

- `"http-chunked"`：从 socket 接收数据，并在返回数据之前删除*分块传输编码*；
- `"by-length"`：从 socket 接收固定数量的字节。此模式需要额外的参数 `length`；
- `"until-closed"`：从 socket 接收数据，直到另一端关闭连接。

`Socket` 是用于接收数据的流 socket 对象。

该函数返回具有适当行为的源。

socket.**_SOCKETINVALID**

无效 socket 的操作系统值。这可以与 [`tcp:getfd`](https://lunarmodules.github.io/luasocket/tcp.html#getfd) 和 [`tcp:setfd`](https://lunarmodules.github.io/luasocket/tcp.html#setfd) 方法一起使用。

socket.**try(**ret1 [, ret2 ... retN]**)**

如果 `ret1` 为假值，则抛出异常，使用 `ret2` 作为错误消息。该异常应该只被 [`protect`](https://lunarmodules.github.io/luasocket/socket.html#protect) 保护的函数捕获。这实现了 [LTN012，使用终结异常](https://github.com/lunarmodules/luasocket/blob/master/ltn013.md) 中描述的想法。

`Ret1` 到 `retN` 可以是任意参数，但通常是嵌套在 `try` 中的函数调用的返回值。

如果 `ret1` 不是 `**nil**` 或 `**false**`，该函数返回 `ret1` 到 `retN`。否则，它调用 `error`，传递包装在带有元表的表中的 `ret2`，该元表被 [`protect`](https://lunarmodules.github.io/luasocket/socket.html#protect) 用于区分异常和运行时错误。

```
-- 连接或抛出带有适当错误消息的异常
c = socket.try(socket.connect("localhost", 80))
```

socket.**_VERSION**

这个常量包含一个描述当前 LuaSocket 版本的字符串。