import os
import glob 
import tempfile
import shutil
# base_dir
# data_dir = "/opt/test"
# data_dir = "/opt/cross-reentrancy"
data_dir = "/opt/cross-test"
# data_dir = "/opt/t1"

# 遍历目录中 .rt.hex 文件

# for filepath in glob.glob(data_dir + '/**/*.rt.hex', recursive=True):
#     # 构建新文件名（替换 .rt.hex 为 .bin）
#     new_filepath = filepath.rsplit('.rt.hex', 1)[0] + '.bin'

#     # 重命名文件
#     os.rename(filepath, new_filepath)

#     print(f"Renamed '{filepath}' to '{new_filepath}'")

# for dirpath, dirnames, filenames in os.walk(data_dir):
#     for filename in filenames:
#         if ' ' in filename:
#             new_filename = filename.replace(' ', '')
#             original_file_path = os.path.join(dirpath, filename)
#             new_file_path = os.path.join(dirpath, new_filename)

#             # 重命名文件
#             os.rename(original_file_path, new_file_path)
#             print(f"重命名：'{filename}' -> '{new_filename}'")
for subdir in os.listdir(data_dir):
    subdir_path = os.path.join(data_dir,subdir)

    # 确保是目录
    if os.path.isdir(subdir_path):
        

        bin_files = [file for file in os.listdir(subdir_path) if file.endswith('.bin')]
            
        if len(bin_files) ==2:
           
            bin_file2 = [file for file in bin_files if file.endswith('2.bin')][0]
            bin_file1 = [file for file in bin_files if file.endswith('1.bin')][0]
            print("%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%")
            print("analye target file {} {}".format(bin_file1, bin_file2))
            
            bin1_path = os.path.join(subdir_path, bin_file1)
            bin2_path = os.path.join(subdir_path, bin_file2)
            # 使用临时文件来安全交换名称
            with tempfile.NamedTemporaryFile(delete=False, dir=subdir_path) as tmp:
                tmp_path = tmp.name

                # 重命名文件1 -> 临时文件
            shutil.move(bin1_path, tmp_path)

                # 重命名文件2 -> 文件1
            shutil.move(bin2_path, bin1_path)

                # 重命名临时文件 -> 文件2
            shutil.move(tmp_path, bin2_path)

            print(f"在 {subdir_path} 中交换了文件：'{bin_file1}' 和 '{bin_file2}'")

