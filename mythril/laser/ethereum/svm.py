"""This module implements the main symbolic execution engine."""
import logging
from collections import defaultdict
from copy import copy, deepcopy
from datetime import datetime, timedelta
import random
from typing import Callable, Dict, DefaultDict, List, Tuple, Optional, cast

from mythril.support.opcodes import OPCODES
# from mythril.analysis.potential_issues import check_potential_issues
from mythril.analysis.solver import get_transaction_sequence
from mythril.laser.execution_info import ExecutionInfo
from mythril.laser.ethereum.cfg import NodeFlags, Node, Edge, JumpType
from mythril.laser.ethereum.evm_exceptions import InvalidInstruction, StackUnderflowException, VmException
from mythril.laser.ethereum.instructions import Instruction
from mythril.laser.ethereum.instruction_data import get_required_stack_elements
from mythril.laser.plugin.signals import PluginSkipWorldState, PluginSkipState
from mythril.laser.ethereum.state.global_state import GlobalState

from mythril.laser.ethereum.state.world_state import WorldState
from mythril.laser.ethereum.strategy.basic import DepthFirstSearchStrategy
from mythril.laser.ethereum.strategy.constraint_strategy import DelayConstraintStrategy
from abc import ABCMeta
from mythril.laser.ethereum.time_handler import time_handler
from mythril.laser.ethereum.state.calldata import ConcreteCalldata, SymbolicCalldata,MixedSymbolicCalldata
from mythril.analysis import solver
from mythril.exceptions import UnsatError, SolverTimeOutException
from mythril.support.my_utils import check_worldstate_change
from mythril.laser.ethereum.transaction import (
    ContractCreationTransaction,
    MessageCallTransaction,
    TransactionEndSignal,
    TransactionStartSignal,
    execute_sub_contract_creation,
    execute_contract_creation,
    execute_message_call,
    tx_id_manager,
)
from mythril.laser.smt import symbol_factory, UGT, BitVec
from mythril.support.support_args import args

# from mythril.mythril.mythril_disassembler import MythrilDisassembler
from mythril.solidity.soliditycontract import EVMContract

log = logging.getLogger(__name__)


class SVMError(Exception):
    """An exception denoting an unexpected state in symbolic execution."""

    pass


class LaserEVM:
    """The LASER EVM.

    Just as Mithril had to be mined at great efforts to provide the
    Dwarves with their exceptional armour, LASER stands at the heart of
    Mythril, digging deep in the depths of call graphs, unearthing the
    most precious symbolic call data, that is then hand-forged into
    beautiful and strong security issues by the experienced smiths we
    call detection modules. It is truly a magnificent symbiosis.
    """

    def __init__(
        self,
        dynamic_loader=None,
        max_depth=float("inf"),
        execution_timeout=120,
        create_timeout=10,
        strategy=DepthFirstSearchStrategy,
        transaction_count=2,
        requires_statespace=True,
        iprof=None,
        use_reachability_check=True,
        beam_width=None,
    ) -> None:
        """
        Initializes the laser evm object

        :param dynamic_loader: Loads data from chain
        :param max_depth: Maximum execution depth this vm should execute
        :param execution_timeout: Time to take for execution
        :param create_timeout: Time to take for contract creation
        :param strategy: Execution search strategy
        :param transaction_count: The amount of transactions to execute
        :param requires_statespace: Variable indicating whether the statespace should be recorded
        :param iprof: Instruction Profiler
        """
        self.execution_info: List[ExecutionInfo] = []

        self.open_states: List[WorldState] = []
        self.total_states = 0
        self.dynamic_loader = dynamic_loader
        self.use_reachability_check = use_reachability_check

        self.work_list: List[GlobalState] = []
        self.strategy = strategy(self.work_list, max_depth, beam_width=beam_width)
        self.max_depth = max_depth
        self.transaction_count = transaction_count

        self.execution_timeout = execution_timeout or 0
        self.create_timeout = create_timeout or 0

        self.requires_statespace = requires_statespace
        if self.requires_statespace:
            self.nodes: Dict[int, Node] = {}
            self.edges: List[Edge] = []

        self.time: datetime = None
        self.executed_transactions: bool = False

        self.pre_hooks: DefaultDict[str, List[Callable]] = defaultdict(list)
        self.post_hooks: DefaultDict[str, List[Callable]] = defaultdict(list)

        self._add_world_state_hooks: List[Callable] = []
        self._execute_state_hooks: List[Callable] = []

        self._start_exec_trans_hooks: List[Callable] = []
        self._stop_exec_trans_hooks: List[Callable] = []

        self._start_sym_trans_hooks: List[Callable] = []
        self._stop_sym_trans_hooks: List[Callable] = []

        self._start_sym_exec_hooks: List[Callable] = []
        self._stop_sym_exec_hooks: List[Callable] = []

        self._start_exec_hooks: List[Callable] = []
        self._stop_exec_hooks: List[Callable] = []

        self._transaction_end_hooks: List[Callable] = []

        self.iprof = iprof
        self.instr_pre_hook: Dict[str, List[Callable]] = {}
        self.instr_post_hook: Dict[str, List[Callable]] = {}
        for op in OPCODES:
            self.instr_pre_hook[op] = []
            self.instr_post_hook[op] = []
        self.hook_type_map = {
            "start_execute_transactions": self._start_exec_trans_hooks,
            "stop_execute_transactions": self._stop_exec_trans_hooks,
            "add_world_state": self._add_world_state_hooks,
            "execute_state": self._execute_state_hooks,
            "start_sym_exec": self._start_sym_exec_hooks,
            "stop_sym_exec": self._stop_sym_exec_hooks,
            "start_sym_trans": self._start_sym_trans_hooks,
            "stop_sym_trans": self._stop_sym_trans_hooks,
            "start_exec": self._start_exec_hooks,
            "stop_exec": self._stop_exec_hooks,
            "transaction_end": self._transaction_end_hooks,
        }
        log.info("LASER EVM initialized with dynamic loader: " + str(dynamic_loader))

    def extend_strategy(self, extension: ABCMeta, **kwargs) -> None:
        self.strategy = extension(self.strategy, **kwargs)

    def sym_exec(
        self,
        world_state: WorldState = None,
        target_address: int = None,
        creation_code: str = None,
        contract_name: str = None,
        sub_contracts: Optional[List[EVMContract]] = None,
        sig:list[dict] = None,
    ) -> None:
        """Starts symbolic execution
        There are two modes of execution.
        Either we analyze a preconfigured configuration, in which case the world_state and target_address variables
        must be supplied.
        Or we execute the creation code of a contract, in which case the creation code and desired name of that
        contract should be provided.

        :param world_state The world state configuration from which to perform analysis
        :param target_address The address of the contract account in the world state which analysis should target
        :param creation_code The creation code to create the target contract in the symbolic environment
        :param contract_name The name that the created account should be associated with
        """
    # bytecode 여기까지 잘 받아옴
        pre_configuration_mode = target_address is not None
        scratch_mode = creation_code is not None and contract_name is not None
        if pre_configuration_mode == scratch_mode:
            print("Error: Symbolic execution started with invalid parameters")
            raise ValueError("Symbolic execution started with invalid parameters")

        log.debug("Starting LASER execution")
        for hook in self._start_sym_exec_hooks:
            hook()

        time_handler.start_execution(self.execution_timeout)
        self.time = datetime.now()

        if sub_contracts == []:
            sub_accounts = None
            sub_contracts = None

        if pre_configuration_mode:
            self.open_states = [world_state]
            log.info("Starting message call transaction to {}".format(target_address))
            self.execute_transactions(symbol_factory.BitVecVal(target_address, 256))

        elif scratch_mode:
            log.info("Starting contract creation transaction")
            
                
            if(len(self.open_states) != 0):
                print("Multi analyze mode")
                created_account = execute_contract_creation(
                    self, creation_code, contract_name, world_state = self.open_states[0], sig = sig[0],
                )
            else:
                print("Single analyze mode")
                if sig is None:
                    sigs = None
                else:
                    sigs = sig[0]
                created_account = execute_contract_creation(
                    self, creation_code, contract_name, world_state = world_state, sig = sigs,
                )
            if(len(self.open_states) > 1 or len(self.open_states) == 0):
                print("Warning, open_states more than 1 or is zero")
                
            if sub_contracts is not None:
                if sig is None:
                    sigs = None
                else:
                    sigs = sig[1:]

                sub_accounts = execute_sub_contract_creation(
                    self, contract_name="SUB", world_state=self.open_states[0], sub_contracts = sub_contracts, sig = sigs
                )
            # 这个时候 worldstate 里面不是最新状态了已经, open_state 里面的 world_state 的 account 是有值的, 
            # 但是 这里的现在的 world_state 里面account 里面木有任何代码, 所以我们不可以相信这个捏
            
            # print("main: ", created_account.code.bytecode)
            # print("sub: ", sub_accounts[0].code.bytecode if (sub_accounts is not None and sub_accounts!= []) else "Empty Sub Contract" ) 
            # exit(1)
            log.info(
                "Finished contract creation, found {} open states".format(
                    len(self.open_states)
                )
            )

            if len(self.open_states) == 0:
                log.warning(
                    "No contract was created during the execution of contract creation "
                    "Increase the resources for creation execution (--max-depth or --create-timeout) "
                    "Check whether the bytecode is indeed the creation code, otherwise use the --bin-runtime flag"
                )
            # if not self.open_states[0].accounts[0xDEADBEEFDEADBEEFDEADBEEFDEADBEEFDEADBEEF]:
                # print("cannot get attacker account error")
                # exit(0)
            attackBridge_addr = symbol_factory.BitVecVal(0xDEADBEEFDEADBEEFDEADBEEFDEADBEEFDEADBEEF, 256)
            accounts_ = self.open_states[0].accounts
            for (addr, acc) in accounts_.items():
                acc.set_balance(100000000000000000000)
            # self.execute_transactions(created_account.address)
            self.execute_transactions(attackBridge_addr)

        log.info("Finished symbolic execution")
        print("Finished symbolic execution")
        print("\n\n================ Print openstates call_chain ================")
        # for i in range(len(self.open_states)):
        #     world_stt = self.open_states[i]
        #     print("print {}th world_state`s call_chain".format(i))
        #     print(world_stt.transaction_sequence[-1].call_chain)
        #     print("----------------------------------------------------")
        
        for i in range(len(self.open_states)):
            print("++++++++++++++++++++ In {}th open_state ++++++++++++++++++++".format(i))
            
            tx = self.open_states[i].transaction_sequence[-1]
                
            print(tx.call_chain)
            fallback_record = ['AttackBridge', 'fallback']
            count = sum(1 for item in tx.call_chain if item[2] == fallback_record)
            print("fallback num is {}".format(count))
            if count >= 2:
                print("********************** Reentrancy Vulnerability found ***********************") 
            if count >=1 and self.check_cross(tx.call_chain):
                print("********************** May Cross Reentrancy Vulnerability found ***********************")

        print("\n\n================ Print openstates call_chain finish ================")
        if self.requires_statespace:
            log.info(
                "%d nodes, %d edges, %d total states",
                len(self.nodes),
                len(self.edges),
                self.total_states,
            )
        
        for hook in self._stop_sym_exec_hooks:
            hook()

    def execute_transactions(self, address) -> None:
        """This function helps runs plugins that can order transactions.
        Such plugins should set self.executed_transactions as True after its execution

        :param address: Address of the contract
        :return: None
        """
        for hook in self._start_exec_trans_hooks:
            hook()

        if self.executed_transactions is False:
            self._execute_transactions(address)

        for hook in self._stop_exec_trans_hooks:
            hook()

    def _execute_transactions(self, address):
        """This function executes multiple transactions on the address

        :param address: Address of the contract
        :return:
        """
        self.time = datetime.now()
        # 记得删除
        # self.transaction_count = 2
        for i in range(self.transaction_count):
            print("\n=========== Excute %d TX Loop!!!==========\n"%i)
            # 这句话决定了 如果你的 open_states 为空 那么不执行剩下的语句
            if len(self.open_states) == 0:
                break
            old_states_count = len(self.open_states)
            print("Now we have %d open states!!!"%old_states_count)
            for addr, acc in self.open_states[0].accounts.items():
                balance = acc.get_balance(addr)
                if balance.value is not None:
                    print("output acc {} balance: {}".format(addr, balance.value))
                
            if self.use_reachability_check:
                self.open_states = [
                    state
                    for state in self.open_states
                    if state.constraints.is_possible()
                ]
                prune_count = old_states_count - len(self.open_states)
                if prune_count:
                    log.info("Pruned {} unreachable states".format(prune_count))
            log.info(
                "Starting message call transaction, iteration: {}, {} initial states".format(
                    i, len(self.open_states)
                )
            ) 
            print("Starting message call transaction, iteration: %d, %d initial states"%(i,len(self.open_states)))
            # 这一步是根据 用户输入的 TX 数据 初始化 func_hashes 如果用户没有输入则是 None
            func_hashes = (
                args.transaction_sequences[i] if args.transaction_sequences else None
            )

            if func_hashes:
                for itr, func_hash in enumerate(func_hashes):
                    if func_hash in (-1, -2):
                        func_hashes[itr] = func_hash
                    else:
                        func_hashes[itr] = bytes.fromhex(hex(func_hash)[2:].zfill(8))

            # # 打钱轮
            # if i == 0:
            #     for hook in self._start_sym_trans_hooks:
            #         hook()
                
            #     main_addr = symbol_factory.BitVecVal(0x0901d12ebE1b195E5AA8748E62Bd7734aE19B51F, 256)
            #     print("Starting message call initial round transaction to: {}".format(main_addr.value))
            #     execute_message_call(self, main_addr, func_hashes=func_hashes, initial="init")

            #     for hook in self._stop_sym_trans_hooks:
            #         hook()
            # else:
                # 正常调用轮
            for hook in self._start_sym_trans_hooks:
                hook()
            print("Starting message call transaction to: {}".format(address.value))
            execute_message_call(self, address, func_hashes=func_hashes)

            for hook in self._stop_sym_trans_hooks:
                hook()

            print("Excute %d TX Loop finish!!!\noutput the call_chain"%i)
            for i in range(len(self.open_states)):
                print("++++++++++++++++++++ In {}th open_state ++++++++++++++++++++".format(i))
                
                tx = self.open_states[i].transaction_sequence[-1]
                    
                print(tx.call_chain)
                fallback_record = ['AttackBridge', 'fallback']
                count = sum(1 for item in tx.call_chain if item[2] == fallback_record)
                print("fallback num is {}".format(count))
                if count >= 2:
                    print("********************** Reentrancy Vulnerability found ***********************") 
                if count >=1 and self.check_cross(tx.call_chain):
                    print("********************** May Cross Reentrancy Vulnerability found ***********************")

        self.executed_transactions = True

    def check_cross(self, lst):
        # print(lst)
        groups = lst
        counter = 0
        temp = ""
        for group in groups:
            if 'MAIN' in group[-2]:
                if group[-1]=="REVERT":
                    continue
                if temp == "":
                    temp = group[-2][1]
                else:
                    if temp == group[-2][1]:
                        continue
                    else: # 找到了不一样的两个函数名
                        return True
        return False

    def _check_create_termination(self) -> bool:
        if len(self.open_states) != 0:
            return (
                self.create_timeout > 0
                and self.time + timedelta(seconds=self.create_timeout) <= datetime.now()
            )
        return self._check_execution_termination()

    def _check_execution_termination(self) -> bool:
        return (
            self.execution_timeout > 0
            and self.time + timedelta(seconds=self.execution_timeout) <= datetime.now()
        )
    # 执行 虚拟机 bytecode
    def exec(self, create=False, track_gas=False) -> Optional[List[GlobalState]]:
        """

        :param create:
        :param track_gas:
        :return:
        """
        final_states = []  # type: List[GlobalState]
        for hook in self._start_exec_hooks:
            hook()
        temp = 0
        for global_state in self.strategy:
            
            # if(len(self.work_list)>=1):
                # print("+++++++++++++ change to execute next path +++++++++++++++++")
                # pass
            
            # if global_state.environment.active_function_name == "delegatecall_a_delegatecall()" or global_state.environment.active_function_name == "callFunc()":
            
            # print("=========================")
            # print("current opcode is {}".format(global_state.environment.code.instruction_list[global_state.mstate.pc]))
            # if (global_state.current_transaction.id == "3"):
            #     print("transaction id is 3")
            #     print(global_state.environment.active_account.contract_name)
            
            # opcode = global_state.environment.code.instruction_list[global_state.mstate.pc]
            # if opcode["address"] == 471 and opcode["opcode"] == "ISZERO":
                # print("catch it")
            # opcode = global_state.environment.code.instruction_list[global_state.mstate.pc]
            # if opcode["address"] == 242 and opcode["opcode"] == "JUMPDEST":
                # print("reach true path")
            # if global_state.re_pc is not None:
                # print(global_state.re_pc)
            # if global_state.mstate.pc == 210:
                # print("210") # 210是 attacker里 attack中的某一位置。 attack函数地址是 215
            # print("current activate function is {}".format(global_state.environment.active_function_name))
            # print("current tx id is {}".format(global_state.current_transaction.id))
            # print("Print stack states ")
            # print(global_state.mstate.stack)
            # print("print memory")
            
            # print("memory size is {}".format(global_state.mstate.memory._msize))
            # for ind in range(global_state.mstate.memory._msize//32):
                # print("word {}: {}".format(ind, global_state.mstate.memory.get_word_at(ind*32)))
            # for wo_global in self.work_list:
            #     print(wo_global.mstate.stack)
            
            # print("current constraint is {}".format(global_state.world_state.constraints))
            # try:
            #     constraints = global_state.world_state.constraints
            #     solver.get_model(constraints)
            # except UnsatError:
            #     print("Warning !!!world_state unsatisfied")
            #     continue
            # except SolverTimeOutException:
            #     print("Warning !!!world_state Timeout")
            #     continue
            # if not (global_state.world_state.constraints.is_possible()):
            #     print("Warning !!!world_state unsatisfied")
            #     continue

            if len(self.work_list)!= temp:
                # print("now we have {} global state (path)!".format(len(self.work_list)+1))
                temp = len(self.work_list)

            # if create and self._check_create_termination():
            #     log.debug("Hit create timeout, returning.")
            #     print("Hit create timeout, returning.")
            #     return final_states + [global_state] if track_gas else None

            # if not create and self._check_execution_termination():
            #     log.debug("Hit execution timeout, returning.")
            #     print("Hit create timeout, returning.")
            #     return final_states + [global_state] if track_gas else None
            try:
                new_states, op_code = self.execute_state(global_state)
                
                # print("op code is {}".format(op_code))
            except NotImplementedError:
                log.debug("Encountered unimplemented instruction")
                print("Error Encountered unimplemented instruction")
                continue
            except:
                print("unkown error in svm")

            # if op_code == "JUMP":
            #     # print(op_code)
            #     # print("new_state is {}".format(len(new_states)))
            #     # print("")
            #     pass
            if type(new_states) != list:
                print("error found")
            temp = []
            if self.strategy.run_check() and (
                len(new_states) > 1 and random.uniform(0, 1) < args.pruning_factor
            ):
                
                for state in new_states:
                    if state.world_state.constraints.is_possible():
                        state.world_state.timestamp +=1
                        temp.append(state)
                    else:
                        print("constraint not satisify, drop path")
                        # print(state.world_state.constraints)
                new_states = temp
                # new_states = [
                #     state
                #     for state in new_states
                #     if state.world_state.constraints.is_possible()
                # ]
                # if len(new_states) >1:
                    # print("{} worklist added! now the worklist num is {}".format(len(new_states), len(self.work_list)+len(new_states)))
                
            self.manage_cfg(op_code, new_states)  # TODO: What about op_code is None?
            
            if new_states:
                self.work_list += new_states
            
            elif track_gas:
                final_states.append(global_state)
            else:
                pass
                # print("no new_states error")
            # 证明当我在某一个 work_list 里面修改 call_chain 的时候 其他的 worklist 路径中的值也会被改动
            
            self.total_states += len(new_states)

        for hook in self._stop_exec_hooks:
            hook()

        return final_states if track_gas else None

    def _add_world_state(self, global_state: GlobalState):
        """Stores the world_state of the passed global state in the open states"""

        # for hook in self._add_world_state_hooks:
        #     try:
        #         hook(global_state)
        #     except PluginSkipWorldState:
        #         print("catch PluginSkipWorldState exception!")
        #         # 原来这里设置的 return 是希望 如果发现 一路执行过来木有 call, staticcall, sstore 这种命令的话我们不管当前这个命令 让他直接返回
        #         # 否则 就会将这条 执行路径的 world_state 加入到 open_states里面 然后 tx 循环执行的时候就会执行这条路径.
        #         # return
        #         continue

        # self.open_states.append(deepcopy(global_state.world_state))
        # print("in addworld 1")
        new_state = global_state.world_state
        flag = False
        try:
            if self.open_states == []:
                flag = False
                # print("in add 3.3")
            else:
                for world_state_ in self.open_states:
                    # print("in 6")
                    f = check_worldstate_change(world_state_, new_state)
                    # print("in 7")
                    if f:
                        print("found same worldsate state, pass")
                        flag = True
                        break
                    # print("in add 3.4")
                # print("in addworld 2")
        except:
            # print("in addworld 3")
            print("match error in _add_world_state")
            flag = True

        if not flag:
            # print("in addworld 4")
            self.open_states.append(deepcopy(new_state))
            # if global_state.re_pc is not None:
            #     # print("in addworld 5")
            #     print("add new changed world state after reentrant, cross reentrancy")



    # 当 opcode 是 "INVALID"的时候处理, 或者 命令执行有问题的时候, 比如 dup4时候 stack 只有3个元素
    def handle_vm_exception(
        self, global_state: GlobalState, op_code: str, error_msg: str
    ) -> List[GlobalState]:
        _, return_global_state = global_state.transaction_stack.pop()
        print(" warning, In handle_vm_exception in svm.py")
        if return_global_state is None:
            # In this case we don't put an unmodified world state in the open_states list Since in the case of an
            #  exceptional halt all changes should be discarded, and this world state would not provide us with a
            #  previously unseen world state
            log.debug("Encountered a VmException, ending path: `{}`".format(error_msg))
            new_global_states = []  # type: List[GlobalState]
        else:
            # First execute the post hook for the transaction ending instruction
            self._execute_post_hook(op_code, [global_state])
            new_global_states = self._end_message_call(
                return_global_state, global_state, revert_changes=True, return_data=None
            )
        return new_global_states

    def execute_state(
        self, global_state: GlobalState
    ) -> Tuple[List[GlobalState], Optional[str]]:
        """Execute a single instruction in global_state.

        :param global_state:
        :return: A list of successor states.
        """
        # Execute hooks
        try:
            for hook in self._execute_state_hooks:
                hook(global_state)
        except PluginSkipState:
            print("error, return empty")
            return [], None

        instructions = global_state.environment.code.instruction_list
        try:
            op_code = instructions[global_state.mstate.pc]["opcode"]
        except IndexError:
            # self._add_world_state(global_state)
            print("[IndexError] warning, opcode indexError ********************************")
            
            return [], None

        if len(global_state.mstate.stack) < get_required_stack_elements(op_code):
            error_msg = (
                "Stack Underflow Exception due to insufficient "
                "stack elements for the address {}".format(
                    instructions[global_state.mstate.pc]["address"]
                )
            )
            print(error_msg)
            new_global_states = self.handle_vm_exception(
                global_state, op_code, error_msg
            )
            self._execute_post_hook(op_code, new_global_states)
            return new_global_states, op_code

        try:
            self._execute_pre_hook(op_code, global_state)
        except PluginSkipState:
            print("[execute prehook Error]  ********************************")
            return [], None

        try:
            new_global_states = Instruction(
                op_code,
                self.dynamic_loader,
                pre_hooks=self.instr_pre_hook[op_code],
                post_hooks=self.instr_post_hook[op_code],
            ).evaluate(global_state)

        except VmException as e:
            for hook in self._transaction_end_hooks:
                hook(
                    global_state,
                    global_state.current_transaction,
                    None,
                    False,
                )
            new_global_states = self.handle_vm_exception(global_state, op_code, str(e))

        except TransactionStartSignal as start_signal:
            #start_signal = (transactions, op_code, global_state)
            new_global_states = []
            index = 0
            # if start_signal.mode == "reenter":
            #     new_global_states.append(start_signal.global_state)
            #     self.work_list.clear()
            #     print("clear worklist")
            #     return new_global_states, start_signal.op_code
            for tx in start_signal.transaction:
                # step 1: 因为已经有了 TX 了, 利用 TX 生成 新的 global_stack 
                # step 2: 深拷贝 旧 GlobalState 然后放入新的 global_stack 中
                # 最后 再复制好 整个 Global_state 的情况下 给他 放入栈里
                # 这是用于存储现在caller 的 global_state
                # if not start_signal.global_state.world_state.constraints.is_possible():
                #     print("warning give up this TX")
                #     continue
                forked_caller_global_state = deepcopy(start_signal.global_state)
                
                #################下面是 进一步的处理, 我们希望 要提前为了 处理 revert 情况 做一些处理 ####   
                # fork 一下 caller的 world_state 给 callee
                forked_new_world_state = deepcopy(forked_caller_global_state.world_state)
                # assert(tx.id is not None, "Warning !! tx.id is None")
                next_transaction_id = tx_id_manager.get_next_tx_id()
                calldata_ = tx.get("call_data")
                calldata_total_length = calldata_.get("total_length") if calldata_ is not None else None
                calldata_data = calldata_.get("calldata") if calldata_ is not None else None
                constructor_arguments = MixedSymbolicCalldata(tx_id=next_transaction_id, calldata=calldata_data, total_length=calldata_total_length)

                if tx.get("type") == "crossreenter":
                    new_transaction = tx.get("transaction")
                    new_global_state = new_transaction.initial_global_state()
                    new_global_state.re_pc = ["cross", "cross"]
                elif tx.get("type") == "reenter":
                    new_transaction = tx.get("transaction")
                    new_global_state = new_transaction.initial_global_state()
                    re_pc = tx.get("re_pc")
                    new_global_state.re_pc = re_pc
                    
                elif tx.get("type") == "ContractCreationTransaction":
                    new_transaction = ContractCreationTransaction(
                        world_state=forked_new_world_state,
                        caller=forked_caller_global_state.environment.active_account.address,
                        code=tx.get("code"),
                        identifier=next_transaction_id,
                        call_data=constructor_arguments,
                        gas_price=forked_caller_global_state.environment.gasprice,
                        gas_limit=forked_caller_global_state.mstate.gas_limit,
                        origin=forked_caller_global_state.environment.origin,
                        call_value=tx.get("call_value"),
                        contract_address=tx.get("contract_address"),
                        txtype = "Internal_MessageCall",
                        fork=False,
                    )
                    new_global_state = new_transaction.initial_global_state()
                else:
                    # next_transaction_id = tx_id_manager.get_next_tx_id()
                    # 处于 某些 原因， 他在从 fallback出发调用 其他地方的时候 calldata 有些问题啊。。。。
                    # if forked_caller_global_state.environment.active_function_name == "fallback":
                    #     calldata = SymbolicCalldata(next_transaction_id+"_temp")
                    # else:
                    #     calldata = deepcopy(tx.call_data)
                    if tx.get("code_addr", None) is not None:
                        addr = tx.get("code_addr", None)[0]
                        code_ = forked_new_world_state._accounts[addr].code
                    else:
                        code_ = forked_new_world_state._accounts[tx.get("callee_account").address.value].code
                   
                    #
                    if tx.get("call_type", None) == "delegatecall":
                        callee_account = forked_new_world_state._accounts[tx.get("callee_account").address.value]
                        callee_account.storage = forked_caller_global_state.environment.active_account.storage
                        # keep sender, value and storage same
                        new_transaction = MessageCallTransaction(
                            world_state = forked_new_world_state,
                            gas_price = forked_caller_global_state.environment.gasprice,
                            gas_limit = tx.get("gas_limit"),
                            identifier = next_transaction_id,
                            origin = forked_caller_global_state.environment.origin,
                            caller = forked_caller_global_state.environment.active_account.address,
                            # caller = forked_caller_global_state.environment.sender,
                            # account 实际上是 caller的 account， balance， storage，然后 只有 code是 callee的 code
                            callee_account = forked_new_world_state._accounts[tx.get("callee_account").address.value],
                            code = code_,
                            # call_data = deepcopy(tx.call_data), # symbol
                            # 我这种行为算强行给他一个call_data了。。。
                            call_data = constructor_arguments,
                            # call_value = tx.get("call_value"),
                            call_value = forked_caller_global_state.environment.callvalue,
                            static = forked_caller_global_state.environment.static,
                            txtype = "Internal_MessageCall",
                            )
                        new_global_state = new_transaction.initial_global_state("delegatecall")
                    else:
                        new_transaction = MessageCallTransaction(
                            world_state = forked_new_world_state,
                            gas_price = forked_caller_global_state.environment.gasprice,
                            gas_limit = tx.get("gas_limit"),
                            identifier = next_transaction_id,
                            origin = forked_caller_global_state.environment.origin,
                            caller = forked_caller_global_state.environment.active_account.address,
                            callee_account = forked_new_world_state._accounts[tx.get("callee_account").address.value],
                            code=code_,
                            # call_data = deepcopy(tx.call_data), # symbol
                            # 我这种行为算强行给他一个call_data了。。。
                            call_data = constructor_arguments,
                            call_value = tx.get("call_value"),
                            static = forked_caller_global_state.environment.static,
                            txtype = "Internal_MessageCall",
                            )
                        new_global_state = new_transaction.initial_global_state()
                    
                
                    # 这一步才是负责与之前 global_state 的链接
                new_global_state.transaction_stack = forked_caller_global_state.transaction_stack + [(new_transaction, forked_caller_global_state)]
                    # 对于 prev TX来说 已经更新好了, 要更新 new tx的 caller function
                if tx.get("type") != "reenter":
                    new_global_state.current_transaction.call_chain[0][1][1] = forked_caller_global_state.environment.active_function_name
                
                if tx.get("type") =="reenter":
                    record = ["start",[start_signal.global_state.environment.active_account.contract_name,start_signal.global_state.environment.active_function_name+"RE"],["AttackBridge","fallback"],""]
                    new_global_state.current_transaction.call_chain.append(record)
                    new_global_state.current_transaction.call_chain[0][2][1] = new_global_state.current_transaction.call_chain[0][2][1]+"_RE"
                    new_global_state.current_transaction.call_chain[0][1][1] = "fallback_virtual"
                    new_global_state.current_transaction.call_chain[0][0] = "START_REENTRANT"
                    
                if new_global_state.re_pc is None and forked_caller_global_state.re_pc is not None:
                    new_global_state.re_pc = forked_caller_global_state.re_pc
                new_global_state.node = forked_caller_global_state.node
                if tx.get("type") !="crossreenter" and tx.get("type") !="reenter":
                    # # 要加上 call 对象的 匹配这个 constraint
                    if (start_signal.constraints is not None and start_signal.constraints != []) and tx.__class__.__name__ != "ContractCreationTransaction":
                        new_constraint = start_signal.constraints[index]
                        a = new_constraint[0]
                        b = new_constraint[1]
                        if type(a) == BitVec:
                            new_global_state.world_state.constraints.append(a == b)
                
                    
                # gaslimit_ = tx.get("gas_limit",0)
                # if not isinstance(gaslimit_, BitVec):
                #     gaslimit_ = cast(BitVec, gaslimit_)
                # new_global_state.world_state.constraints.append(UGT(gaslimit_, symbol_factory.BitVecVal(2300, 256)))

                # if not new_global_state.world_state.constraints.is_possible():
                #     print("warning ! after the global_state inint, constraint unsolveable !!")
                #     index += 1
                #     continue
                # print("\n======= Print forked caller stack ========== {}\n".format(forked_caller_global_state.mstate.stack))
                log.debug("Setup new transaction %s", new_global_state.current_transaction)
                print("Setup new transaction %s", new_global_state.current_transaction)
                new_global_states.append(new_global_state)
                index += 1
                if tx.get("type") == "reenter":
                    self.work_list.clear()
                    print("clear worklist")
                    break
            return new_global_states, start_signal.op_code
        
        # 因为在每次执行的时候只添加当前的 callfunction 所以, 当当前环境执行结束的时候需要将这次执行的记录传递给之前的环境 这样才能记录上
        except TransactionEndSignal as end_signal:
            # get caller state and tx from callee.global_state 
            (
                transaction,
                return_global_state,
            ) = end_signal.global_state.transaction_stack[-1]
            # 打印 约束条件们
            # calldata_exp = global_state.world_state.constraints.as_list
            # print(calldata_exp)
            # print("in except endsignal")            
            # if end_signal.end_type == "reenter":
            #     # 加到 EVM open_states 里面
            #     self._add_world_state(end_signal.global_state)
            #     return [], None
            # print("1")            
            for hook in self._transaction_end_hooks:
                hook(
                    end_signal.global_state,
                    transaction,
                    return_global_state,
                    end_signal.revert,
                )
            # 检查一下 返回来的 globa_state.world_state 是否存在问题, 
            # 检查一下 world_state 的 tx_transaction[-1].world_state 是否是同一个
            # print("2")
            if end_signal.global_state.world_state != end_signal.global_state.world_state.transaction_sequence[-1].world_state:
                print("Error +++++++++++++++++++ world_sate not match")

            # 要处理一下 call_chain的问题
            # print("3")
            callee_tx = end_signal.global_state.current_transaction
            callee_tx.call_chain[0][2][1] = end_signal.global_state.environment.active_function_name
            callee_tx.call_chain[0][3] = "REVERT" if end_signal.revert else "END"
            if end_signal.end_type == "reenter" and callee_tx.call_chain[0][3] != "REVERT":
                callee_tx.call_chain[0][3] = callee_tx.call_chain[0][3] + "_RE"
            # 情况一 结束 creation TX
            # from an EOA send a TX to a smartcontract case
            if return_global_state is None:
                # print("4")
                # print("END with EOA TX CASE: {} ***********".format(transaction))
                
                # 对于 callee是新的， 所以没什么好做的，但是对于 caller 需要定义一个 index_来标记自己现在的 index 在哪里 返回的时候要更新这个
                
                
                
                # end_signal.global_state.current_transaction.call_chain[-1][1] = caller_record
                # 如果 不是 revert 那么 返回 漏洞相关的 potentialIssues
                if (
                    not isinstance(transaction, ContractCreationTransaction)
                    or transaction.return_data
                ) and not end_signal.revert:
                   
                    # 先执行一下当前路径是否存在 issue 这种
                    # check_potential_issues(end_signal.global_state)
                    try:
                        transaction_sequence = get_transaction_sequence(
                            end_signal.global_state, end_signal.global_state.world_state.constraints
                            )
                    except UnsatError:
                        print("global_state constraints solve failed!")
                        return [], None
                    print("[Good!!] global_state constraints get solved passed!")
                    end_signal.global_state.world_state.node = global_state.node
                    # 加到 EVM open_states 里面
                    self._add_world_state(end_signal.global_state)
                # if (transaction.type == "EOA_MessageCall"):


                # 不论是不是 revert 结束的情况 那么 因为状态回滚 返回的新世界状态为 0
                new_global_states = []
                
            # 情况二 结束 MessageCall TX
            # from an smartcontract send a TX to a smartcontract case, end internal messageTX
            # 这里 应该传回 annotations 
            else:
                # print("5")
                # print("END WITH Internal MessageCALLTX: {} **************************".format(transaction))
                return_global_state = deepcopy(return_global_state)
                # First execute the post hook for the transaction ending instruction
                self._execute_post_hook(op_code, [end_signal.global_state])
                    # [合约名，函数名]
                
                
                # 每个 callee 回去之前补满 callee的 call_chain 然后 加到 caller的 call_chain后面
                # 反正每次 补充的时候都是从 callee的 头部开始确认, 我只需要确认 每个 tx的 第一个是自己就行
                # if len(callee_tx.call_chain) > 1:
                #     callee_tx.call_chain[0][3] = "REVERT" if end_signal.revert else "END"
                # else:
                #     callee_tx.call_chain[-1][3] = "REVERT" if end_signal.revert else "END"

                return_global_state.current_transaction.call_chain += callee_tx.call_chain                    
                # if (not end_signal.revert) and end_signal.end_type == "reenter" and end_signal.global_state.re_pc is not None and end_signal.global_state.re_pc[0] == "cross":
                #     print("check worldstate change or not")
                #     flag = False
                #     try:
                #         if end_signal.global_state.world_state.old_worldstate is None:
                #             print("warning, lack old_world_state")
                #         else:
                #             if not check_worldstate_change(end_signal.global_state.world_state, end_signal.global_state.world_state.old_worldstate):
                #                 print("worldsate state change ")
                #                 flag = True
                #     except:
                #         print("match error in _add_world_state")
                #         flag = True

                #     if flag:
                #     #     self.open_states.append(new_state)
                #         print("find cross function reentrancy")
                    
               
                
                # Propagate annotations
                # new_annotations = [
                #     annotation
                #     for annotation in global_state.annotations
                #     if annotation.persist_over_calls  # IssueAnnotation True, StateAnotation False, TraceAnotation True, MutationAnotation Ture. 
                # ]
                # modified 06.20 kevin
                # 如果不是 revert 情况
                if not end_signal.revert and end_signal.end_type != "reenter":
                    # 正常结束 messagecallTX 处理 call_chain
                    
                    new_annotations = end_signal.global_state.annotations
                    # 加上 annotation
                    return_global_state.add_annotations(new_annotations)
                    # 更新 world_state, 尤其是 constraint
                    return_global_state.update_world_state(end_signal.global_state)
                    # print("End Transaction with MessageTX Normally: {}".format(end_signal.global_state.current_transaction))
                    # print("call_chain is {}".format(end_signal.global_state.world_state.transaction_sequence[-1].call_chain))
                    return_global_state.world_state.timestamp = end_signal.global_state.world_state.timestamp
                # 如果是 revert 要不要给 revert的那个 constraint 一个 Not 公式 然后 还回去。
                else:
                    pass
                    # print("End Transaction with Revert: {}".format(end_signal.global_state.current_transaction))
                    # print("call_chain is {}\n".format(end_signal.global_state.world_state.transaction_sequence[-1].call_chain))
                
                revert_changes = end_signal.end_type
                
                # print("6")
                new_global_states = self._end_message_call(
                    return_global_state,
                    global_state,
                    revert_changes=revert_changes,
                    return_data=end_signal.global_state.current_transaction.return_data,
                )
                # print(end_signal.global_state.accounts[51421440056055728346017419001665401074216449311].storage[0])
                # print(end_signal.global_state.accounts[0x51421440056055728346017419001665401074216449311].storage[1])
        # 不论哪种结束情况 都会执行 这个句子
        self._execute_post_hook(op_code, new_global_states)

        return new_global_states, op_code

    
    # 在结束了 internal MessageTX的 时候 执行后处理操作
    def _end_message_call(
        self,
        return_global_state: GlobalState,
        global_state: GlobalState,
        revert_changes=None,
        return_data=None,
    ) -> List[GlobalState]:
        """

        :param return_global_state:
        :param global_state:
        :param revert_changes:
        :param return_data:
        :return:
        """
        # 加上 constraint还是替换?
        # return_global_state.world_state.constraints += (
        #     global_state.world_state.constraints
        # )
        
        # Resume execution of the transaction initializing instruction
        op_code = return_global_state.environment.code.instruction_list[return_global_state.mstate.pc]["opcode"]

        # Set execution result in the return_state of callee_global_state
        if return_global_state.last_return_data is None:
            print("warning! last_return_data.mem_out_off and size may be none")
            return_global_state.last_return_data = return_data
            # print("assign return data {}".format(return_data))

        elif return_data is None:
            print("warning, tx.returndata is None")
            pass
        else:
            return_global_state.last_return_data.return_data = return_data.return_data
            return_global_state.last_return_data.return_data_size = return_data.return_data_size

        return_global_state.mstate.min_gas_used += (
                    global_state.mstate.min_gas_used
                )
        return_global_state.mstate.max_gas_used += (
                    global_state.mstate.max_gas_used
                )

        # 执行下一个命令
        try:
            # Execute the post instruction handler
            new_global_states = Instruction(
                op_code,
                self.dynamic_loader,
                pre_hooks=self.instr_pre_hook[op_code],
                post_hooks=self.instr_post_hook[op_code],
            ).evaluate(return_global_state, post=True, end_type = revert_changes)
        except VmException:
            print("Warning !! end_message_exception catch VmException!!!!!!!!!!!!!!!!!!!!!!!!!")
            new_global_states = []
        except TransactionStartSignal as start_signal:
            print("Warning !! end_message_exception catch TransactionStartSignal!!!!!!!!!!!!!!!!!!!!!!!!!")
        except TransactionEndSignal as end_signal:
            print("Warning !! end_message_exception catch TransactionEndSignal!!!!!!!!!!!!!!!!!!!!!!!!!!!")

        # In order to get a nice call graph we need to set the nodes here
        for state in new_global_states:
            state.node = global_state.node

        return new_global_states

    def manage_cfg(self, opcode: str, new_states: List[GlobalState]) -> None:
        """

        :param opcode:
        :param new_states:
        """
        if opcode == "JUMP":
            assert len(new_states) <= 1
            for state in new_states:
                self._new_node_state(state)
        elif opcode == "JUMPI":
            assert len(new_states) <= 2
            for state in new_states:
                self._new_node_state(
                    state, JumpType.CONDITIONAL, state.world_state.constraints[-1]
                )
        elif opcode in ("SLOAD", "SSTORE") and len(new_states) > 1:
            for state in new_states:
                self._new_node_state(
                    state, JumpType.CONDITIONAL, state.world_state.constraints[-1]
                )
        elif opcode == "RETURN":
            for state in new_states:
                self._new_node_state(state, JumpType.RETURN)

        for state in new_states:
            state.node.states.append(state)

    def _new_node_state(
        self, state: GlobalState, edge_type=JumpType.UNCONDITIONAL, condition=None
    ) -> None:
        """

        :param state:
        :param edge_type:
        :param condition:
        """
        try:
            address = state.environment.code.instruction_list[state.mstate.pc][
                "address"
            ]
        except IndexError:
            print("error in new_node_state")
            return
        new_node = Node(state.environment.active_account.contract_name)
        old_node = state.node
        state.node = new_node
        new_node.constraints = state.world_state.constraints
        if self.requires_statespace:
            self.nodes[new_node.uid] = new_node
            self.edges.append(
                Edge(
                    old_node.uid, new_node.uid, edge_type=edge_type, condition=condition
                )
            )

        if edge_type == JumpType.RETURN:
            new_node.flags |= NodeFlags.CALL_RETURN
        elif edge_type == JumpType.CALL:
            try:
                if "retval" in str(state.mstate.stack[-1]):
                    new_node.flags |= NodeFlags.CALL_RETURN
                else:
                    new_node.flags |= NodeFlags.FUNC_ENTRY
            except StackUnderflowException:
                new_node.flags |= NodeFlags.FUNC_ENTRY

        environment = state.environment
        disassembly = environment.code
        if isinstance(
            state.world_state.transaction_sequence[-1], ContractCreationTransaction
        ):
            environment.active_function_name = "constructor"
        elif address in disassembly.address_to_function_name:
            # Enter a new function
            environment.active_function_name = disassembly.address_to_function_name[
                address
            ]
            new_node.flags |= NodeFlags.FUNC_ENTRY

            log.debug(
                "- Entering function "
                + environment.active_account.contract_name
                + ":"
                + new_node.function_name
            )
        elif address == 0:
            environment.active_function_name = "fallback"

        new_node.function_name = environment.active_function_name

    def register_hooks(self, hook_type: str, hook_dict: Dict[str, List[Callable]]):
        """

        :param hook_type:
        :param hook_dict:
        """
        if hook_type == "pre":
            entrypoint = self.pre_hooks
        elif hook_type == "post":
            entrypoint = self.post_hooks
        else:
            print(
                "Invalid hook type %s. Must be one of {pre, post}", hook_type
            )
            raise ValueError(
                "Invalid hook type %s. Must be one of {pre, post}", hook_type
            )

        for op_code, funcs in hook_dict.items():
            entrypoint[op_code].extend(funcs)

    def register_laser_hooks(self, hook_type: str, hook: Callable):
        """registers the hook with this Laser VM"""

        if hook_type in self.hook_type_map:
            self.hook_type_map[hook_type].append(hook)
        else:
            raise ValueError(f"Invalid hook type {hook_type}")

    def register_instr_hooks(self, hook_type: str, opcode: str, hook: Callable):
        """Registers instructions hooks from plugins"""
        if hook_type == "pre":
            if opcode is None:
                for op in OPCODES:
                    self.instr_pre_hook[op].append(hook(op))
            else:
                self.instr_pre_hook[opcode].append(hook)
        else:
            if opcode is None:
                for op in OPCODES:
                    self.instr_post_hook[op].append(hook(op))
            else:
                self.instr_post_hook[opcode].append(hook)

    def instr_hook(self, hook_type, opcode) -> Callable:
        """Registers the annoted function with register_instr_hooks

        :param hook_type: Type of hook pre/post
        :param opcode: The opcode related to the function
        """

        def hook_decorator(func: Callable):
            """Hook decorator generated by laser_hook

            :param func: Decorated function
            """
            self.register_instr_hooks(hook_type, opcode, func)

        return hook_decorator

    def laser_hook(self, hook_type: str) -> Callable:
        """Registers the annotated function with register_laser_hooks

        :param hook_type:
        :return: hook decorator
        """

        def hook_decorator(func: Callable):
            """Hook decorator generated by laser_hook

            :param func: Decorated function
            """
            self.register_laser_hooks(hook_type, func)
            return func

        return hook_decorator

    def _execute_pre_hook(self, op_code: str, global_state: GlobalState) -> None:
        """

        :param op_code:
        :param global_state:
        :return:
        """
        if op_code not in self.pre_hooks.keys():
            return
        for hook in self.pre_hooks[op_code]:
            hook(global_state)

    def _execute_post_hook(
        self, op_code: str, global_states: List[GlobalState]
    ) -> None:
        """

        :param op_code:
        :param global_states:
        :return:
        """
        if op_code not in self.post_hooks.keys():
            return

        for hook in self.post_hooks[op_code]:
            for global_state in global_states:
                try:
                    hook(global_state)
                except PluginSkipState:
                    global_states.remove(global_state)

    def pre_hook(self, op_code: str) -> Callable:
        """

        :param op_code:
        :return:
        """

        def hook_decorator(func: Callable):
            """

            :param func:
            :return:
            """
            if op_code not in self.pre_hooks.keys():
                self.pre_hooks[op_code] = []
            self.pre_hooks[op_code].append(func)
            return func

        return hook_decorator

    def post_hook(self, op_code: str) -> Callable:
        """

        :param op_code:
        :return:
        """

        def hook_decorator(func: Callable):
            """

            :param func:
            :return:
            """
            if op_code not in self.post_hooks.keys():
                self.post_hooks[op_code] = []
            self.post_hooks[op_code].append(func)
            return func

        return hook_decorator
