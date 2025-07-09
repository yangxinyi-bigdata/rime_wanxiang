#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
一次性脚本：将 20250612_phrases.ini 转换为 ZRM_Aux-code_4.3.txt 格式
修改版：去掉前两个字符，不足三个字符的跳过
"""

def convert_phrases():
    input_file = "20250612_phrases.ini"
    output_file = "ziranma_20250612_phrases.txt"
    
    print(f"正在读取文件: {input_file}")
    print("开始执行转换...")
    
    # 用于存储转换后的数据
    converted_lines = []
    skipped_count = 0
    
    try:
        # 尝试不同的编码格式
        encodings = ['utf-8', 'gbk', 'gb2312', 'utf-16', 'utf-16le', 'utf-16be', 'latin1']
        content = None
        used_encoding = None
        
        for encoding in encodings:
            try:
                with open(input_file, 'r', encoding=encoding) as f:
                    content = f.readlines()
                    used_encoding = encoding
                    print(f"成功使用编码: {encoding}")
                    break
            except (UnicodeDecodeError, UnicodeError):
                continue
        
        if content is None:
            print("错误：无法识别文件编码")
            return
        
        for line_num, line in enumerate(content, 1):
            line = line.strip()
            if not line:
                continue
            
            # 解析格式：编码,序号=汉字
            if '=' in line:
                try:
                    left_part, chinese_char = line.split('=', 1)
                    # 提取编码部分（去掉序号）
                    if ',' in left_part:
                        aux_code = left_part.split(',')[0]
                    else:
                        aux_code = left_part
                    
                    # 检查编码长度，不足三个字符则跳过
                    if len(aux_code) < 3:
                        skipped_count += 1
                        continue
                    
                    # 去掉前两个字符
                    new_aux_code = aux_code[2:]
                    
                    # 转换为目标格式：汉字=辅助码
                    converted_line = f"{chinese_char}={new_aux_code}"
                    converted_lines.append(converted_line)
                    
                except Exception as e:
                    print(f"警告：第 {line_num} 行解析失败: {line} - {e}")
                    continue
        
        print(f"成功解析 {len(converted_lines)} 条记录")
        print(f"跳过 {skipped_count} 条记录（编码长度不足3个字符）")
        
        # 写入输出文件
        print(f"正在写入文件: {output_file}")
        with open(output_file, 'w', encoding='utf-8') as f:
            for line in converted_lines:
                f.write(line + '\n')
        
        print(f"转换完成！生成了 {len(converted_lines)} 条记录")
        print(f"输出文件: {output_file}")
        
    except FileNotFoundError:
        print(f"错误：找不到输入文件 {input_file}")
    except Exception as e:
        print(f"错误：{e}")

if __name__ == "__main__":
    convert_phrases()
