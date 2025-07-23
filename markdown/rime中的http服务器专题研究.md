# rime中的http服务器专题研究


socket通信原理:
1. 任何时候都可以使用send发送消息

### 什么时候发送消息?
应该在 context 上下文发生变化的时候，马上发送消息吗？

rime输入法is_composing的时候,发送当前is_composing的状态到rime.

同时接收rime给的响应,从中提取是否存在command内容,如果存在则进行执行, 然后再返回给python一个响应消息.

