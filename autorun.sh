#!/bin/bash

# 设定主目录路径
parent_dir="/opt/paper_byte_sol"
attack="/opt/1.Reentrancy/Attack/AttackBridgeV15.bin"

# 遍历子目录
for subdir in "$parent_dir"/*/; do
    # 查找所有 .bin 文件
    bin_files=("$subdir"*.bin)
    sol_files=("$subdir"*.sol)

    
    # 检查是否找到了 .bin 文件
    if [[ ${#bin_files[@]} -gt 0 ]]; then
        # 对每个 .bin 文件执行命令并重定向输出
        for file in "${bin_files[@]}"; do
            filename=$(basename "$file")
            output_file="/opt/1.Reentrancy/testOutput/1wOutput/${filename}.log"
            if [[ -f "${output_file}" ]]; then
                echo "已经测试过了 文件 ${output_file}，略过此目录。"
                continue  # 跳过此次循环的剩余部分
            fi
            # python3 myth.py analyze "${sol_files[0]}" -t 1 --solver-timeout 1000 
            echo "开始测试 bin文件" 
            python3 myth.py analyze -mc "$file" "$attack" -t 1 --solver-timeout 1000 | tee "$output_file"
        done
    else
        echo "在 $subdir 中找不到 .bin 文件"
    fi
done
