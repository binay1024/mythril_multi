"""This module contains a representation of the global execution state."""
from typing import Dict, Union, List, Iterable, TYPE_CHECKING

from copy import copy, deepcopy
from z3 import BitVec

from mythril.laser.smt import symbol_factory
from mythril.laser.ethereum.cfg import Node
from mythril.laser.ethereum.state.environment import Environment
from mythril.laser.ethereum.state.machine_state import MachineState
from mythril.laser.ethereum.state.annotation import StateAnnotation
# from mythril.analysis.module.modules.state_change_external_calls import StateChangeCallsAnnotation, StateAnnotation
if TYPE_CHECKING:
    from mythril.laser.ethereum.state.world_state import WorldState
    from mythril.laser.ethereum.transaction.transaction_models import (
        MessageCallTransaction,
        ContractCreationTransaction,
    )
# from mythril.analysis.potential_issues import PotentialIssuesAnnotation


class GlobalState:
    """GlobalState represents the current globalstate."""

    def __init__(
        self,
        world_state: "WorldState",
        environment: Environment,
        node: Node,
        machine_state=None,
        transaction_stack=None,
        last_return_data = None,
        annotations=None,
    ) -> None:
        """Constructor for GlobalState.

        :param world_state:
        :param environment:
        :param node:
        :param machine_state:
        :param transaction_stack:
        :param last_return_data:
        :param annotations:
        """
        self.node = node
        self.world_state = world_state
        self.environment = environment
        self.mstate = (
            machine_state if machine_state else MachineState(gas_limit=1000000000)
        )
        self.transaction_stack = transaction_stack if transaction_stack else []
        self.op_code = ""
        self.last_return_data = last_return_data
        self._annotations = annotations or []
        self.re_pc = None


    def add_annotations(self, annotations: List[StateAnnotation]):
        """
        Function used to add annotations to global state
        :param annotations:
        :return:
        """
        # IssueAnnotation.issue 里面的 不是个 list 呢好像
        # PotentialIssuesAnnotation.potential_issues 是一个 list 里面是一个个的 potential_issue
        prev_potential_issue = None
        for annotation in self._annotations:
            if annotation.__class__.__name__ == "PotentialIssuesAnnotation":
                prev_potential_issue = annotation
                break

        for annotation_ in annotations:
            if annotation_.__class__.__name__ == "PotentialIssuesAnnotation":
                if prev_potential_issue is not None:
                    print("print origin potentiaon issue {}".format(len(prev_potential_issue.potential_issues)))
                    for new_potential_issue in annotation_.potential_issues:
                    # prev_potential_issue.potential_issues+=annotation_.potential_issues
                        if new_potential_issue not in prev_potential_issue.potential_issues:
                            prev_potential_issue.potential_issues.append(new_potential_issue)
                            print("Add new potential issue")
                        else:
                            print("same new potential issue found, pass")
                            continue
            else:
                self._annotations.append(annotation_)
    
        # only for test 
        for annotation in self._annotations:
            if annotation.__class__.__name__ == "PotentialIssuesAnnotation":
                print("print after potentiaon issue {}".format(len(annotation.potential_issues)))
                break

    def __copy__(self) -> "GlobalState":
        """

        :return:
        """
        world_state = copy(self.world_state)
        # world_state.transaction_sequence = deepcopy(self.world_state.transaction_sequence)
        environment = copy(self.environment)
        mstate = deepcopy(self.mstate)
        transaction_stack = copy(self.transaction_stack)
        environment.active_account = world_state[environment.active_account.address]
        new_global_state = GlobalState(
            world_state,
            environment,
            self.node,
            mstate,
            transaction_stack=transaction_stack,
            last_return_data = self.last_return_data,
            annotations=[copy(a) for a in self._annotations],
        )
        new_global_state.re_pc = copy(self.re_pc)
        return new_global_state


    def __deepcopy__(self, memo=None) -> "GlobalState":
        """
        Deepcopy is much slower than copy, since it deepcopies constraints.
        :return:
        """
        if id(self) in memo:
            return memo[id(self)]
        # # 第一步 深度复制 world_state 得到 new_world_state 和 new_tx
        new_global_state = GlobalState(world_state=None, environment=None,node=None)
        memo[id(self)] = new_global_state
        ################################# transaction_stack setting #################################
        current_tx = self.transaction_stack[-1][0]
        prev_global_state = self.transaction_stack[-1][1]
        forked_current_tx = deepcopy(current_tx, memo)
        if prev_global_state is None:
            current_transaction_stack = [(forked_current_tx, None)]
        else:
            # forked_prev_global_state = deepcopy(prev_global_state,memo)
            forked_prev_global_state = prev_global_state
            current_transaction_stack = forked_prev_global_state.transaction_stack + [(forked_current_tx, forked_prev_global_state)]
        ################################# transaction_stack setting end #################################
        if current_transaction_stack is None:
            print("Error !!!!! None tx stack")
            exit(0)
        ###### 下面是 处理 最新的 当前 global_state 的情况###############
        # new_current_transaction = forked_current_tx
        ########### gemerate Environment with newTX ##########
        if forked_current_tx.code is not None:
            forked_code = forked_current_tx.code
        elif forked_current_tx.callee_account.code is not None:
            forked_code = forked_current_tx.callee_account.code
        elif self.environment.code is not None:
            forked_code = deepcopy(self.environment.code)
        else:
            print("Warning!! forked TX's code is None +++")
            forked_code = None
        #-----------------------------
        new_environment = Environment(
            active_account = forked_current_tx.callee_account,
            sender = forked_current_tx.caller,
            calldata = forked_current_tx.call_data,
            gasprice = forked_current_tx.gas_price,
            callvalue = forked_current_tx.call_value,
            origin = forked_current_tx.origin,
            basefee = forked_current_tx.base_fee,
            code = forked_code,
            static=forked_current_tx.static,
        )
        new_environment.address = deepcopy(self.environment.address)
        new_environment.active_function_name = deepcopy(self.environment.active_function_name)
        ########################################################
        ######### init global state with env ################
        new_global_state.world_state = forked_current_tx.world_state
        new_global_state.environment = new_environment
        new_global_state.node = copy(self.node)
        new_global_state.mstate = deepcopy(self.mstate)
        new_global_state.transaction_stack = current_transaction_stack
        new_global_state.last_return_data = deepcopy(self.last_return_data)
        new_global_state.world_state._annotations = []
        for a in self._annotations:
            new_annotation = deepcopy(a, memo)
            new_global_state.annotate(new_annotation)
            # new_global_state._annotations.append(new_annotation)
        ########################################################
        # check!
        new_global_state.re_pc = deepcopy(self.re_pc)
        if new_global_state.world_state != new_global_state.world_state.transaction_sequence[-1].world_state:
            print("ERROR !!!!!!!!!!!!!!!!! world_state not match \n\n\n")
        return new_global_state

    @property
    def accounts(self) -> Dict:
        """

        :return:
        """
        return self.world_state._accounts

    # TODO: remove this, as two instructions are confusing
    def get_current_instruction(self) -> Dict:
        """Gets the current instruction for this GlobalState.

        :return:
        """
        instructions = self.environment.code.instruction_list
        try:
            return instructions[self.mstate.pc]
        except IndexError:
            return {"address": self.mstate.pc, "opcode": "STOP"}

    @property
    def current_transaction(
        self,
    ) -> Union["MessageCallTransaction", "ContractCreationTransaction", None]:
        """

        :return:
        """
        # TODO: Remove circular to transaction package to import Transaction classes
        # 提取出 当前 tx
        try:
            return self.transaction_stack[-1][0]
        except IndexError:
            return None

    @property
    def instruction(self) -> Dict:
        """

        :return:
        """
        return self.get_current_instruction()

    def new_bitvec(self, name: str, size=256, annotations=None) -> BitVec:
        """

        :param name:
        :param size:
        :return:
        """
        transaction_id = self.current_transaction.id
        return symbol_factory.BitVecSym(
            "{}_{}".format(transaction_id, name), size, annotations=annotations
        )

    def annotate(self, annotation: StateAnnotation) -> None:
        """

        :param annotation:
        """
        self._annotations.append(annotation)

        if annotation.persist_to_world_state:
            self.world_state.annotate(annotation)

    @property
    def annotations(self) -> List[StateAnnotation]:
        """

        :return:
        """
        return self._annotations

    def get_annotations(self, annotation_type: type) -> Iterable[StateAnnotation]:
        """Filters annotations for the queried annotation type. Designed
        particularly for modules with annotations:
        globalstate.get_annotations(MySpecificModuleAnnotation)

        :param annotation_type: The type to filter annotations for
        :return: filter of matching annotations
        """
        return filter(lambda x: isinstance(x, annotation_type), self.annotations)

    def update_world_state(self, c_global_state: "GlobalState"):

        # 更新 annotation
        # for annotate in c_global_state.world_state.annotations:
            # self.world_state.annotate(annotate)
        self.world_state._annotations = c_global_state.world_state._annotations
        # 更新 constraint
        self.world_state.constraints = c_global_state.world_state.constraints
        # 更新 accounts
        self.world_state._accounts = c_global_state.world_state._accounts
        # 更新 balances
        self.world_state.balances = c_global_state.world_state.balances
        # 更新 TX
        current_tx = c_global_state.world_state.transaction_sequence[-1]
        self.world_state.transaction_sequence[-1].callee_account = current_tx.world_state._accounts[self.world_state.transaction_sequence[-1].callee_account.address.value]
        assert(self.world_state.transaction_sequence[-1].callee_account is not None)

        # 更新 environment 的 activate_account
        self.environment.active_account = self.world_state.transaction_sequence[-1].callee_account

    def update_mstate(self,):
        self.mstate = MachineState(gas_limit=self.mstate.gas_limit, depth=self.mstate.depth, max_gas_used=self.mstate.max_gas_used,min_gas_used=self.mstate.min_gas_used)