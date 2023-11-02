import logging
import re
from copy import copy, deepcopy
from typing import cast, Callable, List, Union, Tuple
from mythril.laser.ethereum.state.calldata import MixedSymbolicCalldata
# from mythril.laser.smt import (
#     Extract,
#     Expression,
#     UDiv,
#     simplify,
#     Concat,
#     ULT,
#     UGT,
#     BitVec,
#     is_false,
#     URem,
#     SRem,
#     If,
#     Bool,
#     Not,
#     LShR,
#     UGE,
# )
# from mythril.laser.smt import symbol_factory


# from mythril.laser.ethereum.state.global_state import GlobalState

# from mythril.disassembler import asm
# from mythril.laser.ethereum.state.account import Account
# from mythril.laser.ethereum.state.world_state import WorldState



import json 
import subprocess

TYPE_LIST = {  
    "bool": "static", 
    "int": "static", 
    "uint": "static", 
    # "fixed",
    # "ufixed",
    "address": "static",
    "bytesM": "static",
     "bytes": "dynamic",
    "string":"dynamic",
    # "function", 
}

bytesMAX = 128

TYPE_SIZE = {
    "bool": 32,     # 静态
    "int": 32,      # 静态
    "uint": 32,     # 静态
    "bytes": bytesMAX,    # 动态
    "bytesM": 32,   # 静态
    "string":bytesMAX,    # 动态
    # "fixed",0
    # "ufixed",
    "address": 32,  # 静态
    # "function", 
}

################################################

class Paramet:
    def __init__(self) -> None:
        self.offset = 0
        self.length = None
        self.size = 0
        self.data = "data"
        self.type = None

def signature_parsing(sig_:str) -> list:
    # 首先 去掉空白字符
    sig_ = sig_.strip()

    # 找到 左括号和右括号的位置
    left_pare = sig_.find('(')
    righ_pare = sig_.find(')')

    if left_pare == -1 or righ_pare == -1:
        return []
    
    # 找到括号之后, 提取括号之间的内容
    parameters = sig_[left_pare+1:righ_pare]

    # 根据逗号分割参数并返回 
    return [para.strip() for para in parameters.split(',')]


def pure_sigs(para_list:list[str]) -> list:
    return [ pure_sig(para) for para in para_list]

def pure_sig(para:str):
    number = r'\d'
    return "bytesM" if 'bytes' in para and len(para) > 5 else re.sub(number, '',para)

def calcu_paras_size (pure_para_list:list[str]) -> list:
    # return [TYPE_SIZE.get(typ, 0) for typ in pure_para_list]
    return [ calcu_para_size(typ) for typ in pure_para_list]

def calcu_para_size (pure_para:str) -> int:
    return TYPE_SIZE.get(pure_para, 0)

def build_calldata(sig_:str):
    signature = signature_parsing(sig_)
    pure_paras = pure_sigs(signature)
    static_para_list = []
    dynamic_para_list = []
    for para in pure_paras:
        p = Paramet()
        p.type = TYPE_LIST.get(para, "unknown")
        p.size = TYPE_SIZE.get(para, 0)
        if p.size == 0:
            print("Error, data size is 0 in build_calldata")
            continue
        if p.type == "static":
            p.length = 0
            static_para_list.append(p)
        if p.type == "dynamic":
            # p.length = "length"
            p.data = "dy_data"
            p.length = p.size-32 # 288
            dynamic_para_list.append(p)
    # static_para_list = [para for para in para_object_list if para.type == "static"]
    # dynamic_para_list = [para for para in para_object_list if para.type == "dynamic"]
        
    # 这样的话整理出来每一个 calldata的 类型啥的都整理好了
    calldata_ = []
    total_length = 0

    # 先处理 Static parameter
    for para in static_para_list:
        calldata_.append(para.data)
        
    # 后处理 Dynamic parameter
    staticOffset = 0x20 * len(static_para_list)
    dynamicOffset = 0x20 * len(dynamic_para_list)
    basicOffset = staticOffset + dynamicOffset
    # print("basicOffset is {}".format(basicOffset))
    
    # 这是  处理 offset 部分
    for para in dynamic_para_list:
        para.offset = basicOffset
        calldata_.append(para.offset)
        basicOffset += para.size

    print("basicoffset is {}".format(basicOffset))

    
    # 然后按照para顺序 添加每一个 para 长度和数据
    for para in dynamic_para_list:
        calldata_.append(para.length)
        calldata_.append(para.data)
    
    
    return calldata_, basicOffset

def build_calldata_test():
    sig1 = "foo(uint256)"
    print("Test sig1 {}".format(sig1))
    print("Pure Parasize1: {}".format(calcu_paras_size(pure_sigs(signature_parsing(sig1)))))
    print("calldata is {}".format(build_calldata(sig1)))
    print()
    
    sig2 = "foo(bytes)"
    print("Test sig2 {}".format(sig2))
    print("Pure Parasize2: {}".format(calcu_paras_size(pure_sigs(signature_parsing(sig2)))))
    print("calldata is {}".format(build_calldata(sig2)))
    print()
    
    sig3 = "foo(uint256,bytes)"
    print("Test sig3 {}".format(sig3))
    print("Pure ParaSize3: {}".format(calcu_paras_size(pure_sigs(signature_parsing(sig3)))))
    print("calldata is {}".format(build_calldata(sig3)))
    print()
    
    sig4 = "attack(uint256,bytes)"
    print("Test sig4 {}".format(sig4))
    print("Pure ParaSize4: {}".format(calcu_paras_size(pure_sigs(signature_parsing(sig4)))))
    print("calldata is {}".format(build_calldata(sig4)))
    print()

    sig5 = "foo(uint256,bytes,address,string)"
    print("Test sig5 {}".format(sig5))
    print("Pure ParaSize5: {}".format(calcu_paras_size(pure_sigs(signature_parsing(sig5)))))
    print("calldata is {}".format(build_calldata(sig5)))
    print()

def build_mixed_symbolic_data(init_calldata, id, length):
    total_size = length
    calldata = MixedSymbolicCalldata(tx_id=id, total_length=total_size)
    for (index, data) in enumerate(init_calldata,0):
        index = index * 32
        if type(data) == str:
            continue
        # data = f"{data:064x}"
        byte_list = [(data >> (8 *i)) & 0xff for i in range(31, -1, -1)]
        print("Data is {}".format(byte_list))
        for i in range(index, index+32):
            ind = i - index
            calldata.assign_value_at_index(index= i, value=byte_list[ind])
    return calldata

def build_mixed_symbolic_data_for_msg(init_calldata, id, length):
    
    total_size = length + 4
    init_calldata = ["sig"] + init_calldata

    calldata = MixedSymbolicCalldata(tx_id=id, total_length=total_size)
    print("size is {}".format(calldata.size))
    temp = 0
    for (index, data) in enumerate(init_calldata, 0):

        if index == 0:
            pass
        elif index == 1:
            index = temp + 4

        elif data == "dy_data":
            index = temp + (bytesMAX - 32)
        else:
            index = temp + 32

        temp = index
        if type(data) == str:
            continue
        # data = f"{data:064x}"
        byte_list = [(data >> (8 *i)) & 0xff for i in range(31, -1, -1)]

        print("Data is {}".format(byte_list))
        for i in range(index, index+32):
            ind = i - index
            calldata.assign_value_at_index(index= i, value=byte_list[ind])
    return calldata

def mixed_calldata_init(initdata, id, length):
    calldata = MixedSymbolicCalldata(tx_id=id, calldata=initdata, total_length=length)
    return calldata

def generate_signature(filepath:str):
    # solc --abi ./mythril/solidity_examples/ccs2023/AttackBridge/AttackBridgeV10.sol -o ./ast.json/AttackBridgeV10.json
    outpath = "/".join(filepath.split('/')[:-1])
    contractName = filepath.split('/')[-2]
    outfilepath = outpath+'/'+contractName+'.abi'
    print("outfilepath is {}".format(outfilepath))
    cmd = [
        'solc', 
        '--abi', 
        filepath,
        '-o',
        outpath
    ]

    result = subprocess.run(
        cmd,
        text = True,
        stdout = subprocess.PIPE,
        stderr = subprocess.PIPE
        )

    if result.returncode == 0:
        print("Signature get successful.")
    else:
        print("Signature get failed.")
    return outfilepath

def extract_signature(ast_json_path):
    
    signatures = {}
    with open(ast_json_path, 'r') as file:
        ast = json.load(file)
        # function level
        for function in ast:
            if "inputs" not in function:
                continue

            paras = [ para["type"] for para in function["inputs"] ]

            if function['type'] == 'function':
                signature = function["name"] + "(" + ",".join(paras) + ")"
                signatures[function["name"]] = signature
            else:
                signature = function["type"] + "(" + ",".join(paras) + ")"
                signatures[function["type"]] = signature

    return signatures

# def get_callable_sc_list(global_state: GlobalState):    
#     callable_sc = []
#     # 首先 不可以 call 自己，creator， sumbug， 
     

#     # act = symbol_factory.BitVecVal(int("0xAFFEAFFEAFFEAFFEAFFEAFFEAFFEAFFEAFFEAFFE", 16), 256)
#     # att = symbol_factory.BitVecVal(int("0xDEADBEEFDEADBEEFDEADBEEFDEADBEEFDEADBEEF", 16), 256)
#     # smg = symbol_factory.BitVecVal(int("0xAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", 16), 256)
#     # current_account_addr = global_state.environment.active_account.address
#     # except_accounts_addr = [act,att,smg,current_account_addr]
#     # worldstate = global_state.world_state
#     # print("start to print accounts")
#     # for addr,sc in worldstate.accounts.items():
#     #     print(addr)
#     #     print(sc.contract_name)
#     #     if addr in except_accounts_addr:
#     #         continue
#     #     callable_sc.append(sc)
#     #     print("add callable sc")
    
#     # 我先在想摘除重复的 
#     # for sc in callable_sc:
#     #     for tx, global_st in global_state.transaction_stack:
#     #         print("Compare !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!")
#     #         print(sc.address.__str__())
#     #         print(tx.caller.__str__())
#     #         # 注意 如果是 EOA 的话 是一个符号可能是任何人 记得处理这个.
#     #         if "sender" in sc.address.__str__():
#     #             callable_sc.remove(sc)
#     #         if sc.address.__str__() == tx.caller.__str__():
#     #             print("remove reentrancy target")
#     #             callable_sc.remove(sc)
    
#     # if callable_sc!= []:
#     #     print("not a empty account {}".format(callable_sc))
#     # txlist = global_state.transaction_stack
#     # len_txlist = len(txlist)
#     # tx_, oldgs_ = txlist[-1]
    
#     # last_sender_tx_seq = []
#     # for i in range(len(txlist)):
#     #     tx, old_global_state = txlist[len_txlist-1-i]
#     #     origin = tx.origin.__str__()
#     #     caller = tx.caller.__str__()
#     #     callee = tx.callee_account.address.__str__()
#     #     last_sender_tx_seq.append((tx.origin, tx.caller, tx.callee_account))
#     #     pre_tx, pre_old_global_state = txlist[len_txlist-1-i-1]
#     #     if pre_tx.origin.__str__() != origin:
#     #         break
#     # # 上面代码提取出了最后一个 sender 的 相关 tx 序列 如果 callable_sc 存在于曾经的 callee 序列 那么可以停止了
#     # for origin, caller, callee in last_sender_tx_seq:
#     #     flag = False
#     #     for sc in callable_sc:
#     #         if callee.address.__str__() == sc.address.__str__():
#     #             callable_sc.remove(sc)
#     #             flag = True
#     #             break
#     #     if flag:
#     #         break
#     return callable_sc