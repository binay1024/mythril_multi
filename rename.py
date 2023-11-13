import os
import glob 

# base_dir
# data_dir = "/opt/test"
data_dir = "/opt/paper_byte&sol"

# 遍历目录中 .rt.hex 文件

for filepath in glob.glob(data_dir + '/**/*.rt.hex', recursive=True):
    # 构建新文件名（替换 .rt.hex 为 .bin）
    new_filepath = filepath.rsplit('.rt.hex', 1)[0] + '.bin'

    # 重命名文件
    os.rename(filepath, new_filepath)

    print(f"Renamed '{filepath}' to '{new_filepath}'")