#!/usr/bin/env python3
"""
TCP服务端示例
用于接收来自Lua客户端的Rime状态数据，并提供双向通信
"""

import socket
import json
import threading
import time
import logging
from datetime import datetime

# 配置日志
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class RimeTcpServer:
    def __init__(self, host='127.0.0.1', port=12345):
        self.host = host
        self.port = port
        self.server_socket = None
        self.clients = []
        self.running = False
        
    def start(self):
        """启动TCP服务端"""
        try:
            self.server_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            self.server_socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            self.server_socket.bind((self.host, self.port))
            self.server_socket.listen(5)
            
            self.running = True
            logger.info(f"TCP服务端启动成功，监听 {self.host}:{self.port}")
            
            # 启动接受连接的线程
            accept_thread = threading.Thread(target=self._accept_connections)
            accept_thread.daemon = True
            accept_thread.start()
            
            # 启动命令发送线程（示例）
            command_thread = threading.Thread(target=self._send_commands)
            command_thread.daemon = True
            command_thread.start()
            
            return True
            
        except Exception as e:
            logger.error(f"TCP服务端启动失败: {e}")
            return False
    
    def _accept_connections(self):
        """接受客户端连接"""
        while self.running:
            try:
                client_socket, client_address = self.server_socket.accept()
                logger.info(f"客户端连接: {client_address}")
                
                # 为每个客户端启动处理线程
                client_thread = threading.Thread(
                    target=self._handle_client,
                    args=(client_socket, client_address)
                )
                client_thread.daemon = True
                client_thread.start()
                
                self.clients.append(client_socket)
                
            except Exception as e:
                if self.running:
                    logger.error(f"接受连接失败: {e}")
    
    def _handle_client(self, client_socket, client_address):
        """处理单个客户端"""
        try:
            # 设置socket为非阻塞模式
            client_socket.settimeout(1.0)
            
            while self.running:
                try:
                    # 接收一行数据
                    data = client_socket.recv(4096).decode('utf-8')
                    if not data:
                        break
                    
                    # 处理可能包含多行的数据
                    lines = data.strip().split('\n')
                    for line in lines:
                        if line.strip():
                            self._process_message(client_socket, line.strip())
                            
                except socket.timeout:
                    # 超时继续循环
                    continue
                except Exception as e:
                    logger.error(f"处理客户端数据失败: {e}")
                    break
                    
        except Exception as e:
            logger.error(f"客户端处理异常: {e}")
        finally:
            # 清理客户端连接
            if client_socket in self.clients:
                self.clients.remove(client_socket)
            client_socket.close()
            logger.info(f"客户端断开: {client_address}")
    
    def _process_message(self, client_socket, message):
        """处理来自客户端的消息"""
        try:
            # 尝试解析JSON
            if message == "ping":
                # 简单的ping响应
                response = '{"response": "pong"}\n'
                client_socket.send(response.encode('utf-8'))
                logger.info("响应ping命令")
                return
            
            # 解析JSON数据
            data = json.loads(message)
            logger.info(f"收到状态数据: {data}")
            
            # 处理不同类型的消息
            if 'is_composing' in data:
                # Rime状态数据
                self._handle_rime_state(data)
            elif 'command' in data:
                # 命令数据
                self._handle_command(client_socket, data)
            else:
                logger.warning(f"未知消息格式: {message}")
                
        except json.JSONDecodeError:
            logger.error(f"JSON解析失败: {message}")
        except Exception as e:
            logger.error(f"消息处理失败: {e}")
    
    def _handle_rime_state(self, state_data):
        """处理Rime状态数据"""
        timestamp = datetime.fromtimestamp(state_data.get('timestamp', 0) / 1000)
        logger.info(
            f"Rime状态 - 输入模式: {state_data.get('input_mode')}, "
            f"输入中: {state_data.get('is_composing')}, "
            f"输入文本: '{state_data.get('input_text')}', "
            f"时间: {timestamp.strftime('%H:%M:%S.%f')[:-3]}"
        )
    
    def _handle_command(self, client_socket, command_data):
        """处理命令数据"""
        command = command_data.get('command')
        logger.info(f"收到命令: {command}")
        
        if command == "get_status":
            # 返回服务端状态
            response = {
                "response": "status",
                "data": {
                    "server_time": time.time() * 1000,
                    "client_count": len(self.clients),
                    "uptime": time.time()
                }
            }
            response_json = json.dumps(response) + '\n'
            client_socket.send(response_json.encode('utf-8'))
            
        elif command == "clear_cache":
            # 确认缓存清理
            response = '{"response": "cache_cleared"}\n'
            client_socket.send(response.encode('utf-8'))
    
    def _send_commands(self):
        """定期发送命令到客户端（示例）"""
        while self.running:
            time.sleep(30)  # 每30秒发送一次
            
            if self.clients:
                # 发送ping命令
                command = '{"command": "ping"}\n'
                for client in self.clients[:]:  # 使用副本避免修改列表问题
                    try:
                        client.send(command.encode('utf-8'))
                        logger.info("发送ping命令到客户端")
                    except Exception as e:
                        logger.error(f"发送命令失败: {e}")
                        if client in self.clients:
                            self.clients.remove(client)
    
    def stop(self):
        """停止服务端"""
        self.running = False
        
        # 关闭所有客户端连接
        for client in self.clients:
            try:
                client.close()
            except:
                pass
        self.clients.clear()
        
        # 关闭服务端socket
        if self.server_socket:
            self.server_socket.close()
        
        logger.info("TCP服务端已停止")

def main():
    """主函数"""
    server = RimeTcpServer()
    
    try:
        if server.start():
            logger.info("服务端运行中，按Ctrl+C停止...")
            while True:
                time.sleep(1)
    except KeyboardInterrupt:
        logger.info("收到停止信号")
    finally:
        server.stop()

if __name__ == "__main__":
    main()
