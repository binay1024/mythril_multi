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
from copy import copy
from mythril.support.my_utils import *
import logging

log = logging.getLogger(__name__)

DESCRIPTION = """

Check whether the account state is accesses after the execution of an external call
"""

CALL_LIST = ["CALL", "DELEGATECALL", "CALLCODE"]
STATE_READ_WRITE_LIST = ["SSTORE", "SLOAD", "CREATE", "CREATE2"]


class StateChangeCallsAnnotation(StateAnnotation):
    def __init__(self, call_state: GlobalState, user_defined_address: bool) -> None:
        self.call_state = call_state
        self.state_change_states = []  # type: List[GlobalState]
        self.user_defined_address = user_defined_address

    def __copy__(self):
        new_annotation = StateChangeCallsAnnotation(
            self.call_state, self.user_defined_address
        )
        new_annotation.state_change_states = self.state_change_states[:]
        return new_annotation
    # 原先 因为 没有多合约间 调用  所以 这里就是执行 当下合约环境的 to gas 等, 但是 如果是 从 sub 传回 main 我们要分析的 call 则是 sub 的, 
    def get_issue(
        self, global_state: GlobalState, detector: DetectionModule
    ) -> Optional[PotentialIssue]:

        if not self.state_change_states:
            return None
        constraints = Constraints()
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

    def _execute(self, state: GlobalState) -> None:
        issues = self._analyze_state(state)

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
                global_state.annotate(StateChangeCallsAnnotation(global_state, True))
            except UnsatError:
                global_state.annotate(StateChangeCallsAnnotation(global_state, False))
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
        if len(annotations) == 0 and op_code in STATE_READ_WRITE_LIST:
            return []
        # 如果
        if op_code in STATE_READ_WRITE_LIST:
            for annotation in annotations:
                annotation.state_change_states.append(global_state)

        # Record state changes following from a transfer of ether
        
        callable_sc = get_callable_sc_list(global_state)

        if op_code in CALL_LIST :
            value = global_state.mstate.stack[-3]  # type: BitVec
            if StateChangeAfterCall._balance_change(value, global_state):
                for annotation in annotations:
                    annotation.state_change_states.append(global_state)

        # Record external calls
        if op_code in CALL_LIST and callable_sc == []:
            StateChangeAfterCall._add_external_call(global_state)

        # Check for vulnerabilities
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
