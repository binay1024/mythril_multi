import logging
import re
import os
from copy import copy, deepcopy
from typing import cast, Callable, List, Union, Tuple
from mythril.laser.ethereum.state.calldata import MixedSymbolicCalldata
from mythril.laser.ethereum.state.constraints import Constraints
from z3 import Model, sat, unsat, unknown
from mythril.laser.smt import Solver
from mythril.laser.smt import (
#     Extract,
#     Expression,
#     UDiv,
#     simplify,
#     Concat,
#     ULT,
#     UGT,
    BitVec,
#     is_false,
#     URem,
#     SRem,
#     If,
    Bool,
#     Not,
#     LShR,
#     UGE,
)
from mythril.laser.smt import symbol_factory


# from mythril.laser.ethereum.state.global_state import GlobalState

# from mythril.disassembler import asm
# from mythril.laser.ethereum.state.account import Account
# from mythril.laser.ethereum.state.world_state import WorldState

from mythril.ethereum.util import extract_version 
import platform
import solcx
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

bytesMAX = 320

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
    # 对于 没有参数的函数，他的 calldata应该是 0
    static_para_list = []
    dynamic_para_list = []
    if pure_paras == ['']:
        # print("function para is empty {}".format(sig_))
        return [], 0
    # 这个是处理每一个参数的东西
    for para in pure_paras:
        p = Paramet()
        p.type = TYPE_LIST.get(para, "unknown")
        p.size = TYPE_SIZE.get(para, 0)
        if p.size == 0:
            # print("warning, data size is 0 in build_calldata {}".format(para))
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

    # print("basicoffset is {}".format(basicOffset))

    
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
    # print("size is {}".format(calldata.size))
    if init_calldata is None:
        return calldata
    for (index, data) in enumerate(init_calldata,0):
        index = index * 32
        if type(data) == str:
            continue
        # data = f"{data:064x}"
        byte_list = [(data >> (8 *i)) & 0xff for i in range(31, -1, -1)]
        # print("Data is {}".format(byte_list))
        for i in range(index, index+32):
            ind = i - index
            calldata.assign_value_at_index(index= i, value=byte_list[ind])
    return calldata

def build_mixed_symbolic_data_for_msg(init_calldata, id, length):
    
    total_size = length + 4
    init_calldata = ["sig"] + init_calldata

    calldata = MixedSymbolicCalldata(tx_id=id, total_length=total_size)
    # print("size is {}".format(calldata.size))
    if init_calldata is None:
        return calldata
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

        # print("Data is {}".format(byte_list))
        for i in range(index, index+32):
            ind = i - index
            calldata.assign_value_at_index(index= i, value=byte_list[ind])
    return calldata

def mixed_calldata_init(initdata, id, length):
    calldata = MixedSymbolicCalldata(tx_id=id, calldata=initdata, total_length=length)
    return calldata

def get_version(file: str) -> str:
    file_data = None
    with open(file) as f:
        file_data = f.read()

    version = extract_version(file_data)
    if version is None:
        return os.environ.get("SOLC") or "solc"
    
    return version


def generate_signature(filepath:str):
    # solc --abi ./mythril/solidity_examples/ccs2023/AttackBridge/AttackBridgeV10.sol -o ./ast.json/AttackBridgeV10.json
    version = get_version(filepath)
    outpath = "/".join(filepath.split('/')[:-1])
    contractName = filepath.split('/')[-2]
    outfilepath = outpath+'/'+contractName+'.abi'
    # print("outfilepath is {}".format(outfilepath))

    if platform.system() == "Darwin":
        solcx.import_installed_solc()
    solcx.install_solc("v" + version)
    solcx.set_solc_version("v" + version)
    solc_abi = solcx.compile_files([filepath],output_values=["abi"], solc_version=version)
    # print(solc_abi)
    signatures = {}
    
    for contract, abi in solc_abi.items():
        # function level
        for function in abi["abi"]:
            if "inputs" not in function:
                continue

            paras = [ para["type"] for para in function["inputs"] ]

            if function['type'] == 'function':
                signature = function["name"] + "(" + ",".join(paras) + ")"
                signatures[function["name"]] = signature
            else:# 不是function 就是 construc or event 
                signature = function["type"] + "(" + ",".join(paras) + ")"
                # coma_new = len(signature.split(','))
                
                if function["type"] in signatures and signature == signatures[function["type"]]:
                    continue
                elif function["type"] in signatures:
                    signatures[signature] = signature
                else:
                    signatures[function["type"]] = signature

    # print("print sig")
    # print(signatures)
    # exit(0)
    return signatures    

    # cmd = [
    #     'solc', 
    #     '--abi', 
    #     filepath,
    #     '-o',
    #     outpath
    # ]

    # result = subprocess.run(
    #     cmd,
    #     text = True,
    #     stdout = subprocess.PIPE,
    #     stderr = subprocess.PIPE
    #     )

    # if result.returncode == 0:
    #     print("Signature get successful.")
    # else:
    #     print("Signature get failed.")
    # return outfilepath

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

def get_callable_sc_list(global_state):    
    callable_sc = []
    worldstate = global_state.world_state
    # 首先 不可以 call 自己，creator， sumbug， 
    act = symbol_factory.BitVecVal(int("0xAFFEAFFEAFFEAFFEAFFEAFFEAFFEAFFEAFFEAFFE", 16), 256)
    att = symbol_factory.BitVecVal(int("0xDEADBEEFDEADBEEFDEADBEEFDEADBEEFDEADBEEF", 16), 256)
    smg = symbol_factory.BitVecVal(int("0xAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", 16), 256)
    current_account_addr = global_state.environment.active_account.address
    except_accounts_addr = [act,smg,current_account_addr]

    # Tx_stack = global_state.transaction_stack
    # for tx, _ in Tx_stack:
    #     acc_addr = tx.caller
    #     if (acc_addr != att) and (not acc_addr in except_accounts_addr):
    #         except_accounts_addr.append(acc_addr)
    # 除了 攻击者合约，调用过的合约不再重复调用

    # if global_state.environment.active_account.address != att:
    #     callable_sc.append(worldstate.accounts[0xDEADBEEFDEADBEEFDEADBEEFDEADBEEFDEADBEEF])
    
    # print("start to print accounts")
    for addr,sc in worldstate.accounts.items():
        if addr in except_accounts_addr:
            continue
        callable_sc.append(sc)
        # print("add callable sc")
    return callable_sc

# 比较balances和 每个 account的 storage
# def check_worldstate_change(worldstate_old, worldstate_new):
#     acc_ = worldstate_old._accounts.get(0x901d12ebe1b195e5aa8748e62bd7734ae19b51f,None)
#     new_acc = worldstate_new._accounts.get(0x901d12ebe1b195e5aa8748e62bd7734ae19b51f,None)
#     if acc_ is None or new_acc is None:
#         return False
#     # print("check change 1")
#     s = Solver()
#     # s.add(new_balance.raw != old_balance.raw)
#     # try:
#     #     cond2 = old_balance != new_balance
#     # except:
#     #     print("balance error")
#     try:
        
#             # 对于 acc来说 我们比较 acc.storage
#             # new_s = new_acc.storage._standard_storage.raw
#             # old_s = acc.storage._standard_storage.raw
#             # cond1 = new_s!= old_s
#             # c2 = cond1
#         new_b = new_acc._balances[new_acc.address]
#         print(new_b)
#         # print(acc_._balances)
#         # exit(0)
#         old_b = acc_._balances[acc_.address]
#         print(old_b)
#         print("compare acc {} new_b old b {} vs {}".format(acc_.contract_name, new_b, old_b))
#         s.add(new_b != old_b)
#         new_kset = new_acc.storage.keys_set
#         old_kset = acc_.storage.keys_set
#         a = new_kset + old_kset
#         if len(new_kset) != len(old_kset):
#             print("warning, account storage key set changes")
#         for key_ in a:
#             s.add(new_acc.storage.printable_storage.get(key_,0) != new_acc.storage.printable_storage.get(key_,0))
#             print("compare new storage as key {}".format(key_,new_acc.storage.printable_storage.get(key_,0), new_acc.storage.printable_storage.get(key_,0)))
#     except:
#         print("s.add problem")
        
#     # 收集完 各自 account的配对， 但凡有一个
#     s.set_timeout(1000)
#     result = s.check()
#     # print("check change 2")
#     if result == unsat:
#         print("world_state not change")
#         return True
#     elif result == unknown:
#         print("warning, cannot calculate world_state change or not")
#         return False
#     else:
#         print("world_state change")
#         return False
def check_worldstate_change(worldstate_old, worldstate_new):
    old_balance = worldstate_old.balances
    new_balance = worldstate_new.balances
    
    s = Solver()
    # s.add(new_balance.raw != old_balance.raw)
    try:
        cond2 = old_balance == new_balance
    except:
        print("balance error")
    try:
        s.add(Bool(cond2))
    except:
        print("add balance error")

    old_accounts = worldstate_old._accounts
    new_accounts = worldstate_new._accounts
    for addr, acc in old_accounts.items():
        new_acc = new_accounts.get(addr,None)
        if new_acc is None:
            # 有变化
            return False
        # 对于 acc来说 我们比较 acc.storage
        cond1 = True
        # cond2 = True
        try:
            new_ = new_acc.storage._standard_storage.raw
            old_ = acc.storage._standard_storage.raw
            cond1 = new_== old_
        except:
            print("storage error")
        
        try:
            # print(Bool(cond1).raw)
            # print(Bool(cond2).raw)
            s.add(Bool(cond1))
        except:
            print("s.add problem")
    

    # 收集完 各自 account的配对， 但凡有一个
    s.set_timeout(600)
    result = s.check()
    if result == unsat:
        # print("world_state change")
        return False
    elif result == unknown:
        print("warning, cannot calculate world_state change or not")
        return True
    else:
        print("world_state not change")
        return True