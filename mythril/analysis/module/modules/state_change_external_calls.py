from mythril.analysis.potential_issues import (
    PotentialIssue,
    get_potential_issues_annotation,
)
from mythril.analysis.swc_data import REENTRANCY
from mythril.analysis.module.base import DetectionModule, EntryPoint
from mythril.laser.ethereum.state.constraints import Constraints
from mythril.laser.smt import symbol_factory, UGT, BitVec, Or
from mythril.laser.ethereum.state.global_state import GlobalState
from mythril.laser.ethereum.state.annotation import StateAnnotation
from mythril.analysis import solver
from mythril.exceptions import UnsatError
from typing import List, cast, Optional
from copy import copy, deepcopy
from mythril.support.my_utils import *
import logging

log = logging.getLogger(__name__)

DESCRIPTION = """

Check whether the account state is accesses after the execution of an external call
"""

CALL_LIST = ["CALL", "DELEGATECALL", "CALLCODE"]
STATE_READ_WRITE_LIST = ["SSTORE", "SLOAD", "CREATE", "CREATE2"]

# 可以 fork 但是需要重新赋值 global_state
class StateChangeCallsAnnotation(StateAnnotation):
    def __init__(self, call_state: GlobalState, user_defined_address: bool) -> None:
        self.call_state = call_state
        self.state_change_states = []  # type: List[GlobalState]
        self.user_defined_address = user_defined_address
    
    def __copy__(self):
        
        new_annotation = StateChangeCallsAnnotation(
            copy(self.call_state), self.user_defined_address
        )
        new_annotation.state_change_states = self.state_change_states[:]
        return new_annotation
    
    # 为了实现 deepcopy, 我们需要弄懂 global_state 在这里到底做了什么 发现
    # 在 get_transaction_sequence 涉及到 值的计算, 包括 global_state.tx_sequence
    # 用到了 global_state.world_state 的 starting balances 以及 account 的 地址
    # 另外 state_change_states 中 里面存储了 发生了触发特定规则的 global_state, 这个不需要 copy
    def __deepcopy__(self, memo):
        if id(self) in memo:
            return memo[id(self)]
        new_global_state = copy(self.call_state) # 主要是 get 到 mstate 所以 copy 就够了

        new_annotation = StateChangeCallsAnnotation(
            new_global_state, deepcopy(self.user_defined_address)
        )
        memo[id(self)] = new_annotation
        new_annotation.state_change_states = self.state_change_states[:]
        # 因为我发现啊, 这里的 global_state 毫无用处.
        # for global_state in self.state_change_states:
        #     new_annotation.state_change_states.append(global_state)
        return new_annotation
    # 注意! 这里单纯深拷贝就好 无需做什么关联, 反正就是用于值的计算的.
    # 这里的 global_state 和拥有这个 annotation 的 world_state 没啥关系!

    # 原先 因为 没有多合约间 调用  所以 这里就是执行 当下合约环境的 to gas 等, 但是 如果是 从 sub 传回 main 我们要分析的 call 则是 sub 的,
    # 这里用到的 globa_State 是触发了 read 和 write 的那些 
    def get_issue(
        self, global_state: GlobalState, detector: DetectionModule
    ) -> Optional[PotentialIssue]:

        if not self.state_change_states:
            return None
        constraints = Constraints()
        # 你如何确定 添加了之后 globa_state 的 mstate 不会再继续变化了的呀??? 
        # 在当下就应该执行了,而不是后期遇到 read write 之后 执行的
        # 出问题了, 就是 call_state 的这个时间点应该是 call 命令的那个时候的状态, 所以从 mstate 读出来应该是
        # gas 和 to 这种 但是这里明显不一样了
        gas = self.call_state.mstate.stack[-1]
        to = self.call_state.mstate.stack[-2]
        constraints += [
            UGT(gas, symbol_factory.BitVecVal(2300, 256)),
            Or(
                to > symbol_factory.BitVecVal(16, 256),
                to == symbol_factory.BitVecVal(0, 256),
            ),
        ]
        # 对于 main 来说 他的 to 已经指定了 sub 所以不可能是 攻击者
        if self.user_defined_address:
            constraints += [to == 0xDEADBEEFDEADBEEFDEADBEEFDEADBEEFDEADBEEF]

        try:
            solver.get_transaction_sequence(
                global_state, constraints + global_state.world_state.constraints
            )
        except UnsatError:
            print("State_change_call_get_issue constraint unsatisifiy")
            return None

        severity = "Medium" if self.user_defined_address else "Low"
        address = global_state.get_current_instruction()["address"]
        logging.debug(
            "[EXTERNAL_CALLS] Detected state changes at addresses: {}".format(address)
        )
        read_or_write = "Write to"
        if global_state.get_current_instruction()["opcode"] == "SLOAD":
            read_or_write = "Read of"
        address_type = "user defined" if self.user_defined_address else "fixed"
        description_head = "{} persistent state following external call".format(
            read_or_write
        )
        description_tail = (
            "The contract account state is accessed after an external call to a {} address. "
            "To prevent reentrancy issues, consider accessing the state only before the call, especially if the callee is untrusted. "
            "Alternatively, a reentrancy lock can be used to prevent "
            "untrusted callees from re-entering the contract in an intermediate state.".format(
                address_type
            )
        )

        return PotentialIssue(
            contract=global_state.environment.active_account.contract_name,
            function_name=global_state.environment.active_function_name,
            address=address,
            title="State access after external call",
            severity=severity,
            description_head=description_head,
            description_tail=description_tail,
            swc_id=REENTRANCY,
            bytecode=global_state.environment.code.bytecode,
            constraints=constraints,
            detector=detector,
        )


class StateChangeAfterCall(DetectionModule):
    """This module searches for state change after low level calls (e.g. call.value()) that
    forward gas to the callee."""

    name = "State change after an external call"
    swc_id = REENTRANCY
    description = DESCRIPTION
    entry_point = EntryPoint.CALLBACK
    pre_hooks = CALL_LIST + STATE_READ_WRITE_LIST
    
    # 遇到 call, read write 都会在 prehook 里面 触发这个 _execute
    # 遇到 call 之后他会 存入 当前 global_state, 然后开启新的 global_state 去执行那个合约的命令了. 
    # 一直到 遇到一个 无法 call 的 一个外部函数调用命令之后 开始 继续执行当前 global_state.pc ++ 这么开始走
    def _execute(self, state: GlobalState) -> None:
        # 对当下的 global_state 分析 生成一个
        issues = self._analyze_state(state)
        # 这个函数是 调用当时就对 当下的 globa_state 进行分析然后生成一个新的 potential_issue 对象返回 不涉及后续操作
        annotation = get_potential_issues_annotation(state)
        annotation.potential_issues.extend(issues)
    
    # if we can set the callee address to attacker return true
    # so when we call concrete external call here return false?
    @staticmethod
    def _add_external_call(global_state: GlobalState) -> None:
        gas = global_state.mstate.stack[-1]
        to = global_state.mstate.stack[-2]
        try:
            constraints = copy(global_state.world_state.constraints)
            solver.get_model(
                constraints
                + [
                    UGT(gas, symbol_factory.BitVecVal(2300, 256)),
                    Or(
                        to > symbol_factory.BitVecVal(16, 256),
                        to == symbol_factory.BitVecVal(0, 256),
                    ),
                ]
            )

            # Check whether we can also set the callee address as attacker
            try:
                constraints += [to == 0xDEADBEEFDEADBEEFDEADBEEFDEADBEEFDEADBEEF]
                solver.get_model(constraints)
                global_state.annotate(StateChangeCallsAnnotation(copy(global_state), True))
            except UnsatError:
                global_state.annotate(StateChangeCallsAnnotation(copy(global_state), False))
        except UnsatError:
            pass

    def _analyze_state(self, global_state: GlobalState) -> List[PotentialIssue]:

        if global_state.environment.active_function_name == "constructor":
            return []
        # 首先从 global 里面读出 StateChangeCallsAnnotation 类型的 annotation
        
        # 要检查 跨合约间 检测是否存在这种情况.
        annotations = cast(
            List[StateChangeCallsAnnotation],
            list(global_state.get_annotations(StateChangeCallsAnnotation)),
        )
        op_code = global_state.get_current_instruction()["opcode"]
        # 其次 如果 前面的 anotation 是 0 并且 当前命令属于 读写 那么返回
        # 先读写的情况 还没检测到 call 那种 适用于这种情况
        # 情况一
        if len(annotations) == 0 and op_code in STATE_READ_WRITE_LIST:
            return []
        # 如果 存在 annotation 并且 当前是 读写 storage 那么加入
        # 情况二
        if op_code in STATE_READ_WRITE_LIST:
            for annotation in annotations:
                annotation.state_change_states.append(copy(global_state))

        # Record state changes following from a transfer of ether
        
        # callable_sc = get_callable_sc_list(global_state)
        callable_sc = []
        # 如果 cunzai call 并且 balance 改变了 那么 存入当前全球环境
        # 情况三
        if op_code in CALL_LIST :
            value = global_state.mstate.stack[-3]  # type: BitVec
            if StateChangeAfterCall._balance_change(value, global_state):
                for annotation in annotations:
                    annotation.state_change_states.append(copy(global_state))
        # 兼容情况三
        # Record external calls
        if op_code in CALL_LIST and callable_sc == []:
            StateChangeAfterCall._add_external_call(global_state)

        # Check for vulnerabilities
        # 只要包含 StateChangeAfterCall 都会执行一遍
        vulnerabilities = []
        for annotation in annotations:
            if not annotation.state_change_states:
                continue
            issue = annotation.get_issue(global_state, self)
            if issue:
                vulnerabilities.append(issue)
        return vulnerabilities
    
    # check whether the value > 0 ? true : false 
    @staticmethod
    def _balance_change(value: BitVec, global_state: GlobalState) -> bool:
        if not value.symbolic:
            assert value.value is not None
            return value.value > 0

        else:
            constraints = copy(global_state.world_state.constraints)

            try:
                solver.get_model(
                    constraints + [value > symbol_factory.BitVecVal(0, 256)]
                )
                return True
            except UnsatError:
                return False


detector = StateChangeAfterCall()
