"""This module contains various utility for function signature parsing"""
import re

import pytest
from mythril.laser.ethereum.state.calldata import ConcreteCalldata, SymbolicCalldata, MixedSymbolicCalldata
from mythril.laser.smt import Solver, symbol_factory
from z3 import sat, unsat
from z3.z3types import Z3Exception
from mock import MagicMock
from mythril.support.my_utils import *


uninitialized_test_data = [
    ([]),  # Empty concrete calldata
    ([1, 4, 5, 3, 4, 72, 230, 53]),  # Concrete calldata
]



@pytest.mark.parametrize("starting_calldata", uninitialized_test_data)
def test_concrete_calldata_uninitialized_index(starting_calldata):
    # Arrange
    calldata = ConcreteCalldata(0, starting_calldata)

    # Act
    value = calldata[100]
    value2 = calldata.get_word_at(200)

    # Assert
    assert value == 0
    assert value2 == 0


def test_concrete_calldata_calldatasize():
    # Arrange
    calldata = ConcreteCalldata(0, [1, 4, 7, 3, 7, 2, 9])
    solver = Solver()

    # Act
    solver.check()
    model = solver.model()
    result = model.eval(calldata.calldatasize.raw)

    # Assert
    assert result == 7


def test_concrete_calldata_constrain_index():
    # Arrange
    calldata = ConcreteCalldata(0, [1, 4, 7, 3, 7, 2, 9])
    solver = Solver()

    # Act
    value = calldata[2]
    constraint = value == 3

    solver.add(constraint)
    result = solver.check()

    # Assert
    assert str(result) == "unsat"


def test_symbolic_calldata_constrain_index():
    # Arrange
    calldata = SymbolicCalldata(0)
    solver = Solver()

    # Act
    value = calldata[51]

    constraints = [value == 1, calldata.calldatasize == 50]

    solver.add(*constraints)

    result = solver.check()

    # Assert
    assert str(result) == "unsat"


def test_symbolic_calldata_equal_indices():
    calldata = SymbolicCalldata(0)

    index_a = symbol_factory.BitVecSym("index_a", 256)
    index_b = symbol_factory.BitVecSym("index_b", 256)

    # Act
    a = calldata[index_a]
    b = calldata[index_b]

    s = Solver()
    s.append(index_a == index_b)
    s.append(a != b)

    # Assert
    assert unsat == s.check()

##################################3

# TYPE_LIST = {  
#     "bool": "static", 
#     "int": "static", 
#     "uint": "static", 
#     # "fixed",
#     # "ufixed",
#     "address": "static",
#     "bytesM": "static",
#      "bytes": "dynamic",
#     "string":"dynamic",
#     # "function", 
# }


# TYPE_SIZE = {
#     "bool": 32,     # 静态
#     "int": 32,      # 静态
#     "uint": 32,     # 静态
#     "bytes": 64,    # 动态
#     "bytesM": 32,   # 静态
#     "string":64,    # 动态
#     # "fixed",
#     # "ufixed",
#     "address": 32,  # 静态
#     # "function", 
# }

# ################################################

# class Paramet:
#     def __init__(self) -> None:
#         self.offset = 0
#         self.length = None
#         self.size = 0
#         self.data = "data"
#         self.type = None

# def signature_parsing(sig_:str) -> list:
#     # 首先 去掉空白字符
#     sig_ = sig_.strip()

#     # 找到 左括号和右括号的位置
#     left_pare = sig_.find('(')
#     righ_pare = sig_.find(')')

#     if left_pare == -1 or righ_pare == -1:
#         return []
    
#     # 找到括号之后, 提取括号之间的内容
#     parameters = sig_[left_pare+1:righ_pare]

#     # 根据逗号分割参数并返回 
#     return [para.strip() for para in parameters.split(',')]


# def pure_sigs(para_list:list[str]) -> list:
#     return [ pure_sig(para) for para in para_list]

# def pure_sig(para:str):
#     number = r'\d'
#     return "bytesM" if 'bytes' in para and len(para) > 5 else re.sub(number, '',para)

# def calcu_paras_size (pure_para_list:list[str]) -> list:
#     # return [TYPE_SIZE.get(typ, 0) for typ in pure_para_list]
#     return [ calcu_para_size(typ) for typ in pure_para_list]

# def calcu_para_size (pure_para:str) -> int:
#     return TYPE_SIZE.get(pure_para, 0)

# def build_calldata(sig_:str):
#     signature = signature_parsing(sig_)
#     pure_paras = pure_sigs(signature)
#     static_para_list = []
#     dynamic_para_list = []
#     for para in pure_paras:
#         p = Paramet()
#         p.type = TYPE_LIST.get(para, "unknown")
#         p.size = TYPE_SIZE.get(para, 0)
#         if p.size == 0:
#             print("Error, data size is 0 in build_calldata")
#             continue
#         if p.type == "static":
#             p.length = 0
#             static_para_list.append(p)
#         if p.type == "dynamic":
#             # p.length = "length"
#             p.length = 32
#             dynamic_para_list.append(p)
#     # static_para_list = [para for para in para_object_list if para.type == "static"]
#     # dynamic_para_list = [para for para in para_object_list if para.type == "dynamic"]
        
#     # 这样的话整理出来每一个 calldata的 类型啥的都整理好了
#     calldata_ = []
    
#     # 先处理 Static parameter
#     for para in static_para_list:
#         calldata_.append(para.data)
    
#     # 后处理 Dynamic parameter
#     staticOffset = 0x20 * len(static_para_list)
#     dynamicOffset = 0x20 * len(dynamic_para_list)
#     basicOffset = staticOffset + dynamicOffset
#     # print("basicOffset is {}".format(basicOffset))
#     for para in dynamic_para_list:
#         para.offset = basicOffset
#         calldata_.append(para.offset)
#         basicOffset += p.size
    
#     # 然后按照para顺序 添加每一个 para 长度和数据
#     for para in dynamic_para_list:
#         calldata_.append(para.length)
#         calldata_.append(para.data)
    
#     return calldata_   

# def build_calldata_test():
#     sig1 = "foo(uint256)"
#     print("Test sig1 {}".format(sig1))
#     print("Pure Parasize1: {}".format(calcu_paras_size(pure_sigs(signature_parsing(sig1)))))
#     print("calldata is {}".format(build_calldata(sig1)))
#     print()
    
#     sig2 = "foo(bytes)"
#     print("Test sig2 {}".format(sig2))
#     print("Pure Parasize2: {}".format(calcu_paras_size(pure_sigs(signature_parsing(sig2)))))
#     print("calldata is {}".format(build_calldata(sig2)))
#     print()
    
#     sig3 = "foo(uint256,bytes)"
#     print("Test sig3 {}".format(sig3))
#     print("Pure ParaSize3: {}".format(calcu_paras_size(pure_sigs(signature_parsing(sig3)))))
#     print("calldata is {}".format(build_calldata(sig3)))
#     print()
    
#     sig4 = "attack(uint256,bytes)"
#     print("Test sig4 {}".format(sig4))
#     print("Pure ParaSize4: {}".format(calcu_paras_size(pure_sigs(signature_parsing(sig4)))))
#     print("calldata is {}".format(build_calldata(sig4)))
#     print()

#     sig5 = "foo(uint256,bytes,address,string)"
#     print("Test sig5 {}".format(sig5))
#     print("Pure ParaSize5: {}".format(calcu_paras_size(pure_sigs(signature_parsing(sig5)))))
#     print("calldata is {}".format(build_calldata(sig5)))
#     print()

# def build_mixed_symbolic_data(init_calldata, id,):
#     total_size = len(init_calldata) * 32
#     calldata = MixedSymbolicCalldata(tx_id=id, total_length=total_size)
#     for (index, data) in enumerate(init_calldata,0):
#         index = index * 32
#         if type(data) == str:
#             continue
#         # data = f"{data:064x}"
#         byte_list = [(data >> (8 *i)) & 0xff for i in range(31, -1, -1)]
#         print("Data is {}".format(byte_list))
#         for i in range(index, index+32):
#             ind = i - index
#             calldata.assign_value_at_index(index= i, value=byte_list[ind])
#     return calldata

# def build_mixed_symbolic_data_for_msg(init_calldata, id,):
    
#     total_size = len(init_calldata) * 32 + 4
#     init_calldata = ["sig"] + init_calldata

#     calldata = MixedSymbolicCalldata(tx_id=id, total_length=total_size)
#     print("size is {}".format(calldata.size))
#     for (index, data) in enumerate(init_calldata, 0):
#         if index == 0:
#             pass
#         elif index == 1:
#             index = 4
#         else:
#             index = (index-1) * 32 +4
#         if type(data) == str:
#             continue
#         # data = f"{data:064x}"
#         byte_list = [(data >> (8 *i)) & 0xff for i in range(31, -1, -1)]
#         print("Data is {}".format(byte_list))
#         for i in range(index, index+32):
#             ind = i - index
#             calldata.assign_value_at_index(index= i, value=byte_list[ind])
#     return calldata

# def mixed_calldata_init(initdata, id, length):
#     calldata = MixedSymbolicCalldata(tx_id=id, calldata=initdata, total_length=length)
#     return calldata

def mixed_calldata_test():
    # _init_calldata = ['data', 'data', 128, 192, 'length', 'data', 'length', 'data']
    sig5 = "attack(uint256,bytes)"
    _init_calldata =  build_calldata(sig5)
    id = 1
    calldata = build_mixed_symbolic_data_for_msg(_init_calldata, id)
    # _init_calldata = [0x11, 0x12, 0x13, 0x14]
    # calldata = mixed_calldata_init(_init_calldata, id, 8)
    
    # 输出出来看看
    # for i in range(256):
        # print("output calldata[{}] {}".format(i, calldata[i]))
    print("output calldata:\n {}".format(calldata[36:68]))
    print("output {}".format(calldata.get_word_at(36)))

if __name__ == "__main__":
    
    # build_calldata_test()
    mixed_calldata_test()

