import os
import shutil

# 设置基础目录
base_dir = "/opt/paper_byte&sol"
target_dir = "/opt/paper_byte&sol0.5"
# 初始化包含特定pragma的目录列表
pragma_05_dirs = []

# 遍历基础目录下的所有子目录
for subdir in os.listdir(base_dir):
    subdir_path = os.path.join(base_dir, subdir)
    
    # 确保是目录
    if os.path.isdir(subdir_path):
        # 遍历目录中的所有文件
        for file in os.listdir(subdir_path):
            if file.endswith('.sol'):
                file_path = os.path.join(subdir_path, file)
                
                # 检查文件内容
                with open(file_path, 'r') as f:
                    contents = f.read()
                    if "pragma solidity ^0.5" in contents:
                        pragma_05_dirs.append(subdir)

                        target_subdir_path = os.path.join(target_dir, subdir)

                        if not os.path.exists(target_subdir_path):
                            # print("创建文件夹")
                            os.makedirs(target_subdir_path)

                        shutil.copytree(subdir_path, target_subdir_path, dirs_exist_ok=True)

                        break  # 只需找到一个符合条件的文件即可

# 输出包含指定pragma的目录
print("包含pragma solidity ^0.5的目录:")
# for dir in pragma_05_dirs:
    # print(dir)
print("目录数目为 {}".format(len(pragma_05_dirs)))


