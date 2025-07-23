#!/usr/bin/env python3
"""
持续运行的TCP测试服务端
专门用于测试Lua客户端的读写功能，提供详细的日志和交互功能

当前测试可以跑通的python端代码

"""

import socket
import json
import threading
import time
import logging
import sys
from datetime import datetime

# 配置详细日志
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.StreamHandler(sys.stdout),
        logging.FileHandler('tcp_test_server.log')
    ]
)
logger = logging.getLogger(__name__)

class ContinuousTcpTestServer:
    def __init__(self, host='127.0.0.1', port=12345):
        self.host = host
        self.port = port
        self.server_socket = None
        self.clients = {}  # 存储客户端信息
        self.running = False
        self.message_count = 0
        self.start_time = time.time()
        
    def start(self):
        """启动TCP测试服务端"""
        try:
            self.server_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            self.server_socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            self.server_socket.bind((self.host, self.port))
            self.server_socket.listen(10)
            
            self.running = True
            logger.info(f"🚀 TCP测试服务端启动成功，监听 {self.host}:{self.port}")
            logger.info("📊 支持的测试功能：")
            logger.info("   - 接收Rime状态数据")
            logger.info("   - 响应ping/pong测试")
            logger.info("   - 定期发送测试命令")
            logger.info("   - 实时统计信息")
            
            # 启动接受连接的线程
            accept_thread = threading.Thread(target=self._accept_connections, name="AcceptThread")
            accept_thread.daemon = True
            accept_thread.start()
            
            # 启动统计线程
            stats_thread = threading.Thread(target=self._stats_reporter, name="StatsThread")
            stats_thread.daemon = True
            stats_thread.start()
            
            # 启动定期测试线程
            test_thread = threading.Thread(target=self._periodic_tests, name="TestThread")
            test_thread.daemon = True
            test_thread.start()
            
            return True
            
        except Exception as e:
            logger.error(f"❌ TCP服务端启动失败: {e}")
            return False
    
    def _accept_connections(self):
        """接受客户端连接"""
        while self.running:
            try:
                client_socket, client_address = self.server_socket.accept()
                client_id = f"{client_address[0]}:{client_address[1]}"
                
                logger.info(f"🔗 新客户端连接: {client_id}")
                
                # 存储客户端信息
                self.clients[client_id] = {
                    'socket': client_socket,
                    'address': client_address,
                    'connect_time': time.time(),
                    'message_count': 0,
                    'last_activity': time.time()
                }
                
                # 为每个客户端启动处理线程
                client_thread = threading.Thread(
                    target=self._handle_client,
                    args=(client_socket, client_address, client_id),
                    name=f"Client-{client_id}"
                )
                client_thread.daemon = True
                client_thread.start()
                
            except Exception as e:
                if self.running:
                    logger.error(f"❌ 接受连接失败: {e}")
    
    def _handle_client(self, client_socket, client_address, client_id):
        """处理单个客户端"""
        try:
            client_socket.settimeout(30.0)  # 30秒超时
            
            while self.running:
                try:
                    # 接收数据
                    data = client_socket.recv(4096).decode('utf-8')
                    if not data:
                        logger.warning(f"📤 客户端 {client_id} 断开连接")
                        break
                    
                    # 更新活动时间
                    if client_id in self.clients:
                        self.clients[client_id]['last_activity'] = time.time()
                        self.clients[client_id]['message_count'] += 1
                    
                    # 处理可能包含多行的数据
                    lines = data.strip().split('\n')
                    for line in lines:
                        if line.strip():
                            self._process_message(client_socket, client_id, line.strip())
                            
                except socket.timeout:
                    # 检查客户端是否还活跃
                    if client_id in self.clients:
                        last_activity = self.clients[client_id]['last_activity']
                        if time.time() - last_activity > 60:  # 60秒无活动
                            logger.warning(f"⏰ 客户端 {client_id} 超时，断开连接")
                            break
                    continue
                except Exception as e:
                    logger.error(f"❌ 处理客户端 {client_id} 数据失败: {e}")
                    break
                    
        except Exception as e:
            logger.error(f"❌ 客户端 {client_id} 处理异常: {e}")
        finally:
            # 清理客户端连接
            if client_id in self.clients:
                connection_time = time.time() - self.clients[client_id]['connect_time']
                msg_count = self.clients[client_id]['message_count']
                logger.info(f"👋 客户端 {client_id} 断开 (连接时长: {connection_time:.1f}s, 消息数: {msg_count})")
                del self.clients[client_id]
            
            try:
                client_socket.close()
            except:
                pass
    
    def _process_message(self, client_socket, client_id, message):
        """处理来自客户端的消息"""
        try:
            self.message_count += 1
            
            # 处理简单命令
            if message == "ping":
                response = '{"response": "pong", "timestamp": ' + str(int(time.time() * 1000)) + '}\n'
                client_socket.send(response.encode('utf-8'))
                logger.info(f"🏓 响应ping命令给客户端 {client_id}")
                return
            
            # 尝试解析JSON数据
            try:
                data = json.loads(message)
                logger.info(f"📨 收到客户端 {client_id} 的数据: {self._format_rime_data(data)}")
                
                # 处理不同类型的消息
                if 'is_composing' in data:
                    # Rime状态数据
                    self._handle_rime_state(client_socket, client_id, data)
                elif 'command' in data:
                    # 命令数据
                    self._handle_command(client_socket, client_id, data)
                else:
                    logger.info(f"📋 收到未知格式数据: {message[:100]}...")
                    
            except json.JSONDecodeError:
                logger.warning(f"⚠️  JSON解析失败，原始数据: {message[:100]}...")
                
        except Exception as e:
            logger.error(f"❌ 消息处理失败: {e}")
    
    def _format_rime_data(self, data):
        """格式化Rime状态数据为易读格式"""
        if 'timestamp' in data:
            timestamp = datetime.fromtimestamp(data['timestamp'] / 1000)
            time_str = timestamp.strftime('%H:%M:%S.%f')[:-3]
        else:
            time_str = "未知时间"
            
        return (f"输入模式={data.get('input_mode', '未知')}, "
                f"输入中={data.get('is_composing', '未知')}, "
                f"内容='{data.get('input_text', '')}', "
                f"时间={time_str}")
    
    def _handle_rime_state(self, client_socket, client_id, state_data):
        """处理Rime状态数据"""
        # 可以在这里添加特定的Rime状态处理逻辑
        
        # 发送确认响应
        response = {
            "response": "rime_state_received",
            "timestamp": int(time.time() * 1000),
            "client_id": client_id
        }
        
        try:
            response_json = json.dumps(response) + '\n'
            client_socket.send(response_json.encode('utf-8'))
            logger.debug(f"✅ 已确认Rime状态数据给客户端 {client_id}")
        except Exception as e:
            logger.error(f"❌ 发送确认响应失败: {e}")
    
    def _handle_command(self, client_socket, client_id, command_data):
        """处理命令数据"""
        command = command_data.get('command')
        logger.info(f"⚡ 收到客户端 {client_id} 的命令: {command}")
        
        if command == "get_status":
            # 返回服务端状态
            uptime = time.time() - self.start_time
            response = {
                "response": "status",
                "data": {
                    "server_time": int(time.time() * 1000),
                    "client_count": len(self.clients),
                    "uptime_seconds": round(uptime, 1),
                    "total_messages": self.message_count,
                    "clients": list(self.clients.keys())
                }
            }
            
        elif command == "clear_cache":
            response = {"response": "cache_cleared", "timestamp": int(time.time() * 1000)}
            
        elif command == "ping":
            response = {"response": "pong", "timestamp": int(time.time() * 1000)}
            
        else:
            response = {"response": "unknown_command", "command": command}
        
        try:
            response_json = json.dumps(response) + '\n'
            client_socket.send(response_json.encode('utf-8'))
            logger.info(f"📤 已响应命令 '{command}' 给客户端 {client_id}")
        except Exception as e:
            logger.error(f"❌ 发送命令响应失败: {e}")
    
    def _stats_reporter(self):
        """定期报告统计信息"""
        while self.running:
            time.sleep(30)  # 每30秒报告一次
            
            if self.clients:
                uptime = time.time() - self.start_time
                avg_msg_per_client = self.message_count / len(self.clients) if self.clients else 0
                
                logger.info(f"📊 统计信息 - 运行时长: {uptime:.1f}s, "
                           f"活跃客户端: {len(self.clients)}, "
                           f"总消息数: {self.message_count}, "
                           f"平均每客户端: {avg_msg_per_client:.1f}")
                
                # 显示每个客户端的详细信息
                for client_id, info in self.clients.items():
                    conn_time = time.time() - info['connect_time']
                    last_activity = time.time() - info['last_activity']
                    logger.info(f"  👤 {client_id}: 连接 {conn_time:.1f}s, "
                               f"消息 {info['message_count']}, "
                               f"最后活动 {last_activity:.1f}s前")
    
    def _periodic_tests(self):
        """定期发送测试命令 - 真正的双向通信"""
        while self.running:
            time.sleep(15)  # 每15秒发送一次主动消息
            
            if self.clients:
                # 发送不同类型的主动消息
                message_types = [
                    {
                        "command": "server_ping",
                        "test_type": "bidirectional",
                        "server_message_id": int(time.time()),
                        "timestamp": int(time.time() * 1000)
                    },
                    {
                        "command": "server_status_check",
                        "server_info": {
                            "uptime": round(time.time() - self.start_time, 1),
                            "total_messages": self.message_count,
                            "active_clients": len(self.clients)
                        },
                        "timestamp": int(time.time() * 1000)
                    },
                    {
                        "command": "server_broadcast",
                        "message": f"服务端广播消息 - 当前时间: {datetime.now().strftime('%H:%M:%S')}",
                        "broadcast_id": int(time.time()),
                        "timestamp": int(time.time() * 1000)
                    }
                ]
                
                # 轮换发送不同类型的消息
                current_time = int(time.time())
                msg_type = message_types[current_time % len(message_types)]
                command_json = json.dumps(msg_type) + '\n'
                
                logger.info(f"🔄 服务端主动发送消息类型: {msg_type.get('command', 'unknown')}")
                
                for client_id, info in list(self.clients.items()):
                    try:
                        info['socket'].send(command_json.encode('utf-8'))
                        logger.info(f"� 服务端向客户端 {client_id} 发送: {msg_type.get('command', 'unknown')}")
                    except Exception as e:
                        logger.error(f"❌ 服务端发送消息失败给客户端 {client_id}: {e}")
    
    def stop(self):
        """停止服务端"""
        logger.info("🛑 正在停止TCP测试服务端...")
        self.running = False
        
        # 关闭所有客户端连接
        for client_id, info in list(self.clients.items()):
            try:
                info['socket'].close()
            except:
                pass
        self.clients.clear()
        
        # 关闭服务端socket
        if self.server_socket:
            self.server_socket.close()
        
        uptime = time.time() - self.start_time
        logger.info(f"✅ TCP测试服务端已停止 (运行时长: {uptime:.1f}s, 总消息数: {self.message_count})")

def main():
    """主函数"""
    server = ContinuousTcpTestServer()
    
    try:
        if server.start():
            logger.info("🎯 服务端运行中，支持以下测试功能：")
            logger.info("   - Lua客户端连接测试")
            logger.info("   - Rime状态数据接收")
            logger.info("   - 双向命令测试")
            logger.info("   - 定期ping/pong测试")
            logger.info("   - 连接状态监控")
            logger.info("📝 按Ctrl+C停止服务器...")
            
            while True:
                time.sleep(1)
    except KeyboardInterrupt:
        logger.info("🛑 收到停止信号")
    except Exception as e:
        logger.error(f"❌ 服务端运行异常: {e}")
    finally:
        server.stop()

if __name__ == "__main__":
    main()
