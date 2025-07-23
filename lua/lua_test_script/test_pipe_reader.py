#!/usr/bin/env python3
"""
测试命名管道读取器
用于验证 Rime 状态数据的实时读取和消费
"""

import json
import os
import time
import signal
import sys
from typing import Dict, Optional

class RimeStateTestReader:
    def __init__(self, pipe_path: str = "/tmp/rime_state_pipe", debug: bool = False):
        self.pipe_path = pipe_path
        self.pipe_fd = None
        self.running = True
        self.message_count = 0
        self.debug = debug
        
    def signal_handler(self, signum, frame):
        """处理 Ctrl+C 信号"""
        print(f"\n收到停止信号，共处理了 {self.message_count} 条消息")
        self.running = False
        sys.exit(0)  # 强制退出
        
    def connect(self) -> bool:
        """连接到命名管道"""
        try:
            print(f"正在连接到管道: {self.pipe_path}")
            # 以只读模式打开管道（会阻塞直到有写入端）
            self.pipe_fd = open(self.pipe_path, 'r')
            print("管道连接成功！")
            return True
        except OSError as e:
            print(f"连接管道失败: {e}")
            return False
    
    def read_and_consume(self):
        """读取并消费管道数据"""
        if not self.pipe_fd:
            return
            
        print("开始读取数据...\n")
        
        # 设置信号处理
        signal.signal(signal.SIGINT, self.signal_handler)
        
        buffer = ""
        
        try:
            while self.running:
                # 读取一行数据
                line = self.pipe_fd.readline()
                
                if line:
                    line = line.strip()
                    if line:
                        if self.debug:
                            print(f"[DEBUG] 读取行: {line}")
                        
                        buffer += line + "\n"
                        
                        # 检查是否是单行JSON（包含完整的JSON对象）
                        if line.startswith("{") and line.endswith("}"):
                            try:
                                if self.debug:
                                    print(f"[DEBUG] 尝试解析单行JSON: {line}")
                                # 直接解析单行JSON
                                json_data = json.loads(line)
                                self.process_message(json_data)
                                buffer = ""  # 清空缓冲区
                                continue
                            except json.JSONDecodeError as e:
                                if self.debug:
                                    print(f"[DEBUG] 单行JSON解析失败: {e}")
                                # 如果单行解析失败，继续用多行模式
                                pass
                        
                        # 尝试解析 JSON（当遇到完整的 JSON 对象时）- 多行模式
                        if line == "}":
                            try:
                                if self.debug:
                                    print(f"[DEBUG] 尝试解析多行JSON缓冲区: {buffer.strip()}")
                                # 解析累积的 JSON 数据
                                json_data = json.loads(buffer.strip())
                                self.process_message(json_data)
                                buffer = ""  # 清空缓冲区
                            except json.JSONDecodeError as e:
                                if self.debug:
                                    print(f"[DEBUG] 多行JSON解析失败: {e}")
                                # JSON 不完整，继续累积
                                pass
                else:
                    # 没有数据时短暂休眠
                    time.sleep(0.01)
                    
        except Exception as e:
            print(f"读取过程中出错: {e}")
        finally:
            self.close()
    
    def process_message(self, data: Dict):
        """处理收到的消息"""
        self.message_count += 1
        
        # 格式化时间戳
        timestamp = data.get('timestamp', 0)
        formatted_time = time.strftime('%H:%M:%S', time.localtime(timestamp / 1000))
        
        print(f"[{self.message_count:3d}] {formatted_time} | "
              f"输入: {'是' if data.get('is_composing') else '否'} | "
              f"模式: {data.get('input_mode', 'unknown'):<7} | "
              f"文本: '{data.get('input_text', ''):<10}' | "
              f"候选: {data.get('candidate_count', 0)}")
        
        # 每10条消息显示一次统计
        if self.message_count % 10 == 0:
            print(f"--- 已处理 {self.message_count} 条消息 ---")
    
    def close(self):
        """关闭连接"""
        if self.pipe_fd:
            self.pipe_fd.close()
            self.pipe_fd = None
            print(f"\n管道连接已关闭，总共处理了 {self.message_count} 条消息")

def main():
    print("=== Rime 状态管道测试读取器 ===")
    print("按 Ctrl+C 停止读取")
    print()
    
    # 支持调试模式
    debug_mode = len(sys.argv) > 1 and sys.argv[1] == "--debug"
    if debug_mode:
        print("启用调试模式")
    
    reader = RimeStateTestReader(debug=debug_mode)
    
    if not reader.connect():
        print("无法连接到 Rime 状态管道")
        print("请确保:")
        print("1. Rime 输入法正在运行")
        print("2. named_pipe_cached_sync.lua 模块已加载")
        print("3. 管道文件存在: /tmp/rime_state_pipe")
        return 1
    
    reader.read_and_consume()
    return 0

if __name__ == "__main__":
    sys.exit(main())
