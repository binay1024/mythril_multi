import os
import subprocess 
import pandas as pd
import time

# 设置基础目录 
data_dir_same = "/opt/1.Reentrancy/runtest/samefunction"
data_dir_diff = "/opt/1.Reentrancy/runtest/difffunction"
# data_dir = "/opt/paper_byte_sol"
output_dir = "/opt/1.Reentrancy/testOutput"
# 存储结果的列表
results = []
times_costs = []

# 遍历基础目录下的所有子目录 

def run(data_dir, flag = 2):
    counter = 0
    for subdir in os.listdir(data_dir):
        subdir_path = os.path.join(data_dir,subdir)

        # 确保是目录
        if os.path.isdir(subdir_path):
            
            # 构建 sol文件和 bin文件的 路径
            attackdir = "/opt/1.Reentrancy/Attack/"
            attackFile_same = "AttackBridgeV13.bin"
            attackFile_diff = "AttackBridgeV14.bin"
            attack_bridge_path_same = os.path.join(attackdir, attackFile_same)
            attack_bridge_path_diff = os.path.join(attackdir, attackFile_diff)
            if flag == 1:
                attack_bridge_path = attack_bridge_path_same
            else:
                attack_bridge_path = attack_bridge_path_diff
            bin_files = [file for file in os.listdir(subdir_path) if file.endswith('.bin')]
            if len(bin_files) >=2:
                print("warning, more than 2 bin files, defaultly select 1")
            bin_file = bin_files[0]
            print("%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%")
            print("analye target file {}".format(bin_file))
            
            bin_path = os.path.join(subdir_path, bin_file)
            temp = bin_file + 'log'
            # 检查文件是否存在
            if os.path.exists(attack_bridge_path) and os.path.exists(bin_path):

                command = "python3 myth.py analyze  {}".format(bin_path[:-3]) + "sol"
                print(command)
                subprocess.run(command, shell=True, text=True)
                
                output_path = os.path.join(output_dir, temp)
                # command = "python3 myth.py analyze -mc {} {}".format(bin_path,attack_bridge_path)
                command = "python3 myth.py analyze -mc {} {} > {}".format(bin_path,attack_bridge_path, output_path)
                print(command)
                # 执行命令并捕获输出
                time_start = time.time()
                try:
                    result = subprocess.run(command, shell=True, text=True)
                    # output = result.stdout

                    # 将文件名和输出添加到结果列表
                    # time_end = time.time()
                    # time_cost = time_end-time_start
                    # results.append([os.path.basename(subdir_path), output, time_cost])
                    counter += 1
                    
                except subprocess.CalledProcessError as e:
                    print(f"命令执行失败: {e}")
                    print("some error happen")
                    # break
                except BrokenPipeError as f:
                    print("brokenpip capture {}".format(f))


            else:
                print("file not exist")
            
        else:
            print("not a dir pass")
            continue
    return counter
# 创建 DataFrame
# print(results)
# df = pd.DataFrame(results, columns = ["Contract", "Result", "Timecost"])

# # 将 DataFrame 保存到 Excel 文件
# output_excel_path = os.path.join(data_dir, "runtest_output.xlsx")
# df.to_excel(output_excel_path, index = False)
if __name__ == "__main__":
    data_dir_same = "/opt/1.Reentrancy/runtest/samefunction"
    data_dir_diff = "/opt/1.Reentrancy/runtest/difffunction"
    counter = run(data_dir_same, 1)
    print("finish analyzing {} files".format(counter))
    counter = run(data_dir_diff, 2)
    print("finish analyzing {} files".format(counter))