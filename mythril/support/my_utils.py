import logging

from copy import copy, deepcopy
from typing import cast, Callable, List, Union, Tuple

from mythril.laser.smt import (
    Extract,
    Expression,
    UDiv,
    simplify,
    Concat,
    ULT,
    UGT,
    BitVec,
    is_false,
    URem,
    SRem,
    If,
    Bool,
    Not,
    LShR,
    UGE,
)
from mythril.laser.smt import symbol_factory


from mythril.laser.ethereum.state.global_state import GlobalState

from mythril.disassembler import asm
from mythril.laser.ethereum.state.account import Account
from mythril.laser.ethereum.state.world_state import WorldState


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