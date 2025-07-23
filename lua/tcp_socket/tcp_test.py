#!/usr/bin/env python3
"""
简单的TCP测试脚本
用于测试Lua客户端和Python服务端的TCP通信
"""

import socket
import json
import time
import threading
import sys

def test_client():
    """测试客户端功能"""
    try:
        # 连接到服务端
        client = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        client.connect(('127.0.0.1', 12345))
        client.settimeout(1.0)
        
        print("连接到TCP服务端成功")
        
        # 发送测试数据
        test_data = {
            "is_composing": True,
            "input_mode": "chinese",
            "input_text": "test",
            "timestamp": int(time.time() * 1000)
        }
        
        # 发送JSON数据
        json_str = json.dumps(test_data) + '\n'
        client.send(json_str.encode('utf-8'))
        print(f"发送数据: {test_data}")
        
        # 发送ping
        client.send("ping\n".encode('utf-8'))
        print("发送ping")
        
        # 接收响应
        try:
            response = client.recv(1024).decode('utf-8')
            print(f"收到响应: {response.strip()}")
        except socket.timeout:
            print("未收到响应（超时）")
        
        client.close()
        print("客户端测试完成")
        
    except Exception as e:
        print(f"客户端测试失败: {e}")

def simple_server():
    """简单的测试服务端"""
    try:
        server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        server.bind(('127.0.0.1', 12345))
        server.listen(1)
        
        print("简单TCP服务端启动，监听端口 12345")
        print("等待连接...")
        
        while True:
            client, addr = server.accept()
            print(f"客户端连接: {addr}")
            
            try:
                while True:
                    data = client.recv(1024).decode('utf-8')
                    if not data:
                        break
                    
                    print(f"收到数据: {data.strip()}")
                    
                    # 简单的ping响应
                    if "ping" in data:
                        client.send('{"response": "pong"}\n'.encode('utf-8'))
                        print("发送pong响应")
                    
            except Exception as e:
                print(f"处理客户端数据失败: {e}")
            finally:
                client.close()
                print("客户端断开")
                
    except KeyboardInterrupt:
        print("服务端停止")
    except Exception as e:
        print(f"服务端错误: {e}")
    finally:
        server.close()

if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "client":
        test_client()
    else:
        simple_server()
