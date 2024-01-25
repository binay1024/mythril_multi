import os
import subprocess 
# import pandas as pd
import time
import gc

# 设置基础目录 
data_dir = "/home/kevinj/Desktop/evaluation/dataset/paper_dataset/contract/ReentrancyStudy-Data-main/reentrancy_byte_sol/mul"
# data_dir = "/opt/paper_byte_sol"
# data_dir = "/opt/t1"

# 存储结果的列表
results = []
times_costs = []

# 遍历基础目录下的所有子目录 
counter = 0

for subdir in os.listdir(data_dir):
    subdir_path = os.path.join(data_dir,subdir)

    # 确保是目录
    if os.path.isdir(subdir_path):
        
        # 构建 sol文件和 bin文件的 路径
        attackdir = "/home/kevinj/Desktop/evaluation/dataset/paper_dataset/contract/ReentrancyStudy-Data-main/reentrancy_byte_sol/AttackBridge"
        attackFile = "AttackBridgeV15.bin"
        attack_bridge_path = os.path.join(attackdir, attackFile)

        bin_files = [file for file in os.listdir(subdir_path) if file.endswith('.bin')]
        flag = 1
        if len(bin_files) ==1 :
            bin_file = bin_files[0]
            print("%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%")
            print("analye target file {}".format(bin_file))
            
            bin_path = os.path.join(subdir_path, bin_file)

            # 检查文件是否存在
            if os.path.exists(attack_bridge_path) and os.path.exists(bin_path):
                if flag == 1:
                    command = "python3 myth.py analyze -mc {} {}".format(bin_path,attack_bridge_path)
                    print(command)
                else:
                    # command = "python3 myth.py analyze -mc {} {} {}".format(bin_path,attack_bridge_path)
                    pass
                    
                # 执行命令并捕获输出
                time_start = time.time()
                try:
                    result = subprocess.run(command, shell=True, text=True,  stdout=subprocess.PIPE)
                    output = result.stdout

                    # 将文件名和输出添加到结果列表
                    time_end = time.time()
                    time_cost = time_end-time_start
                    results.append([os.path.basename(subdir_path), output, time_cost])
                    counter += 1
                    
                except subprocess.CalledProcessError as e:
                    print(f"命令执行失败: {e}")
                    # print(results)
                    # break
                except BrokenPipeError as f:
                    print("brokenpip capture {}".format(f))
            else:
                print("file not exist")
            
        if len(bin_files) >2:
            print("warning, more than 2 bin files, reverse ordering")
            flag = 3

        if len(bin_files) ==2:
            flag = 2
            bin_file2 = [file for file in bin_files if file.endswith('2.bin')][0]
            bin_file1 = [file for file in bin_files if file.endswith('1.bin')][0]
            temp = subdir_path+".log"
            print("%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%")
            print("analye target file {} {}".format(bin_file1, bin_file2))
            
            bin1_path = os.path.join(subdir_path, bin_file1)
            bin2_path = os.path.join(subdir_path, bin_file2)

            # 检查文件是否存在
            if os.path.exists(attack_bridge_path) and os.path.exists(bin1_path) and os.path.exists(bin2_path):
                
                command = "python3 myth.py analyze  {}".format(bin1_path[:-3]) + "sol" + " --solver-timeout 600 -t 1"
                print(command)

                result = subprocess.run(command, shell=True, text=True)
                command = "python3 myth.py analyze  {}".format(bin2_path[:-3]) + "sol" + " --solver-timeout 600 -t 1"
                print(command)
                
                result = subprocess.run(command, shell=True, text=True)
                output = "/home/kevinj/Desktop/evaluation/dataset/paper_dataset/contract/ReentrancyStudy-Data-main/reentrancy_byte_sol/output"
                output_path = os.path.join(output, temp)
                command = "python3 myth.py analyze -mc {} {} {} --solver-timeout 600000 -t 1 --strategy dfs > {}".format(bin1_path,attack_bridge_path,bin2_path, output_path)
                print(command)
                # 执行命令并捕获输出
                time_start = time.time()
                try:
                    # result = subprocess.run(command, shell=True, text=True,  stdout=subprocess.PIPE)
                    subprocess.run(command, shell=True, text=True)
                    # output = result.stdout

                    # 将文件名和输出添加到结果列表
                    # time_end = time.time()
                    # time_cost = time_end-time_start
                    # results.append([os.path.basename(subdir_path), output, time_cost])
                    counter += 1
                    
                except subprocess.CalledProcessError as e:
                    print(f"命令执行失败: {e}")
                    # print(results)
                    # break
                except BrokenPipeError as f:
                    print("brokenpip capture {}".format(f))


            else:
                print("file not exist")
        
        
    else:
        print("not a dir pass")
        continue
    # 回收内存垃圾
    gc.collect()
# 创建 DataFrame
# print(results)
# df = pd.DataFrame(results, columns = ["Contract", "Result", "Timecost"])

# # 将 DataFrame 保存到 Excel 文件
# output_excel_path = os.path.join(data_dir, "runtest_output.xlsx")
# df.to_excel(output_excel_path, index = False)
print("finish analyzing {} files".format(counter))