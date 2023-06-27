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


from mythril.laser.ethereum.state.account import Account
from mythril.laser.ethereum.state.world_state import WorldState


def get_callable_sc_list(global_state: GlobalState):    
    callable_sc = []
    act = symbol_factory.BitVecVal(int("0xAFFEAFFEAFFEAFFEAFFEAFFEAFFEAFFEAFFEAFFE", 16), 256)
    att = symbol_factory.BitVecVal(int("0xDEADBEEFDEADBEEFDEADBEEFDEADBEEFDEADBEEF", 16), 256)
    smg = symbol_factory.BitVecVal(int("0xAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", 16), 256)
    current_account_addr = global_state.environment.active_account.address
    except_accounts_addr = [act,att,smg,current_account_addr]
    worldstate = global_state.world_state
    for addr,sc in worldstate.accounts.items():
        if addr in except_accounts_addr:
            continue
        callable_sc.append(sc)
        
    txlist = global_state.transaction_stack
    len_txlist = len(txlist)
    tx_, oldgs_ = txlist[-1]
    
    last_sender_tx_seq = []
    for i in range(len(txlist)):
        tx, old_global_state = txlist[len_txlist-1-i]
        origin = tx.origin.__str__()
        caller = tx.caller.__str__()
        callee = tx.callee_account.address.__str__()
        last_sender_tx_seq.append((tx.origin, tx.caller, tx.callee_account))
        pre_tx, pre_old_global_state = txlist[len_txlist-1-i-1]
        if pre_tx.origin.__str__() != origin:
            break
        # 上面代码提取出了最后一个 sender 的 相关 tx 序列 如果 callable_sc 存在于曾经的 callee 序列 那么可以停止了
    for origin, caller, callee in last_sender_tx_seq:
            
        flag = False
        for sc in callable_sc:
                
            if callee.address.__str__() == sc.address.__str__():
                    
                callable_sc.remove(sc)
                flag = True
                break
        if flag:
            break
    return callable_sc