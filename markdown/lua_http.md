# 引言

lua-http 是一个高性能、功能强大的 HTTP 和 WebSocket 库，适用于 Lua 5.1、5.2、5.3 以及 LuaJIT。该库的一些主要特性包括：

- 支持 HTTP 版本 1、1.1 和 2，[ 符合 RFC](https://tools.ietf.org/html/rfc7230) [7230 和 RFC 7540](https://tools.ietf.org/html/rfc7540) 规范。
- 提供客户端和服务器端 API
- 完全异步的 API，在执行通常会阻塞的操作时不会阻塞当前线程。
- [支持 RFC 6455](https://tools.ietf.org/html/rfc6455) 规范的 WebSockets，包括 ping/pong、二进制数据传输及 TLS 加密。
- 传输层安全（TLS） - lua-http 通过 [luaossl](https://github.com/wahern/luaossl) 支持 HTTPS 和 WSS。
- 轻松集成到其他事件循环或脚本中

### 为什么选择 lua-http？

Lua-http 库旨在填补 Lua 生态系统中的空白，提供一个具备以下特性的 HTTP 和 WebSocket 库：

- 异步且高性能的
- 无需强制开发者遵循特定模式即可使用。反之，该库可适配多种常见模式。
- 可以在非常高级的水平上使用，无需理解 HTTP 数据的传输（除了连接地址之外）。
- 提供了一个丰富的低级 API，可用于在协议层创建强大的基于 HTTP 的工具。

由于这些设计目标，该库简单且不显眼，能够在通用硬件上支持数万个连接。

lua-http 是一个灵活的 HTTP 和 WebSocket 库，允许开发人员在构建互联网应用程序时专注于核心业务功能。如果您正在寻找一种方法来简化互联网应用程序的开发、在游戏中启用 HTTP 网络、创建新的物联网（IoT）系统，或为特定用例编写高性能的自定义 Web 服务器，lua-http 提供了您所需的工具。

### 便携性

lua-http 是一个纯 Lua 代码库，依赖于以下外部库：

- [cqueues](http://25thandclement.com/~william/projects/cqueues.html)- Lua 的 Posix API 库
- [luaossl](http://25thandclement.com/~william/projects/luaossl.html)- Lua 语言的 TLS/SSL 绑定库
- [lua-zlib](https://github.com/brimworks/lua-zlib)- Lua 语言的 zlib 库可选绑定

lua-http 可以在支持 cqueues 和 openssl 的任何操作系统上运行，截至本文撰写时，这些操作系统包括 GNU/Linux、FreeBSD、NetBSD、OpenBSD、OSX 和 Solaris。

## 常见使用场景

以下是两个简单的示例，演示了如何使用 lua-http 库：

### 检索文档

客户端的最高级接口是 [*http.request*](https://daurnimator.github.io/lua-http/0.4/#http.request)。通过使用 [`new_from_uri`](https://daurnimator.github.io/lua-http/0.4/#http.request.new_from_uri) 从一个 URI 构建一个[*请求*](https://daurnimator.github.io/lua-http/0.4/#http.request)对象并立即评估它，你可以轻松地获取一个 HTTP 资源。

```
local http_request = require "http.request"
local headers, stream = assert(http_request.new_from_uri("http://example.com"):go())
local body = assert(stream:get_body_as_string())
if headers:get ":status" ~= "200" then
    error(body)
end
print(body)
```

### WebSocket 通信

要从 WebSocket 服务器请求信息，请使用 `websocket` 模块创建一个新的 WebSocket 客户端。

```
local websocket = require "http.websocket"
local ws = websocket.new_from_uri("wss://echo.websocket.org")
assert(ws:connect())
assert(ws:send("koo-eee!"))
local data = assert(ws:receive())
assert(data == "koo-eee!")
assert(ws:close())
```

## 异步操作

lua-http 设计为异步执行，因此可在您的应用程序、服务器或游戏中使用，而不会阻塞主循环。异步操作通过利用 cqueues 实现，这是一个 Lua/C 库，集成了 Lua yield 机制和内核级 API，以减少 CPU 占用。所有 lua-http 操作（包括 DNS 解析、TLS 协商以及读写操作）在从 cqueue 或启用了 cqueue 的“容器”中运行时，都不会阻塞主应用程序线程。虽然有时需要阻塞一个例程（yield）并等待外部数据，但任何阻塞的 API 调用都会带有一个可选超时，以确保网络应用程序的良好行为并避免例程无响应或“死”的情况。

异步操作是 lua-http 最强大的功能之一，且无需开发人员额外努力。例如，可以在任何 Lua 主循环中实例化一个 HTTP 服务器，并与应用程序代码并行运行，而不会对主应用程序进程产生负面影响。如果将其他支持 cqueue 的组件集成到 cqueue 循环中，应用程序将完全通过内核级轮询 API 实现事件驱动。

cqueues 可与 lua-http 配合使用，将其他功能集成到 Lua 应用程序中，从而创建强大、高效且支持 Web 的应用程序。本指南中的部分示例将使用 cqueues 进行简单演示。有关 cqueues 的更多资源，请参阅：

- 有关 cqueues 库的更多信息，请访问 [cqueues 官方网站 ](http://25thandclement.com/~william/projects/cqueues.html)。
- cqueues 的示例可以在通过 [Git 或存档](http://www.25thandclement.com/~william/projects/cqueues.html#download)获取的 cqueues 源代码中找到，或[通过以下链接](https://github.com/wahern/cqueues/tree/master/examples)在线访问。
- 有关将 cqueues 与其他事件循环库集成的更多信息，请参阅[与其他事件循环的集成 ](https://github.com/wahern/cqueues/wiki/Integrations-with-other-main-loops)。
- 对于使用 cqueues 的其他库，例如 Redis 和 PostgreSQL 的异步 API，请参阅[此处的 cqueues 维基页面 ](https://github.com/wahern/cqueues/wiki/Libraries-that-use-cqueues)。

## 会议

以下是 API 规范和通用参考列表：

### 超文本传输协议（HTTP）

- HTTP 1 请求和状态行字段在 HTTP 2 中通过*[头部对象](https://daurnimator.github.io/lua-http/0.4/#http.headers)*传递，分别存储在键 `":authority"`、`":method"`、`":path"`、`":scheme"` 和 `":status"` 下。因此，这些字段均以字符串形式保存（特别需要注意 `":status"` 字段）。
- 标题字段应始终使用小写键。

### 错误

- 无效的函数参数将引发 Lua 错误（如果进行了验证）。
- 错误以 `nil`、error 或 errno 形式返回，除非另有说明。
- 某些 HTTP/2 操作会返回或抛出特殊的 [HTTP/2 错误对象 ](https://daurnimator.github.io/lua-http/0.4/#http.h2_error)。

### 超时

所有可能阻塞当前线程的操作都接受一个`超时参数 `。该参数始终表示在返回 `nil、err_msg 或 ETIMEDOUT` 之前允许的秒数，其中 `err_msg` 是本地化的错误消息 `，例如“连接超时”`。

## 术语

Lua-http 中的许多术语都借用了 HTTP 2.

*[连接 ](https://daurnimator.github.io/lua-http/0.4/#connection)*- 对底层 TCP/IP 套接字的抽象。lua-http 目前支持两种连接类型：一种用于 HTTP 1，另一种用于 HTTP 2。

*[流 ](https://daurnimator.github.io/lua-http/0.4/#stream)*- 连接对象上的请求/响应。lua-http 提供了两种流类型：一种用于 [*HTTP 1 流* ](https://daurnimator.github.io/lua-http/0.4/#http.h1_stream)，另一种用于 [*HTTP 2 流* ](https://daurnimator.github.io/lua-http/0.4/#http.h2_stream)。常见的接口在 [*stream*](https://daurnimator.github.io/lua-http/0.4/#stream) 中有详细描述。

# 接口

lua-http 为 HTTP 1 和 HTTP 2 协议提供了独立的模块，但不同版本之间共享许多共同的概念。lua-http 提供了一个通用的接口，用于执行适用于两种协议版本（以及未来任何发展）的操作。

以下各节概述了 lua-http 库暴露的接口。

## connection

一个connection 连接封装了套接字，并提供协议特定的操作。一个连接可能包含[*流，这些流*](https://daurnimator.github.io/lua-http/0.4/#stream)封装了在连接上发生的请求/响应。或者，你可以完全忽略流，并使用低级协议特定的操作来读写套接字。

所有*连接*类型均暴露以下字段：

### `connection.type`

连接对象的使用模式。有效值为：

- `"客户端"`: 作为客户端；此连接类型用于希望发送请求的实体。
- `"服务器"`: 作为服务器运行；此连接类型用于需要响应请求的实体。

### `connection.version`

连接的 HTTP 版本号，以数字形式表示。

### `connection:pollfd()`

### `connection:events()`

### `connection:timeout()`

### `connection:connect(timeout)`

使用指定的地址、HTTP 版本以及`连接.new` 构造函数中指定的任何选项，完成与远程服务器的连接 `。` `connect` 函数将阻塞直到连接尝试完成（成功或失败）或`超时 `。连接过程可能包括 DNS 解析、TLS 协商和 HTTP/2 设置交换。成功时返回 `true`。发生错误时，返回 `nil`、错误消息和错误编号。

### `connection:checktls()`

检查套接字是否存在有效的传输层安全连接。如果连接已加密，则返回 luaossl ssl 对象。如果没有活动 TLS 会话，则返回 `nil` 并触发错误消息。有关 ssl 对象的更多信息，请参阅 [luaossl 官方网站 ](http://25thandclement.com/~william/projects/luaossl.html)。

### `connection:localname()`

返回本地套接字的连接信息。返回外部套接字的地址族、IP 地址和端口。对于 Unix 域套接字，该函数返回 `AF_UNIX` 和路径。如果连接对象未连接，则返回 `AF_UNSPEC`(0)。发生错误时，返回 `nil`、错误消息和错误编号。

### `connection:peername()`

返回套接字*对等方的*连接信息（即下一个跳转目标）。返回外部套接字的地址族、IP 地址和端口。对于 UNIX 套接字，该函数`返回 AF_UNIX 和路径 `。如果连接对象未连接，则`返回 AF_UNSPEC`（0）。发生错误时，返回 `Nil`、错误消息和错误编号。

*注意：如果客户端使用了代理，则返回的值 `:peername()` 指向代理服务器，而非远程服务器。*

### `connection:flush(timeout)`

将缓冲的待发送数据从套接字发送到操作系统。成功时返回 `true`。发生错误时，返回 `nil`、错误消息和错误代码。

### `connection:shutdown()`

按顺序关闭连接，通过关闭所有流并调用套接字的 `:shutdown()` 方法。该连接无法重新打开。

### `connection:close()`

关闭连接并释放操作系统资源。注意 `：close()` 在释放资源之前会先执行 [`connection:shutdown()`](https://daurnimator.github.io/lua-http/0.4/#connection:shutdown)。

### `connection:new_stream()`

在连接上创建并返回一个新的[*流* ](https://daurnimator.github.io/lua-http/0.4/#stream)。

### `connection:get_next_incoming_stream(timeout)`

返回连接上由对等方发起的下一个[*流* ](https://daurnimator.github.io/lua-http/0.4/#stream)。此函数可用于暂停执行并“监听”传入的 HTTP 流。

### `connection:onidle(new_handler)`

提供一个回调函数，当连接处于空闲状态时（即没有正在处理的请求且没有待处理的管道流）调用该回调函数。调用时，该函数将接收`连接`作为第一个参数。返回上一个处理程序。

## stream

HTTP *流是* HTTP 连接中请求/响应的抽象表示。在一个流中可能包含多个“头部”块以及称为“主体”的数据。

所有流类型都暴露以下字段和函数：

### `stream.connection`

底层[*连接对象* ](https://daurnimator.github.io/lua-http/0.4/#connection)。

### `stream:checktls()`

与 [`stream.connection:checktls()`](https://daurnimator.github.io/lua-http/0.4/#connection:checktls) 功能相当的便捷封装函数。

### `stream:localname()`

与 [`stream.connection:localname()`](https://daurnimator.github.io/lua-http/0.4/#connection:localname) 功能相当的便捷封装器。

### `stream:peername()`

与 [`stream.connection:peername()`](https://daurnimator.github.io/lua-http/0.4/#connection:peername) 功能相当的便捷封装器。

### `stream:get_headers(timeout)`

从流中检索下一个完整的头部对象（即一组头部或尾部）。

### `stream:write_headers(headers, end_stream, timeout)`

将给定的[*头部对象*](https://daurnimator.github.io/lua-http/0.4/#http.headers)写入流。该函数接受一个标志，用于指示这是流中的最后一个数据块。如果`标志为 true`，则流将被关闭。如果指定了`超时时间 `，流将等待发送操作完成，直到`超时时间`被超过。

### `stream:write_continue(timeout)`

发送一个包含 100 个继续标头的数据块。

### `stream:get_next_chunk(timeout)`

从套接字中返回 HTTP 主体的下一块数据，可能在最多 `timeout` 秒内阻塞。发生错误时，返回 `nil`、错误消息和错误编号。

### `stream:each_chunk()`

流迭代器 [`：get_next_chunk()`](https://daurnimator.github.io/lua-http/0.4/#stream:get_next_chunk)

### `stream:get_body_as_string(timeout)`

从流中读取整个内容并将其作为字符串返回。发生错误时，返回 `nil`、错误消息和错误编号。

### `stream:get_body_chars(n, timeout)`

从流中读取 `n 个`字符（字节）的正文，并将其作为字符串返回。如果在读取 `n 个`字符之前流结束，则返回部分结果。发生错误时，返回 `nil`、错误消息和错误编号。

### `stream:get_body_until(pattern, plain, include_pattern, timeout)`

从流中读取主体数据，直到找到 [Lua](http://www.lua.org/manual/5.3/manual.html#6.4.1)` 模式 pattern`，并将数据作为字符串返回。`plain` 是一个布尔值，用于指示是否应禁用模式匹配功能，使函数执行简单的“查找子字符串”操作，模式中的字符均不被视为特殊字符。`include_patterns` 指定是否将模式本身包含在返回的字符串中。发生错误时，返回 `nil`、错误消息和错误编号。

### `stream:save_body_to_file(file, timeout)`

从流中读取主体内容并将其保存到 [Lua 文件句柄 ](http://www.lua.org/manual/5.3/manual.html#6.8)`handlefile` 中。若发生错误，返回 `nil`、错误消息及错误代码。

### `stream:get_body_as_file(timeout)`

从流中读取主体内容并将其保存到临时文件中，然后返回一个 [Lua 文件句柄 ](http://www.lua.org/manual/5.3/manual.html#6.8)。如果发生错误，返回 `nil`、错误消息和错误编号。

### `stream:unget(str)`

将`数据`重新写入传入的数据缓冲区，使其可在后续命令中再次读取（“取消获取”数据）。成功时返回 `true`。发生错误时，返回 `nil`、错误消息和错误编号。

### `stream:write_chunk(chunk, end_stream, timeout)`

将字符串`片段`写入流。如果 `end_stream` 为 true，则会完成流的关闭操作。`write_chunk` 会无限期地`阻塞 `，直到`超时 `。发生错误时，返回 `nil`、错误消息和错误代码。

### `stream:write_body_from_string(str, timeout)`

将字符串 `str` 写入流并结束流。发生错误时，返回 `nil`、错误消息和错误编号。

### `stream:write_body_from_file(options|file, timeout)`

- `选项`是一个包含以下内容的表格：
  - `.文件 `(文件)
  - `.count`（正整数）：要写入`文件的`字节数
    默认值为无穷大（整个文件将被写入）

`将文件 file` 的内容写入流并结束流。` 文件`不会自动定位，因此在调用前请确保文件已定位到正确偏移量。发生错误时，返回 `nil`、错误消息和错误编号。

### `stream:shutdown()`

关闭流。资源被释放，流不再可用。

# 模块

## http.bit

一个抽象层，用于封装各种 Lua 位库。

结果仅在底层实现之间一致，当参数和结果在 `0` 到 `0x7fffffff` 的范围内时。

### `band(a, b)`

位与运算。

### `bor(a, b)`

位或运算。

### `bxor(a, b)`

位异或运算。

### 示例

```
local bit = require "http.bit"
print(bit.band(1, 3)) --> 1
```

## http.client

处理与 HTTP 服务器建立连接的相关操作。

### `negotiate(socket, options, timeout)`

与远程服务器协商 HTTP 设置。如果指定了 TLS，此函数将初始化加密隧道。参数如下：

- `socket` 是一个 cqueues 套接字对象socket object。

- `选项`是一个包含以下内容的表格：

  - `.tls`(布尔值，可选)：是否使用 TLS？
    默认值为 `false`

  - `.ctx`（用户数据，可选）：如果 `.tls` 为 `true，` 则使用 `SSL_CTX*`。
    如果 `.ctx` 为`空 `，则使用默认上下文。

  - `.sendname`(字符串|布尔值，可选)：要发送的 [TLS SNI](https://en.wikipedia.org/wiki/Server_Name_Indication) 主机名。

    默认值为 `true`

    - `true` 表示在 `.host` 字段**不是** IP 地址时复制该字段。
    - `false` 禁用 SNI

  - `.version`(`nil|1`.0|1.1|2): 要使用的 HTTP 版本。

    - `nil`：尝试使用 HTTP 2 协议，若失败则回退至 HTTP 1.1 协议。
    - `1.0`
    - `1.1`
    - `2`

  - `.h2_settings`(表，可选)：要使用的 HTTP/2 设置。详情请参阅 [*http.h2_connection*](https://daurnimator.github.io/lua-http/0.4/#http.h2_connection)。

### `connect(options, timeout)`

此函数返回与 HTTP 服务器的新连接。建立连接后，可以创建流以开始请求/响应交换。有关创建流的更多信息，请参阅 [`h1_stream.new_stream`](https://daurnimator.github.io/lua-http/0.4/#h1_stream.new_stream) 和 [`h2_stream.new_stream`](https://daurnimator.github.io/lua-http/0.4/#h2_stream.new_stream)。

- `options` 是一个包含 [`http.client.negotiate`](https://daurnimator.github.io/lua-http/0.4/#http.client.negotiate) 选项的表，此外还包括以下内容：
  - `套接字家族 `（整数，可选）：要使用的套接字家族。
    默认使用 `AF_INET`
  - `主机 `（字符串）：要连接的主机。
    可能是主机名或 IP 地址
  - `端口 `（字符串或整数）：以数字形式指定要连接的端口。
    例如：`"80"` 或 `80`
  - `路径 `（字符串）：要连接到的路径（UNIX 套接字）
  - `v6only`（布尔型，可选）：是否在底层套接字上设置 `IPV6_V6ONLY` 标志。
  - `绑定 `（字符串，可选）：本地出站地址及可选端口，格式`为“地址[:端口]”`。IPv6 地址可通过方括号标记指定。例如：`“127.0.0.1` `”，“127.0.0.1:50000”，“` `[::1]:30000”`。
- `超时 `（可选）是允许建立连接的最大时间（以秒为单位）。
  这包括 DNS 解析时间、连接时间、TLS 协商时间（如果启用了 TLS）以及在 HTTP 2 的情况下：设置交换时间。

#### 示例

连接到本地端口 8000 上运行的 HTTP 服务器

```
local http_client = require "http.client"
local myconnection = http_client.connect {
    host = "localhost";
    port = 8000;
    tls = false;
}
```

## http.cookie

一个用于处理 Cookie 的模块。

### `bake(name, value, expiry_time, domain, path, secure_only, http_only, same_site)`

返回一个适合用于 `Set-Cookie` 头部的字符串，其中包含传入的参数。

### `parse_cookie(cookie)`

解析 `Cookie` 标头`内容 cookie`。

返回一个包含`名称`和`值`对的字符串表。

### `parse_cookies(req_headers)`

解析 [*http.headers*](https://daurnimator.github.io/lua-http/0.4/#http.headers) 对象中的所有 `Cookie` 头部信息，并`存储在 req_headers 中 `。

返回一个包含`名称`和`值`对的字符串表。

### `parse_setcookie(setcookie)`

解析 `Set-Cookie` 头部内容 `setcookie`.

返回`名称 `、` 值和 ` ` 参数 `，其中：

- `名称`是一个字符串，包含 cookie 的名称。
- `值`是一个字符串，包含 cookie 的值。
- `params` 是一个表，其中键是 Cookie 属性名称，值是 Cookie 属性值。

### `new_store()`

创建一个新的 cookie 存储。

Cookie 对于域名、路径和名称的组合是唯一的；尽管由于路径或域名的重叠，一个请求中可能存在多个名称相同的 Cookie。

### `store.psl`

用于与公共后缀列表进行校验的 [lua-psl](https://github.com/daurnimator/lua-psl) 对象。将该字段设置为 `false` 以跳过后缀列表校验。

默认使用系统中的[最新 ](https://rockdaboot.github.io/libpsl/libpsl-Public-Suffix-List-functions.html#psl-latest)PSL。如果未安装 lua-psl，则为`空 `。

### `store.time()`

`商店`用于获取当前时间以处理过期等相关操作的函数。

默认使用基于 [`os.time`](https://www.lua.org/manual/5.3/manual.html#pdf-os.time) 的函数。

### `store.max_cookie_length`

存储中 Cookie 的最大长度（以字节为单位）；此值也用作 `:lookup()` 方法的默认最大 Cookie 长度。减少此值仅会阻止新 Cookie 被添加，不会删除现有 Cookie。

默认值为无穷大（无最大大小）。

### `store.max_cookies`

`商店中`允许的最大 Cookie 数量。减少此值仅会阻止新 Cookie 被添加，不会删除现有 Cookie。

默认值为无穷大（允许使用任意数量的 Cookie）。

### `store.max_cookies_per_domain`

每个域名`在商店中`允许的最大 Cookie 数量。减少此值仅会阻止新增 Cookie，不会删除现有 Cookie。

默认值为无穷大（允许使用任意数量的 Cookie）。

### `store:store(req_domain, req_path, req_is_http, req_is_secure, req_site_for_cookies, name, value, params)`

尝试将一个 Cookie 添加到`存储中 `。

- `req_domain` 是获取该 cookie 的域名。
- `req_path` 是获取该 cookie 的请求路径。
- `req_is_http` 是一个布尔标志，用于指示该 cookie 是否来自一个“非 HTTP”API。
- `req_is_secure` 是一个布尔标志，用于指示 cookie 是否通过“安全”协议获取。
- `req_site_for_cookies` 是一个字符串，用于指定应被视为“Cookie 网站”的主机（参见 [RFC 6265bis-02 第 5.2 节 ](https://tools.ietf.org/html/draft-ietf-httpbis-rfc6265bis-02#section-5.2)），如果未知则可以为`空 `。
- `名称`是一个包含 Cookie 名称的字符串。
- `值`是一个字符串，包含 cookie 的值。
- `params` 是一个表，其中键是 Cookie 属性名称，值是 Cookie 属性值。

返回一个布尔值，表示是否存储了 cookie。

### `store:store_from_request(req_headers, resp_headers, req_host, req_site_for_cookies)`

尝试存储响应头中找到的任何 Cookie。

- `req_headers` 是传出请求的 [*http.headers*](https://daurnimator.github.io/lua-http/0.4/#http.headers) 对象。
- `resp_headers` 是响应中接收的 [*http.headers*](https://daurnimator.github.io/lua-http/0.4/#http.headers) 对象。
- `req_host` 是您的查询所指向的主机（仅在 `req_headers` 中缺少 `Host` 头部时使用）
- `req_site_for_cookies` 是一个字符串，用于指定应被视为“Cookie 网站”的主机（参见 [RFC 6265bis-02 第 5.2 节 ](https://tools.ietf.org/html/draft-ietf-httpbis-rfc6265bis-02#section-5.2)），如果未知则可以为`空 `。

### `store:get(domain, path, name)`

返回指定`域名 `、` 路径和 ` ` 名称的 `Cookie 值。

### `store:remove(domain, path, name)`

删除指定`域名 `、` 路径和 ` ` 名称`对应的 Cookie。

如果`名称`为`空`或未传递，则删除该`域名`和`路径`下的所有 Cookie。

如果`路径`为`空`或未传递（除了`名称`之外），则删除该`域`的所有 cookie。

### `store:lookup(domain, path, is_http, is_secure, is_safe_method, site_for_cookies, is_top_level, max_cookie_length)`

查找可被实体访问的 Cookie。

- `域名是`将接收该 cookie 的域名。
- `路径`是将发送 cookie 的路径。
- `is_http` 是一个布尔标志，用于指示目标是否为“非 HTTP”API。
- `is_secure` 是一个布尔标志，用于指示目标是否将通过“安全”协议进行通信。
- `is_safe_method` 是一个布尔标志，用于指示 cookie 是否将通过安全的 HTTP 方法发送（参见 [http.util.is_safe_method](https://daurnimator.github.io/lua-http/0.4/#http.util.is_safe_method)）
- `site_for_cookies` 是一个字符串，用于指定应被视为“Cookie 网站”的主机（参见 [RFC 6265bis-02 第 5.2 节 ](https://tools.ietf.org/html/draft-ietf-httpbis-rfc6265bis-02#section-5.2)），如果未知则可以为`空 `。
- `is_top_level` 是一个布尔标志，用于指示此请求是否为“顶级”请求（参见 [RFC 6265bis-02 第 5.2 节 ](https://tools.ietf.org/html/draft-ietf-httpbis-rfc6265bis-02#section-5.2)）
- `max_cookie_length` 是允许的最大 Cookie 长度（参见 [`store.max_cookie_length`](https://daurnimator.github.io/lua-http/0.4/#http.cookie.store.max_cookie_length)）

返回一个适合用于 `Cookie` 头部的字符串。

### `store:lookup_for_request(headers, host, site_for_cookies, is_top_level, max_cookie_length)`

查找适合添加到请求中的 Cookie。

- `headers` 是用于传出请求的 [*HTTP 头部*](https://daurnimator.github.io/lua-http/0.4/#http.headers)对象 [*。*](https://daurnimator.github.io/lua-http/0.4/#http.headers)
- `主机`是您的查询所指向的主机（仅在`请求头中`缺少 `Host` 头部时使用）
- `site_for_cookies` 是一个字符串，用于指定应被视为“Cookie 网站”的主机（参见 [RFC 6265bis-02 第 5.2 节 ](https://tools.ietf.org/html/draft-ietf-httpbis-rfc6265bis-02#section-5.2)），如果未知则可以为`空 `。
- `is_top_level` 是一个布尔标志，用于指示此请求是否为“顶级”请求（参见 [RFC 6265bis-02 第 5.2 节 ](https://tools.ietf.org/html/draft-ietf-httpbis-rfc6265bis-02#section-5.2)）
- `max_cookie_length` 是允许的最大 Cookie 长度（参见 [`store.max_cookie_length`](https://daurnimator.github.io/lua-http/0.4/#http.cookie.store.max_cookie_length)）

返回一个适合用于 `Cookie` 头部的字符串。

### `store:clean_due()`

返回`存储中`下一个 cookie 过期前剩余的秒数。

### `store:clean()`

从`存储`中删除所有过期的 Cookie。

### `store:load_from_file(file)`

从文件对象 `file` 中加载 cookie 数据并存储到`存储中 `。文件应采用 Netscape Cookiejar 格式。文件中的无效行将被忽略。

如果操作成功，返回 `true`；否则，如果 `:read` 调用失败，则返回 `nil、err 或 errno`。

### `store:save_to_file(file)`

将`存储中的 `Cookie 数据以 Netscape Cookiejar 格式写入文件对象 `file` 中。在写入前 `，file` 不会被`定位`或截断。

如果操作成功，返回 `true`；否则，如果 `:write` 调用失败，则返回 `nil、err 或 errno`。

## http.h1_connection

*h1_connection* 模块遵循[*连接接口* ](https://daurnimator.github.io/lua-http/0.4/#connection)，并提供 HTTP 1.0 和 1.1 协议的特定操作。

### `new(socket, conn_type, version)`

新建连接的构造函数。接受一个 cqueues 套接字对象、一个[连接类型字符串和](https://daurnimator.github.io/lua-http/0.4/#connection.type)一个数字 HTTP 版本号。连接类型的有效值为 `"client"` 和 `"server"`。版本号的有效值为 `1` 和 `1.1`。返回新初始化的连接对象。

### `h1_connection.version`

指定用于连接握手过程的 HTTP 版本。有效值为：

- `1.0`
- `1.1`

查看[`连接版本。`](https://daurnimator.github.io/lua-http/0.4/#connection.version)

### `h1_connection:pollfd()`

参见 [`：pollfd()`](https://daurnimator.github.io/lua-http/0.4/#connection:pollfd)

### `h1_connection:events()`

查看[`连接：events()`](https://daurnimator.github.io/lua-http/0.4/#connection:events)

### `h1_connection:timeout()`

查看[`连接超时()`](https://daurnimator.github.io/lua-http/0.4/#connection:timeout)

### `h1_connection:connect(timeout)`

查看[`连接：connect(超时)`](https://daurnimator.github.io/lua-http/0.4/#connection:connect)

### `h1_connection:checktls()`

查看[`连接：checktls()`](https://daurnimator.github.io/lua-http/0.4/#connection:checktls)

### `h1_connection:localname()`

[`查看连接：localname()`](https://daurnimator.github.io/lua-http/0.4/#connection:localname)

### `h1_connection:peername()`

查看[`连接：peername()`](https://daurnimator.github.io/lua-http/0.4/#connection:peername)

### `h1_connection:flush(timeout)`

查看[`连接：刷新（超时）`](https://daurnimator.github.io/lua-http/0.4/#connection:flush)

### `h1_connection:shutdown(dir)`

关闭操作尽可能优雅：[ 首先关闭管道](https://daurnimator.github.io/lua-http/0.4/#http.h1_stream:shutdown)流，然后根据实际情况关闭底层套接字。

`dir` 是一个字符串，表示要关闭通信的方向。如果它包含 `"r"`，则关闭读取，如果它包含 `"w"`，则关闭写入。默认值为 `"rw"`，即关闭双向通信。

查看[`连接：关闭()`](https://daurnimator.github.io/lua-http/0.4/#connection:shutdown)

### `h1_connection:close()`

查看[`连接：关闭()`](https://daurnimator.github.io/lua-http/0.4/#connection:close)

### `h1_connection:new_stream()`

在 HTTP 1 中，仅客户端可通过此函数发起新的流。

有关详细信息，请参阅 [`connection:new_stream()`](https://daurnimator.github.io/lua-http/0.4/#connection:new_stream)。

### `h1_connection:get_next_incoming_stream(timeout)`

参见[ `connection:get_next_incoming_stream(timeout)`](https://daurnimator.github.io/lua-http/0.4/#connection:get_next_incoming_stream)

### `h1_connection:onidle(new_handler)`

参见[ `connection:onidle(new_handler)`](https://daurnimator.github.io/lua-http/0.4/#connection:onidle)

### `h1_connection:setmaxline(read_length)`

设置最大读取缓冲区大小（以字节为单位）为 `read_length`。即设置最大行长度（如标题行）。

默认值来自底层套接字，该套接字在构造时获取可变的 cqueues 默认值。默认的 cqueues 默认值为 4096 字节。

### `h1_connection:clearerr(...)`

清除错误以允许在连接上继续进行读取或写入操作。返回现有错误的错误编号。此函数用于从已知错误中恢复。

### `h1_connection:error(...)`

返回现有错误的错误编号。

### `h1_connection:take_socket()`

用于将连接套接字的引用传递给另一个对象。将套接字重置为默认设置，并返回调用该函数的例程中存在的唯一套接字引用。此函数可用于连接升级，例如从 HTTP 1 升级到 WebSocket。

### `h1_connection:read_request_line(timeout)`

从套接字读取一条请求行。返回传入请求的请求方法、请求目标和 HTTP 版本。`:read_request_line()` 持续执行直至接收到`以 "\r\n"` 结尾的块，或`超时 `。如果传入的块不是有效的 HTTP 请求行，则返回 `nil`。发生错误时，返回 `nil`、错误消息和错误编号。

### `h1_connection:read_status_line(timeout)`

从套接字读取一行输入。如果输入是一行有效的状态行，则返回 HTTP 版本（1 或 1.1）、状态码和原因描述（如果适用）。`:read_status_line()` 持续执行直到接收到`以 "\r\n"` 结尾的块，或`超时 `。如果无法读取套接字，则返回 `nil`、错误消息和错误编号。

### `h1_connection:read_header(timeout)`

从套接字中读取以 CRLF 结尾的 HTTP 头部，并返回头部键和值。该函数将阻塞直到接收到符合 MIME 规范的头部项或`超时 `。如果无法读取头部，函数将返回`空值 `、一个错误和错误消息。

### `h1_connection:read_headers_done(timeout)`

检查是否存在空行，这表示 HTTP 头部的结束。如果接收到空行，则返回 `true`。任何其他值都会被推回套接字接收缓冲区（取消获取），并返回 `false`。该函数会阻塞等待套接字输入或直到`超时 `。如果无法读取套接字，则返回 `nil`、一个错误和错误消息。

### `h1_connection:read_body_by_length(len, timeout)`

从套接字中获取`指定长度的`字节数。若使用负数 *，则从指定位置开始读取指定长度的字节* 。 *若*缓冲区中的数据长度小于`指定长度 `，该函数将阻塞并等待套接字就绪。若 `len` 不是数字，则引发异常。

### `h1_connection:read_body_till_close(timeout)`

读取整个请求主体。该函数将阻塞直到主体读取完成或`超时 `。如果读取失败，函数将返回 `nil`、错误消息和错误编号。

### `h1_connection:read_body_chunk(timeout)`

从请求中读取下一条可用的数据行，并返回数据块及其扩展部分。该函数会阻塞执行，直到接收到指定大小的数据块或`超时 `。如果指定的数据块大小为 `0，` 则`返回 false` 并返回任何数据块扩展部分。如果在读取数据块头或套接字时发生错误，则返回 `nil`、错误消息和错误代码。

### `h1_connection:write_request_line(method, target, httpversion, timeout)`

将新请求的 HTTP 1.x 请求首行写入套接字缓冲区。等待直到成功或`超时 `。如果写入失败，返回 `nil`、错误消息和错误编号。

*请注意，请求行不会**在调用* [```](https://daurnimator.github.io/lua-http/0.4/#http.h1_connection:write_headers_done)*write_headers_done*[```](https://daurnimator.github.io/lua-http/0.4/#http.h1_connection:write_headers_done) *之前发送到远程服务器* *。*

### `h1_connection:write_status_line(httpversion, status_code, reason_phrase, timeout)`

将一个 HTTP 状态行写入套接字缓冲区。等待直到成功或`超时 `。如果写入失败，函数返回 `nil`、一个错误消息和一个错误编号。

*请注意，状态行不会**在调用 write_headers_done 之前**发送到远程服务器* *。*

### `h1_connection:write_header(k, v, timeout)`

将一个`键值对`写入套接字缓冲区。等待写入成功或`超时 `。如果写入失败，返回 `nil`、错误消息和错误。

*请注意，标题项不会**在调用 write_headers_done 之前**发送到远程服务器* *。*

### `h1_connection:write_headers_done(timeout)`

通过向套接字写入空行（`"\r\n"`）来终止一个头部块。此函数将清空套接字输出缓冲区中的所有待写数据。阻塞直到成功或`超时 `。返回 `nil`，错误消息和错误，如果写入失败。

### `h1_connection:write_body_chunk(chunk, chunk_ext, timeout)`

将一组数据写入套接字。`chunk_ext` 必须为 `nil`，因为不支持数据块扩展。将阻塞直到`写入`完成或`超时 `。成功时返回 true。如果写入失败，返回 `nil`、错误消息和错误编号。

### `h1_connection:write_body_last_chunk(chunk_ext, timeout)`

将分块主体终止符 `"0\r\n"` 写入套接字。`chunk_ext` 必须为 `nil`，因为不支持分块扩展。将阻塞直到`操作`完成或`超时 `。如果写入失败，返回 `nil`、错误消息和错误编号。

*请注意，连接不会立即被清除到远程服务器；通常，这将在写入尾部数据时发生。*

### `h1_connection:write_body_plain(body, timeout)`

`将主体`内容写入套接字并立即刷新套接字输出缓冲区。阻塞直到操作成功或`超时 `。如果写入失败，返回 `nil`、错误消息和错误编号。

## http.h1_reason_phrases

一个将状态码（字符串形式）映射到 HTTP 状态码对应的描述性短语的映射表。任何未知的状态码将返回 `“未分配”。`

### 示例

```
local reason_phrases = require "http.h1_reason_phrases"
print(reason_phrases["200"]) --> "OK"
print(reason_phrases["342"]) --> "Unassigned"
```

## http.h1_stream

*h1_stream* 模块遵循[*流*](https://daurnimator.github.io/lua-http/0.4/#stream)接口规范，并提供 HTTP 1.x 特定的操作。

gzip 压缩传输编码被透明支持。

### `h1_stream.connection`

查看[`流连接。`](https://daurnimator.github.io/lua-http/0.4/#stream.connection)

### `h1_stream.max_header_lines`

要读取的标题行最大数量。默认值为 `100`。

### `h1_stream:checktls()`

查看[`流：checktls()`](https://daurnimator.github.io/lua-http/0.4/#stream:checktls)

### `h1_stream:localname()`

[`查看流：localname()`](https://daurnimator.github.io/lua-http/0.4/#stream:localname)

### `h1_stream:peername()`

查看[`流：peername()`](https://daurnimator.github.io/lua-http/0.4/#stream:peername)

### `h1_stream:get_headers(timeout)`

查看[`流：获取头部信息（超时）`](https://daurnimator.github.io/lua-http/0.4/#stream:get_headers)

### `h1_stream:write_headers(headers, end_stream, timeout)`

参见[ `stream:write_headers(headers, end_stream, timeout)`](https://daurnimator.github.io/lua-http/0.4/#stream:write_headers)

### `h1_stream:write_continue(timeout)`

参见[ `stream:write_continue(timeout)`](https://daurnimator.github.io/lua-http/0.4/#stream:write_continue)

### `h1_stream:get_next_chunk(timeout)`

参见[ `stream:get_next_chunk(timeout)`](https://daurnimator.github.io/lua-http/0.4/#stream:get_next_chunk)

### `h1_stream:each_chunk()`

[`查看流：each_chunk()`](https://daurnimator.github.io/lua-http/0.4/#stream:each_chunk)

### `h1_stream:get_body_as_string(timeout)`

参见[ `stream:get_body_as_string(timeout)`](https://daurnimator.github.io/lua-http/0.4/#stream:get_body_as_string)

### `h1_stream:get_body_chars(n, timeout)`

参见[ `stream:get_body_chars(n, timeout)`](https://daurnimator.github.io/lua-http/0.4/#stream:get_body_chars)

### `h1_stream:get_body_until(pattern, plain, include_pattern, timeout)`

参见[ `stream:get_body_until(pattern, plain, include_pattern, timeout)`](https://daurnimator.github.io/lua-http/0.4/#stream:get_body_until)

### `h1_stream:save_body_to_file(file, timeout)`

参见[ `stream:save_body_to_file(file, timeout)`](https://daurnimator.github.io/lua-http/0.4/#stream:save_body_to_file)

### `h1_stream:get_body_as_file(timeout)`

参见[ `stream:get_body_as_file(timeout)`](https://daurnimator.github.io/lua-http/0.4/#stream:get_body_as_file)

### `h1_stream:unget(str)`

[`查看流：unget(str)`](https://daurnimator.github.io/lua-http/0.4/#stream:unget)

### `h1_stream:write_chunk(chunk, end_stream, timeout)`

参见[ `stream:write_chunk(chunk, end_stream, timeout)`](https://daurnimator.github.io/lua-http/0.4/#stream:write_chunk)

### `h1_stream:write_body_from_string(str, timeout)`

参见[ `stream:write_body_from_string(str, timeout)`](https://daurnimator.github.io/lua-http/0.4/#stream:write_body_from_string)

### `h1_stream:write_body_from_file(options|file, timeout)`

参见[ `stream:write_body_from_file(options|file, timeout)`](https://daurnimator.github.io/lua-http/0.4/#stream:write_body_from_file)

### `h1_stream:shutdown()`

查看[`流：关闭()`](https://daurnimator.github.io/lua-http/0.4/#stream:shutdown)

### `h1_stream:set_state(new)`

将流的状态设置为`新状态 `。`new` 必须是以下有效状态之一：

- `"打开"`: 已发送或接收了头部信息；尚未发送正文内容。
- `“半关闭（本地）”`：已发送整个身体
- `“半闭合（远程）”`：已接收全身
- `"关闭"`: 完成

并非所有状态转换都是允许的。

### `h1_stream:read_headers(timeout)`

从底层连接中读取并返回一个[头部块 ](https://daurnimator.github.io/lua-http/0.4/#http.headers)。 *不*考虑缓冲的头部块。发生错误时，返回 `nil`、错误消息和错误编号。

此功能应尽量避免使用，您可能需要的是 [`：get_headers()`](https://daurnimator.github.io/lua-http/0.4/#http.h1_stream:get_headers)。

### `h1_stream:read_next_chunk(timeout)`

从底层连接中读取并返回下一个数据块作为字符串。 *不考虑*缓冲区中的数据块。发生错误时，返回 `nil`、错误消息和错误编号。

此功能应尽量避免使用，您可能需要的是 [`：get_next_chunk()`](https://daurnimator.github.io/lua-http/0.4/#http.h1_stream:get_next_chunk)。

## http.h2_connection

*h2_connection* 模块遵循[*连接接口* ](https://daurnimator.github.io/lua-http/0.4/#connection)，并提供 HTTP 2 特定的操作。一个 HTTP 2 连接可以同时有多个流在传输数据，因此 *http.h2_connection* 模块的作用类似于一个调度器。

### `new(socket, conn_type, settings)`

新建连接的构造函数。接受一个 cqueues 套接字对象、一个[连接类型字符串以及](https://daurnimator.github.io/lua-http/0.4/#connection.type)一个可选的 HTTP 2 设置表。返回一个初始化完成但未连接的连接对象。

### `h2_connection.version`

包含 HTTP 连接版本。目前该值始终为 `2`。

查看[`连接版本。`](https://daurnimator.github.io/lua-http/0.4/#connection.version)

### `h2_connection:pollfd()`

参见 [`：pollfd()`](https://daurnimator.github.io/lua-http/0.4/#connection:pollfd)

### `h2_connection:events()`

查看[`连接：events()`](https://daurnimator.github.io/lua-http/0.4/#connection:events)

### `h2_connection:timeout()`

查看[`连接超时()`](https://daurnimator.github.io/lua-http/0.4/#connection:timeout)

### `h2_connection:empty()`

### `h2_connection:step(timeout)`

### `h2_connection:loop(timeout)`

### `h2_connection:connect(timeout)`

查看[`连接：connect(超时)`](https://daurnimator.github.io/lua-http/0.4/#connection:connect)

### `h2_connection:checktls()`

查看[`连接：checktls()`](https://daurnimator.github.io/lua-http/0.4/#connection:checktls)

### `h2_connection:localname()`

[`查看连接：localname()`](https://daurnimator.github.io/lua-http/0.4/#connection:localname)

### `h2_connection:peername()`

查看[`连接：peername()`](https://daurnimator.github.io/lua-http/0.4/#connection:peername)

### `h2_connection:flush(timeout)`

查看[`连接：刷新（超时）`](https://daurnimator.github.io/lua-http/0.4/#connection:flush)

### `h2_connection:shutdown()`

查看[`连接：关闭()`](https://daurnimator.github.io/lua-http/0.4/#connection:shutdown)

### `h2_connection:close()`

查看[`连接：关闭()`](https://daurnimator.github.io/lua-http/0.4/#connection:close)

### `h2_connection:new_stream(id)`

创建并返回一个新的 [*h2_stream 对象* ](https://daurnimator.github.io/lua-http/0.4/#http.h2_stream)。`id`（可选）是用于为新流分配的流标识符。如果客户端发起流时未指定 id，则系统将自动分配下一个可用奇数编号的流；如果服务器发起流时未指定 id，则系统将自动分配下一个可用偶数编号的流。

有关详细信息，请参阅 [`connection:new_stream()`](https://daurnimator.github.io/lua-http/0.4/#connection:new_stream)。

### `h2_connection:get_next_incoming_stream(timeout)`

参见[ `connection:get_next_incoming_stream(timeout)`](https://daurnimator.github.io/lua-http/0.4/#connection:get_next_incoming_stream)

### `h2_connection:onidle(new_handler)`

参见[ `connection:onidle(new_handler)`](https://daurnimator.github.io/lua-http/0.4/#connection:onidle)

### `h2_connection:read_http2_frame(timeout)`

### `h2_connection:write_http2_frame(typ, flags, streamid, payload, timeout, flush)`

### `h2_connection:ping(timeout)`

### `h2_connection:write_window_update(inc, timeout)`

### `h2_connection:write_goaway_frame(last_stream_id, err_code, debug_msg, timeout)`

### `h2_connection:set_peer_settings(peer_settings)`

### `h2_connection:ack_settings()`

### `h2_connection:settings(tbl, timeout)`

## http.h2_error

一种封装 HTTP 2 错误信息的错误对象。`http.h2_error` 对象包含以下字段：

- `名称 `：错误名称：此错误的简短标识符
- `代码 `：错误代码
- 错误代码的`描述`
- `消息 `：错误信息
- `跟踪信息 `：在错误抛出时捕获的跟踪信息。
- `流错误 `：一个布尔值，用于指示此错误是流级别还是协议级别错误。

### `errors`

一个包含[根据 HTTP 2 规范定义的](https://http2.github.io/http2-spec/#iana-errors)错误的表格。该表格可通过错误名称（例如&nbsp;`errors.PROTOCOL_ERROR`）或数字代码（例如&nbsp;`errors[0x1]`）进行索引。

### `is(ob)`

返回一个布尔值，表示对象 `ob` 是否为 `http.h2_error` 对象。

### `h2_error:new(ob)`

从传入的表中创建一个新的错误对象。该表应具有错误对象的格式，即包含字段`名称 `、` 代码 `、` 消息 `、` 堆栈跟踪等 `。

字段`名称 `、` 代码`和`描述`在未指定时将从父级 `h2_error` 对象继承。

`stream_error 的`默认值为 `false`。

### `h2_error:new_traceback(message, stream_error, lvl)`

创建一个新的错误对象，记录当前线程的调用堆栈。

### `h2_error:error(message, stream_error, lvl)`

创建并抛出一个新的错误。

### `h2_error:assert(cond, ...)`

如果 `cond` 为真，则返回 `cond，...`

如果 `cond` 为假值（即 `false` 或 `nil`），则抛出一个错误，并将 `...` 的第一个元素作为错误`消息 `。

## http.h2_stream

h2_stream 表示一个 HTTP 2 流。该模块遵循[*流*](https://daurnimator.github.io/lua-http/0.4/#stream)接口以及 HTTP 2 特定功能。

### `h2_stream.connection`

查看[`流连接。`](https://daurnimator.github.io/lua-http/0.4/#stream.connection)

### `h2_stream:checktls()`

查看[`流：checktls()`](https://daurnimator.github.io/lua-http/0.4/#stream:checktls)

### `h2_stream:localname()`

[`查看流：localname()`](https://daurnimator.github.io/lua-http/0.4/#stream:localname)

### `h2_stream:peername()`

查看[`流：peername()`](https://daurnimator.github.io/lua-http/0.4/#stream:peername)

### `h2_stream:get_headers(timeout)`

查看[`流：获取头部信息（超时）`](https://daurnimator.github.io/lua-http/0.4/#stream:get_headers)

### `h2_stream:write_headers(headers, end_stream, timeout)`

参见[ `stream:write_headers(headers, end_stream, timeout)`](https://daurnimator.github.io/lua-http/0.4/#stream:write_headers)

### `h2_stream:write_continue(timeout)`

参见[ `stream:write_continue(timeout)`](https://daurnimator.github.io/lua-http/0.4/#stream:write_continue)

### `h2_stream:get_next_chunk(timeout)`

参见[ `stream:get_next_chunk(timeout)`](https://daurnimator.github.io/lua-http/0.4/#stream:get_next_chunk)

### `h2_stream:each_chunk()`

[`查看流：each_chunk()`](https://daurnimator.github.io/lua-http/0.4/#stream:each_chunk)

### `h2_stream:get_body_as_string(timeout)`

参见[ `stream:get_body_as_string(timeout)`](https://daurnimator.github.io/lua-http/0.4/#stream:get_body_as_string)

### `h2_stream:get_body_chars(n, timeout)`

参见[ `stream:get_body_chars(n, timeout)`](https://daurnimator.github.io/lua-http/0.4/#stream:get_body_chars)

### `h2_stream:get_body_until(pattern, plain, include_pattern, timeout)`

参见[ `stream:get_body_until(pattern, plain, include_pattern, timeout)`](https://daurnimator.github.io/lua-http/0.4/#stream:get_body_until)

### `h2_stream:save_body_to_file(file, timeout)`

参见[ `stream:save_body_to_file(file, timeout)`](https://daurnimator.github.io/lua-http/0.4/#stream:save_body_to_file)

### `h2_stream:get_body_as_file(timeout)`

参见[ `stream:get_body_as_file(timeout)`](https://daurnimator.github.io/lua-http/0.4/#stream:get_body_as_file)

### `h2_stream:unget(str)`

[`查看流：unget(str)`](https://daurnimator.github.io/lua-http/0.4/#stream:unget)

### `h2_stream:write_chunk(chunk, end_stream, timeout)`

参见[ `stream:write_chunk(chunk, end_stream, timeout)`](https://daurnimator.github.io/lua-http/0.4/#stream:write_chunk)

### `h2_stream:write_body_from_string(str, timeout)`

参见[ `stream:write_body_from_string(str, timeout)`](https://daurnimator.github.io/lua-http/0.4/#stream:write_body_from_string)

### `h2_stream:write_body_from_file(options|file, timeout)`

参见[ `stream:write_body_from_file(options|file, timeout)`](https://daurnimator.github.io/lua-http/0.4/#stream:write_body_from_file)

### `h2_stream:shutdown()`

查看[`流：关闭()`](https://daurnimator.github.io/lua-http/0.4/#stream:shutdown)

### `h2_stream:pick_id(id)`

### `h2_stream:set_state(new)`

### `h2_stream:reprioritise(child, exclusive)`

### `h2_stream:write_http2_frame(typ, flags, payload, timeout, flush)`

使用 `h2_stream 的`流标识符写入一个帧。

参见[ `h2_connection:write_http2_frame(typ, flags, streamid, payload, timeout, flush)`](https://daurnimator.github.io/lua-http/0.4/#http.h2_connection:write_http2_frame)

### `h2_stream:write_data_frame(payload, end_stream, padded, timeout, flush)`

### `h2_stream:write_headers_frame(payload, end_stream, end_headers, padded, exclusive, stream_dep, weight, timeout, flush)`

### `h2_stream:write_priority_frame(exclusive, stream_dep, weight, timeout, flush)`

### `h2_stream:write_rst_stream_frame(err_code, timeout, flush)`

### `h2_stream:rst_stream(err, timeout)`

### `h2_stream:write_settings_frame(ACK, settings, timeout, flush)`

### `h2_stream:write_push_promise_frame(promised_stream_id, payload, end_headers, padded, timeout, flush)`

### `h2_stream:push_promise(headers, timeout)`

向客户端发送一个新的承诺。

返回新的流作为 [h2_stream](https://daurnimator.github.io/lua-http/0.4/#http.h2_stream)。

### `h2_stream:write_ping_frame(ACK, payload, timeout, flush)`

### `h2_stream:write_goaway_frame(last_streamid, err_code, debug_msg, timeout, flush)`

### `h2_stream:write_window_update_frame(inc, timeout, flush)`

### `h2_stream:write_window_update(inc, timeout)`

### `h2_stream:write_continuation_frame(payload, end_headers, timeout, flush)`

## http.headers

有序的标头字段列表。每个字段包含一个*名称* 、一个*值*以及一个 *never_index* 标志，用于指示该标头字段是否可能包含敏感数据。

每个头部对象都通过字段名进行索引，以便高效地根据键值检索值。请注意，给定的字段名可能对应多个值。（例如，一个 HTTP 服务器可能发送两个 `Set-Cookie` 头部。）

如[协议部分](https://daurnimator.github.io/lua-http/0.4/#conventions)所述，HTTP 1 请求和状态行字段在 HTTP 2 中被封装在头部对象中，分别存储在键 `":authority"`、`":method"`、`":path"`、`":scheme"` 和 `":status"` 下。因此，这些字段均以字符串形式保存（特别需要注意 `":status"` 字段）。

### `new()`

创建并返回一个新的头部对象。

### `headers:len()`

返回头部的数量。

在 Lua 5.2 及更高版本中，也可作为 `#headers` 使用。

### `headers:clone()`

创建并返回头部对象的副本。

### `headers:append(name, value, never_index)`

添加一个标题。

- `名称`是标头字段的名称。小写是约定格式。当前不会对该字段进行验证。
- `值`是标头字段的值。当前不会对该值进行验证。
- `never_index` 是一个可选的布尔值，用于指示该`值`是否应被视为机密。对于以下标头字段，默认值为 true：authorization、proxy-authorization、cookie 和 set-cookie。

### `headers:each()`

一个遍历所有头文件的迭代器，该迭代器会输出`名称、值和 never_index`。

#### 示例

```
local http_headers = require "http.headers"
local myheaders = http_headers.new()
myheaders:append(":status", "200")
myheaders:append("set-cookie", "foo=bar")
myheaders:append("connection", "close")
myheaders:append("set-cookie", "baz=qux")
for name, value, never_index in myheaders:each() do
    print(name, value, never_index)
end
--[[ prints:
":status", "200", false
"set-cookie", "foo=bar", true
"connection", "close", false
"set-cookie", "baz=qux", true
]]
```

### `headers:has(name)`

返回一个布尔值，表示头部对象中是否存在`名称`与给定`名称`相同的字段。

### `headers:delete(name)`

从头部对象中删除所有字段名的实例。

### `headers:geti(i)`

返回`第 i` 个头部，作为`名称、值和 never_index`。

### `headers:get_as_sequence(name)`

返回所有具有指定名称的头部信息，并以表格形式呈现。该表格将包含一个`名为 .n 的`字段，用于表示元素的数量。

#### 示例

```
local http_headers = require "http.headers"
local myheaders = http_headers.new()
myheaders:append(":status", "200")
myheaders:append("set-cookie", "foo=bar")
myheaders:append("connection", "close")
myheaders:append("set-cookie", "baz=qux")
local mysequence = myheaders:get_as_sequence("set-cookie")
--[[ mysequence will be:
{n = 2; "foo=bar"; "baz=qux"}
]]
```

### `headers:get(name)`

返回所有名称为指定名称的头部信息，并以多个返回值的形式返回。

### `headers:get_comma_separated(name)`

返回所有名称为指定名称的头部，以逗号分隔的字符串形式返回。

### `headers:modifyi(i, value, never_index)`

将`第 i 个元素`的标题更改为新`值`并设置为 `never_index`。

### `headers:upsert(name, value, never_index)`

如果已存在`名称相同的`头部，则替换它。如果不存在，[` 则将其追加到`](https://daurnimator.github.io/lua-http/0.4/#http.headers:append)头部列表中。

当一个标题`名称`已经有多个值时，无法使用。

### `headers:sort()`

按字段名称对标题列表进行排序，优先排序以`冒号（:）` 开头的标题。如果`名称`相同，则按`值`排序，然后按 `never_index` 排序。

### `headers:dump(file, prefix)`

将标题列表打印到指定文件中，每行一个标题。如果未指定`文件 `，则打印到`标准错误输出（stderr）`。每个标题行前会添加`指定的前缀 `。

## http.hpack

### `new(SETTINGS_HEADER_TABLE_SIZE)`

### `hpack_context:append_data(val)`

### `hpack_context:render_data()`

### `hpack_context:clear_data()`

### `hpack_context:evict_from_dynamic_table()`

### `hpack_context:dynamic_table_tostring()`

### `hpack_context:set_max_dynamic_table_size(SETTINGS_HEADER_TABLE_SIZE)`

### `hpack_context:encode_max_size(val)`

### `hpack_context:resize_dynamic_table(new_size)`

### `hpack_context:add_to_dynamic_table(name, value, k)`

### `hpack_context:dynamic_table_id_to_index(id)`

### `hpack_context:lookup_pair_index(k)`

### `hpack_context:lookup_name_index(name)`

### `hpack_context:lookup_index(index)`

### `hpack_context:add_header_indexed(name, value, huffman)`

### `hpack_context:add_header_never_indexed(name, value, huffman)`

### `hpack_context:encode_headers(headers)`

### `hpack_context:decode_headers(payload, header_list, pos)`

## http.hsts

适用于 HSTS（HTTP 严格传输安全）的数据结构

### `new_store()`

创建并返回一个新的 HSTS 存储。

### `hsts_store.max_items`

商店中允许的最大商品数量。减少此值仅会阻止新商品被添加，不会删除现有商品。

默认值为无穷大（允许任意数量的项目）。

### `hsts_store:clone()`

创建并返回一个存储的副本。

### `hsts_store:store(host, directives)`

向存储中添加关于指定`主机的`新的指令。` 指令`应为一个指令表，该表*必须*包含键值`对“max-age”`。

返回一个布尔值，表示该项是否被接受。

### `hsts_store:remove(host)`

从存储中删除`主机的`条目（如果存在）。

### `hsts_store:check(host)`

返回一个布尔值，表示给定`主机`是否为已知的 HSTS 主机。

### `hsts_store:clean_due()`

返回存储中下一个项目过期前剩余的秒数。

### `hsts_store:clean()`

从商店中删除过期的条目。

## http.proxies

### `new()`

返回一个空的‘proxies’对象

### `proxies:update(getenv)`

`getenv` 默认调用 [`os.getenv`](http://www.lua.org/manual/5.3/manual.html#pdf-os.getenv)

读取用于控制请求是否通过代理的環境變數。

- `http_proxy`（或在设置了 `GATEWAY_INTERFACE` 的程序中使用 `CGI_HTTP_PROXY`）：用于正常 HTTP 连接的代理服务器。
- `https_proxy` 或 `HTTPS_PROXY`：用于 HTTPS 连接的代理服务器。
- `all_proxy` 或 `ALL_PROXY`：用于**所有**连接的代理，可被其他选项覆盖。
- `no_proxy` 或 `NO_PROXY`： **不使用**代理的主机列表

返回`代理 `。

### `proxies:choose(scheme, host)`

返回用于指定`方案`和`主机的`代理，以 URI 格式返回。

## http.request

http.request 模块封装了从服务器获取 HTTP 文档所需的所有功能。

### `new_from_uri(uri)`

根据给定的 URI 创建一个新的 `http.request` 对象。

### `new_connect(uri, connect_authority)`

根据给定的 URI 创建一个新的 `http.request` 对象，该对象将执行一个 *CONNECT* 请求。

### `request.host`

此请求应发送至的宿主。

### `request.port`

此请求应发送到的端口。

### `request.bind`

本地发送地址，可选绑定端口，格式`为“地址[:端口]”`。默认情况下，允许内核自动选择地址和端口。

IPv6 地址可通过方括号表示法指定。例如：`"127.0.0.1"`、`"127.0.0.1:50000"`、`"[::1]:30000"`。

此选项通常无需使用。提供地址可用于手动选择用于发送请求的网络接口，而提供端口仅在与防火墙或要求使用特定端口的设备进行互操作时才真正需要。

### `request.tls`

一个布尔值，用于指示是否应使用 TLS。

### `request.ctx`

用于替代的 `SSL_CTX* 设置 `。如果未指定，则使用默认的 TLS 设置（请参阅 [*http.tls*](https://daurnimator.github.io/lua-http/0.4/#http.tls) 获取详细信息）。

### `request.sendname`

TLS SNI 主机名。

### `request.version`

要使用的 HTTP 版本；` 留空`以自动选择。

### `request.proxy`

指定请求将通过的代理。该值应为一个 URI 或 `false` 以关闭该请求的代理功能。

### `request.headers`

一个包含将在请求中发送的头部信息的 [*http.headers*](https://daurnimator.github.io/lua-http/0.4/#http.headers) 对象。

### `request.hsts`

用于强制执行 HTTP 严格传输安全性的 [*http.hsts*](https://daurnimator.github.io/lua-http/0.4/#http.hsts) 存储。将尝试将响应中包含的严格传输头添加到该存储中。

默认使用共享存储。

### `request.proxies`

用于选择请求代理的 [*http.proxies*](https://daurnimator.github.io/lua-http/0.4/#http.proxies) 对象。仅在 `request.proxy` 为 `nil` 时被查询。

### `request.cookie_store`

用于查找请求中 cookie 的 [*http.cookie.store*](https://daurnimator.github.io/lua-http/0.4/#http.cookie.store)。系统将尝试将响应中包含的 cookie 添加到该存储中。

默认使用共享存储。

### `request.is_top_level`

一个布尔标志，用于指示此请求是否为“顶级”请求（参见 [RFC 6265bis-02 第 5.2 节 ](https://tools.ietf.org/html/draft-ietf-httpbis-rfc6265bis-02#section-5.2)）

默认值为 `true`

### `request.site_for_cookies`

包含应被视为“Cookie 站点”的主机的字符串（参见 [RFC 6265bis-02 第 5.2 节 ](https://tools.ietf.org/html/draft-ietf-httpbis-rfc6265bis-02#section-5.2)），如果未知，可以为`空 `。

默认值为`空 `。

### `request.follow_redirects`

布尔值，用于指示是否应跟随重定向执行 `:go()` 操作。默认值为 `true`。

### `request.expect_100_timeout`

在发送请求正文之前，等待收到 100 Continue 响应的秒数。默认值为 `1`。

### `request.max_redirects`

在放弃之前跟随的最大重定向次数。默认值为 `5`。设置为 `math.huge 以`不放弃。

### `request.post301`

遵守 RFC 2616 第 10.3.2 节，在跟随 301 重定向时**不要将** POST 请求转换为无正文的 GET 请求。非 RFC 行为在网页浏览器中普遍存在，且被服务器默认接受。现代 HTTP 端点会发送状态码 308 以指示不希望更改请求方法。默认值为 `false`。

### `request.post302`

遵守 RFC 2616 第 10.3.3 节，在跟随 302 重定向时**不要将** POST 请求转换为无正文的 GET 请求。非 RFC 行为在网页浏览器中普遍存在，且被服务器默认接受。现代 HTTP 端点会发送状态码 307 以指示不希望更改请求方法。默认值为 `false`。

### `request:clone()`

创建并返回请求的副本。

克隆对象拥有其自身对 [`.headers 和 `](https://daurnimator.github.io/lua-http/0.4/#http.request.headers) [`.h2_settings`](https://daurnimator.github.io/lua-http/0.4/#http.request.h2_settings) 字段的深度副本。

[`.tls`](https://daurnimator.github.io/lua-http/0.4/#http.request.tls) 和 [`.body`](https://daurnimator.github.io/lua-http/0.4/#http.request.body) 字段是从原始请求中浅拷贝过来的。

### `request:handle_redirect(headers)`

处理重定向。

响应`头`应为重定向的响应头。

返回一个新的`请求`对象，该对象将从新位置获取数据。

### `request:to_uri(with_userinfo)`

返回请求的 URI。

如果 `with_userinfo` 为 `true` 且请求包含`授权头 `（或 CONNECT 请求中的`代理授权头 `），返回的 URI 将包含用户信息组件。

### `request:set_body(body)`

允许设置请求主体。` 主体`可以是字符串、函数或 Lua 文件对象。

- 如果`主体内容`为字符串，则将原样发送。
- 如果`身体`是一个函数，它将像迭代器一样被反复调用。它应返回请求主体的分块作为字符串，或在完成时返回 `nil`。
- 如果 `body` 是 Lua 文件对象，则会将其[`定位到`](http://www.lua.org/manual/5.3/manual.html#pdf-file:seek)文件开头 [`，`](http://www.lua.org/manual/5.3/manual.html#pdf-file:seek) 然后作为主体发送。文件操作过程中遇到的任何错误**都会被抛出** 。

### `request:go(timeout)`

执行请求。

请求对象**未被**无效化，可用于新的请求。成功时，返回[*响应头部和*](https://daurnimator.github.io/lua-http/0.4/#http.headers)一个[*流* ](https://daurnimator.github.io/lua-http/0.4/#stream)。

## http.server

*http.server* 对象用于封装 HTTP 客户端的 `accept()` 和 dispatch 操作。每个新的客户端请求都会在由 cqueues 管理的新协程中调用 `onstream` 回调函数。除了构建并返回 HTTP 响应外 `，onstream` 处理程序还可能决定将连接的所有权转移给其他用途，例如将 HTTP 1.1 连接升级为 WebSocket 连接。

有关如何使用服务器库的示例，请参阅源代码树中的[示例目录 ](https://github.com/daurnimator/lua-http/tree/master/examples)。

### `new(options)`

创建一个新的 HTTP 服务器实例，监听指定的套接字。

- `.socket`(*cqueues.socket*)：接受调用 `accept()` 的套接字。
- `.onerror`（ *函数* ）：当发生错误时调用的函数（默认处理程序会抛出错误）。参见 [server:onerror()](https://daurnimator.github.io/lua-http/0.4/#http.server:onerror)
- `.onstream`( *函数* )：用于处理新客户端请求的回调函数。该函数接收[*服务器和*](https://daurnimator.github.io/lua-http/0.4/#http.server)新[*流*](https://daurnimator.github.io/lua-http/0.4/#stream)作为参数。如果回调函数抛出错误，错误将从 [`:step()`](https://daurnimator.github.io/lua-http/0.4/#http.server:step) 或 [`:loop()`](https://daurnimator.github.io/lua-http/0.4/#http.server:loop) 中报告。
- `.tls`( *布尔值* )：指定系统是否应使用传输层安全协议。取值为：
  - `空值 `：允许 TLS 和非 TLS 连接
  - `true`：仅允许 TLS 连接
  - `false`：仅允许非 TLS 连接。
- `.ctx`（ *上下文对象* ）：用于 TLS 连接的 `openssl.ssl.context` 对象。如果传入 `nil`，将生成一个自签名上下文。
- `.connection_setup_timeout`( *数字* )：等待客户端发送第一个字节和/或完成 TLS 握手的时间超时（以秒为单位）。默认值为 10 秒。
- `.intra_stream_timeout`( *数字* )：在空闲连接上等待[*新流的*](https://daurnimator.github.io/lua-http/0.4/#stream)超时时间（以秒为单位），超过该时间后放弃并关闭连接。
- `.version`( *数字* )：允许连接的 HTTP 版本（默认：任何版本）
- `.cq`(*cqueue*)：用于作为主循环的 cqueues 控制器。默认情况下，为服务器创建一个新的控制器。
- `.max_concurrent`( *数字* )：允许同时存在的最大连接数。默认值为无限。

### `listen(options)`

创建一个新的套接字并返回一个将从该套接字接受连接的 HTTP 服务器。参数与 [`new(options)`](https://daurnimator.github.io/lua-http/0.4/#http.server.new) 相同，但将 `.socket` 替换为以下内容：

- `.host`( *字符串* )：本地 IP 地址，采用点分十进制或 IPv6 格式。如果未指定 `.path，` 则此值为必填项。
- `.port`( *数字* )：本地套接字的 IP 端口。指定 0 表示自动选择端口。端口 1-1024 需要应用程序具有 root 权限才能运行。最大值为 65535。如果 `.tls == nil，` 则此值为必填。否则，默认值为：
  - 如果 `.tls 为 false，则为 ``80`。
  - `443` 如果 `.tls 为 true`
- `.path`( *字符串* )：指向 UNIX 套接字的路径。如果未指定 `.host`，则此值为必填项。
- `.family`( *字符串* )：协议族。默认值为 `"AF_INET"`
- `.v6only`( *布尔值* )：设置为 `true` 以限制所有连接仅使用 IPv6（不使用 IPv4 映射的 IPv6 地址）。默认值为 `false`。
- `.mode`( *字符串* )：在创建 UNIX 域套接字后，使用 `fchmod` 或 `chmod` 命令设置套接字权限。
- `.mask`( *布尔值* )：在绑定 UNIX 域套接字时设置并恢复 umask 值。
- `.unlink`( *布尔值* )：`true` 表示在绑定前先断开套接字路径。
- `.reuseaddr`( *布尔型* )：启用 `SO_REUSEADDR` 标志。
- `.reuseport`( *布尔型* )：启用 `SO_REUSEPORT` 标志。

### `server:onerror(new_handler)`

如果带参数调用该函数，该函数将用 `new_handler` 替换当前的错误处理函数，并返回对旧函数的引用。不带参数调用该函数将返回当前的错误处理函数。默认处理函数会抛出错误。服务器的 `onerror` 函数可在实例化时通过传递给 [`server.listen(options)`](https://daurnimator.github.io/lua-http/0.4/#server.listen) 函数的`选项表`进行设置。

### `server:listen(timeout)`

初始化服务器套接字，并在必要时解析 DNS。如果[*在步骤*](https://daurnimator.github.io/lua-http/0.4/#http.server:step)或[*循环*](https://daurnimator.github.io/lua-http/0.4/#http.server:loop)之前调用了 [*localname*](https://daurnimator.github.io/lua-http/0.4/#http.server:localname)，则必须调用 `server:listen()`。发生错误时，返回 `nil`、错误消息和错误编号。

### `server:localname()`

返回本地套接字的连接信息。返回外部套接字的地址族、IP 地址和端口。对于 Unix 域套接字，该函数返回 AF_UNIX 和路径。如果连接对象未连接，则返回 AF_UNSPEC (0)。发生错误时，返回 `nil`、错误消息和错误编号。

### `server:pause()`

导致服务器循环停止处理新客户端，直到调用 [*resume*](https://daurnimator.github.io/lua-http/0.4/#http.server:resume) 方法。现有客户端连接将继续运行直至关闭。

### `server:resume()`

恢复`暂停`的服务器并处理新的客户端请求。

### `server:close()`

关闭服务器并关闭套接字。已关闭的服务器无法被重新使用。

### `server:pollfd()`

返回一个文件描述符（作为整数）或 `nil`。

文件描述符可以传递给系统 API（如 `select` 或 `kqueue`）以等待该服务器对象希望执行的任何操作。此方法用于与其他主循环集成，应与 [`:events()`](https://daurnimator.github.io/lua-http/0.4/#http.server:events) 和 [`:timeout()`](https://daurnimator.github.io/lua-http/0.4/#http.server:timeout) [``](https://daurnimator.github.io/lua-http/0.4/#http.server:events)方法配合使用。

### `server:events()`

返回一个字符串，指示对象正在等待的事件类型：如果对象希望在 [`pollfd()`](https://daurnimator.github.io/lua-http/0.4/#http.server:pollfd) 返回的文件描述符被标记为 POLLIN 时*被步进，* 字符串将包含 `"r"`；如果为 POLLOUT，则为 `"w"`；如果为 POLLPRI，则为 `"p"`。

此方法用于与其他主循环进行集成，应与 [`:pollfd()`](https://daurnimator.github.io/lua-http/0.4/#http.server:pollfd) 和 [`:timeout()`](https://daurnimator.github.io/lua-http/0.4/#http.server:timeout) 方法配合使用。

### `server:timeout()`

在调用 [`server:step()`](https://daurnimator.github.io/lua-http/0.4/#http.server:step) 之前等待的最大时间（以秒为单位）。

此方法用于与其他主循环进行集成，应与 [`:pollfd()`](https://daurnimator.github.io/lua-http/0.4/#http.server:pollfd) 和 [`:events()`](https://daurnimator.github.io/lua-http/0.4/#http.server:events) 方法配合使用。

### `server:empty()`

如果主套接字和所有客户端连接均已关闭，则返回 `true`，否则返回 `false`。

### `server:step(timeout)`

服务器主循环执行一次：所有等待的客户端将被`接受（accept()）`，所有待处理的流将开始被处理，每个 `onstream` 处理程序最多执行一次。该方法将阻塞*最多* `up_to_timeout` 秒。发生错误时，返回 `nil`、错误消息和错误编号。

这可用于与外部主循环的集成。

### `server:loop(timeout)`

以阻塞循环方式运行服务器，持续时间最长为 `timeout` 秒。服务器将持续监听并接受客户端请求，直至调用 [`:pause()`](https://daurnimator.github.io/lua-http/0.4/#http.server:pause) 或 [`:close()`](https://daurnimator.github.io/lua-http/0.4/#http.server:close) 方法，或发生错误。

### `server:add_socket(socket)`

向服务器添加一个新的连接套接字以进行处理。服务器将使用当前的`在线`请求处理程序以及通过 [`server.listen(options)`](https://daurnimator.github.io/lua-http/0.4/#http.server.listen) 构造函数指定的所有`选项 `。`add_socket` 可用于处理从外部源（如：）获取的连接套接字。

- 另一个 cqueues 线程，使用了其他主套接字。
- 从 inetd 启动按需启动的守护进程。
- 具有 `SCM_RIGHTS` 权限的 Unix 套接字。

### `server:add_stream(stream)`

将现有流添加到服务器进行处理。

## http.socks

实现 SOCKS 代理协议的子集。

### `connect(uri)`

`URI` 是一个字符串，包含 SOCKS 服务器的地址。使用 `"socks5"` 方案时，主机名将在本地解析；使用 `"socks5h"` 方案时，主机名将在 SOCKS 服务器上解析。如果 URI 包含用户信息组件，该组件将作为用户名和密码发送至 SOCKS 服务器。

返回一个 *http.socks* 对象。

### `fdopen(socket)`

该函数以一个现有的 cqueues.socket 对象作为参数，返回一个以`该 socket 对象`为基础的 *http.socks* 对象。

### `socks.needs_resolve`

指定是否应在本地解析目标主机。

### `socks:clone()`

克隆一个给定的 socks 对象。

### `socks:add_username_password_auth(username, password)`

将用户名 + 密码授权添加到允许的授权方法列表中，使用给定的凭据。

### `socks:negotiate(host, port, timeout)`

完成 SOCKS 连接。

建立 SOCKS 连接。`host` 是传递给 SOCKS 服务器的主机地址字符串。如果 [`.needs_resolve`](https://daurnimator.github.io/lua-http/0.4/#http.socks.needs_resolve) 为 `true`，则地址将在本地解析。`port` 是传递给 SOCKS 服务器的连接端口号。发生错误时，返回 `nil`、错误消息和错误代码。

### `socks:close()`

### `socks:take_socket()`

获取由 http.socks 对象管理的套接字对象。返回套接字对象（如果不存在则返回 `nil`）。

## http.tls

### `has_alpn`

布尔值，用于指示当前环境中是否可用 ALPN。

如果 OpenSSL 在编译时未启用 ALPN 支持，或者使用的是旧版本，则该功能可能被禁用。

### `has_hostname_validation`

布尔值，用于指示当前环境中是否支持[主机名验证 ](https://wiki.openssl.org/index.php/Hostname_validation)。

如果 OpenSSL 版本过旧，该功能可能被禁用。

### `modern_cipher_list`

[Mozilla “Modern” 密码套件列表](https://wiki.mozilla.org/Security/Server_Side_TLS#Modern_compatibility)以冒号分隔的列表形式，可直接传递给 OpenSSL。

### `intermediate_cipher_list`

[Mozilla “中间”密码套件列表 ](https://wiki.mozilla.org/Security/Server_Side_TLS#Intermediate_compatibility_.28default.29)，以冒号分隔的列表形式，可直接传递给 OpenSSL。

### `old_cipher_list`

[Mozilla “旧”密码套件列表 ](https://wiki.mozilla.org/Security/Server_Side_TLS#Old_backward_compatibility)，以冒号分隔的列表形式，可直接传递给 OpenSSL。

### `banned_ciphers`

一个集合（包含字符串键和值为 `true` 的表），其中键为 OpenSSL 密码名称，[ 表示在 HTTP 2 中被禁止使用的密码 ](https://http2.github.io/http2-spec/#BadCipherSuites)。

OpenSSL 未支持的加密算法未包含在该集合中。

### `new_client_context()`

创建并返回一个新的 luaossl SSL 上下文，用于 HTTP 客户端连接。

### `new_server_context()`

创建并返回一个新的 luaossl SSL 上下文，用于 HTTP 服务器连接。

## http.util

### `encodeURI(str)`

### `encodeURIComponent(str)`

### `decodeURI(str)`

### `decodeURIComponent(str)`

### `query_args(str)`

返回一个遍历 `str` 中所有字符对的迭代器。

#### 示例

```
local http_util = require "http.util"
for name, value in http_util.query_args("foo=bar&baz=qux") do
    print(name, value)
end
--[[ prints:
"foo", "bar"
"baz", "qux"
]]
```

### `dict_to_query(dict)`

将一个字典（字符串键的表）及其字符串值转换为编码后的查询字符串。

#### 示例

```
local http_util = require "http.util"
print(http_util.dict_to_query({foo = "bar"; baz = "qux"})) --> "baz=qux&foo=bar"
```

### `resolve_relative_path(orig_path, relative_path)`

### `is_safe_method(method)`

返回一个布尔值，表示传入的字符串`方法`是否为“安全”方法。有关详细信息，请参阅 [RFC 7231 第 4.2.1 节 ](https://tools.ietf.org/html/rfc7231#section-4.2.1)。

### `is_ip(str)`

返回一个布尔值，表示传入的字符串 `str` 是否为有效的 IP 地址。

### `scheme_to_port`

将方案（作为字符串）映射到默认端口（作为整数）。

### `split_authority(authority, scheme)`

将`权限`拆分为主机和端口组件。如果权限没有端口组件，将尝试使用`方案的`默认值。

#### 示例

```
local http_util = require "http.util"
print(http_util.split_authority("localhost:8000", "http")) --> "localhost", 8000
print(http_util.split_authority("example.com", "https")) --> "localhost", 443
```

### `to_authority(host, port, scheme)`

将`主机`和`端口`连接起来，以创建一个有效的授权组件。如果端口是`方案`的默认值，则省略端口。

### `imf_date(time)`

返回以 HTTP 首选日期格式表示的时间（参见 [RFC 7231 第 7.1.1.1 节 ](https://tools.ietf.org/html/rfc7231#section-7.1.1.1)）

`时间`默认设置为当前时间

### `maybe_quote(str)`

- 如果 `str` 是有效的`令牌 `，则原样返回。
- 如果 `str` 作为`引号字符串`是有效的，则返回其引号版本。
- 否则，返回 `nil`

## http.version

### `name`

```
"lua-http"
```

### `version`

当前版本的 lua-http 作为字符串。

## http.websocket

### `new_from_uri(uri, protocols)`

根据给定的 URI 创建一个类型为 `"client"` 的 `http.websocket` 对象。

- `协议 `（可选）应为一个 Lua 表，其中包含要发送给服务器的协议序列。

### `new_from_stream(stream, headers)`

尝试根据给定的请求头和流创建一个类型`为“服务器”` 的新 `http.websocket` 对象。

- [`流`](https://daurnimator.github.io/lua-http/0.4/#http.h1_stream)应为类型`为“服务器”` 的实时 HTTP 1 流。
- [`这些标头`](https://daurnimator.github.io/lua-http/0.4/#http.headers)应为来自 HTTP 1 客户端的疑似 WebSocket 升级请求的标头。

此函数**没有**副作用，因此可以暂时使用。

### `websocket.close_timeout`

发送关闭帧与实际关闭连接之间等待的时间（以秒为单位）。默认值为 `3` 秒。

### `websocket:accept(options, timeout)`

与 WebSocket 客户端完成协商。

- `选项`是一个包含以下内容的表格：
  - `头部信息 `（可选）一个用于作为响应头部原型的[头部](https://daurnimator.github.io/lua-http/0.4/#http.headers)对象
  - `协议 `（可选）应为一个 Lua 表，其中包含允许客户端使用的协议序列。

通常在成功调用 [`new_from_stream`](https://daurnimator.github.io/lua-http/0.4/#http.websocket.new_from_stream) 方法后调用。

### `websocket:connect(timeout)`

连接到 WebSocket 服务器。

通常在成功调用 [`new_from_uri`](https://daurnimator.github.io/lua-http/0.4/#http.websocket.new_from_uri) 方法后调用。

### `websocket:receive(timeout)`

读取并返回下一个数据帧及其操作码。在读取过程中接收到的任何 ping 帧都将被响应。

操作码 `0x1` 将被返回为 `"文本"`，而 `0x2` 将被返回为 `"二进制"`。

### `websocket:each()`

[`WebSocket 接收`](https://daurnimator.github.io/lua-http/0.4/#http.websocket:receive)事件迭代器。

### `websocket:send_frame(frame, timeout)`

低级函数用于发送原始帧。

### `websocket:send(data, opcode, timeout)`

将给定的`数据`以数据框的形式发送。

- `数据`应为字符串。
- `操作码`可以是数值操作码、`"文本"` 或 `"二进制"`。如果`为空 `，则默认为文本帧。注意此`操作码`是 WebSocket 帧操作码，而非应用程序特定操作码。操作码应来自 [IANA 注册表 ](https://www.iana.org/assignments/websocket/websocket.xhtml#opcode)。

### `websocket:send_ping(data, timeout)`

发送一个 ping 帧。

- `数据`为可选项

### `websocket:send_pong(data, timeout)`

发送一个 PONG 帧。作为单向保持活动信号。

- `数据`为可选项

### `websocket:close(code, reason, timeout)`

关闭 WebSocket 连接。

- `代码`默认值为 `1000`
- `原因`是一个可选的字符串。

## http.zlib

一个封装了各种 Lua zlib 库的抽象层。

### `engine`

目前可以使用 [`“lua-zlib`](https://github.com/brimworks/lua-zlib) [`”或“lzlib”`](https://github.com/LuaDist/lzlib)。

### `inflate()`

返回一个闭包，用于解压（解压缩）一个 zlib 流。

该函数接受一个压缩数据字符串和一个流结束标志（` 布尔值 `）作为参数，并返回解压后的输出作为字符串。如果输入不是有效的 zlib 流，函数将抛出错误。

### `deflate()`

返回一个闭包，用于对 zlib 流进行压缩（减小体积）。

该函数接受一个未压缩的数据字符串和一个表示流结束的标志（` 布尔值 `）作为参数，并返回压缩后的输出结果作为字符串。

### 示例

```
local zlib = require "http.zlib"
local original = "the racecar raced around the racecar track"
local deflater = zlib.deflate()
local compressed = deflater(original, true)
print(#original, #compressed) -- compressed should be smaller
local inflater = zlib.inflate()
local uncompressed = inflater(compressed, true)
assert(original == uncompressed)
```

## http.compat.prosody

提供[与 prosody 的 net.http](https://prosody.im/doc/developers/net/http) 类似的使用方式 [。](https://prosody.im/doc/developers/net/http)

### `request(url, ex, callback)`

与 prosody`net.http.request` 的几个关键区别：

- 必须在运行中的 cqueue 队列内部调用。
- 回调函数可能在队列中的不同线程中被调用。
- 返回的对象将是一个 [*http.request*](https://daurnimator.github.io/lua-http/0.4/#http.request) 对象。
  - 此对象在发生错误时传递给回调函数，并在成功时作为第四个参数传递。
- 默认用户代理将来自 lua-http（` 而非“Prosody XMPP 服务器”`）
- 在可能的情况下，将使用 Lua-HTTP 的功能（如 HTTP/2）。

### 示例

```
local prosody_http = require "http.compat.prosody"
local cqueues = require "cqueues"
local cq = cqueues.new()
cq:wrap(function()
    prosody_http.request("http://httpbin.org/ip", {}, function(b, c, r)
        print(c) --> 200
        print(b) --> {"origin": "123.123.123.123"}
    end)
end)
assert(cq:loop())
```

## http.compat.socket

提供[与 luasocket 的 http.request 模块的](http://w3.impa.br/~diego/software/luasocket/http.html)兼容性。

差异：

- 在由 cqueues 管理的多线程环境中运行时，将自动变为非阻塞模式。
- 在可能的情况下，将使用 Lua-HTTP 的功能（如 HTTP/2）。

### 示例

在正常脚本中使用“简单”界面：

```
local socket_http = require "http.compat.socket"
local body, code = assert(socket_http.request("http://lua.org"))
print(code, #body) --> 200, 2514
```

# 链接

- [Github](https://github.com/daurnimator/lua-http)
- [问题跟踪器](https://github.com/daurnimator/lua-http/issues)