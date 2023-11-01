"""This module contians the transaction models used throughout LASER's symbolic
execution."""

from copy import deepcopy
from z3 import ExprRef
from typing import Union, Optional
from mythril.support.support_utils import Singleton
from mythril.laser.ethereum.state.calldata import ConcreteCalldata
from mythril.laser.ethereum.state.account import Account
from mythril.laser.ethereum.state.calldata import BaseCalldata, SymbolicCalldata, MixedSymbolicCalldata
from mythril.laser.ethereum.state.return_data import ReturnData
from mythril.laser.ethereum.state.environment import Environment
from mythril.laser.ethereum.state.global_state import GlobalState
from mythril.laser.ethereum.state.world_state import WorldState
from mythril.laser.smt import symbol_factory, UGE, BitVec
import logging
from typing import (
    List,
    Optional,
    Union,
)
from copy import copy, deepcopy

log = logging.getLogger(__name__)


class TxIdManager(object, metaclass=Singleton):
    def __init__(self):
        self._next_transaction_id = 0

    def get_next_tx_id(self):
        self._next_transaction_id += 1
        return str(self._next_transaction_id)

    def restart_counter(self):
        self._next_transaction_id = 0

    def set_counter(self, tx_id):
        self._next_transaction_id = tx_id


tx_id_manager = TxIdManager()


class TransactionEndSignal(Exception):
    """Exception raised when a transaction is finalized."""

    def __init__(self, global_state: GlobalState, revert=None, end_type = None, call_chain: str = None) -> None:
        self.global_state = global_state
        self.revert = revert
        self.end_type = end_type
        self.call_chain = call_chain


class TransactionStartSignal(Exception):
    """Exception raised when a new transaction is started."""

    def __init__(
        self,
        transaction: List[Union["MessageCallTransaction", "ContractCreationTransaction"]],
        op_code: str,
        global_state: GlobalState,
        constraints=None,
    ) -> None:
        self.transaction = transaction
        self.op_code = op_code
        self.global_state = global_state
        self.constraints = constraints


class BaseTransaction:
    """Basic transaction class holding common data."""

    def __init__(
        self,
        world_state: WorldState,
        callee_account: Account = None,
        caller: ExprRef = None,
        call_data=None,
        identifier: Optional[str] = None,
        gas_price=None,
        gas_limit=None,
        origin=None,
        code=None,
        call_value=None,
        init_call_data=True,
        static=False,
        base_fee=None,
        fork = False,
        memo = None,
        txtype:str = None,
    ) -> None:
        # assert isinstance(world_state, WorldState)
        if world_state is None:
            self.world_state = None    
        else:
            self.world_state = world_state
        
        self.id = identifier if identifier is not None else tx_id_manager.get_next_tx_id()
        self.call_function = "fallback"
        # 记录 call graph
        self.call_chain = []
        self.gas_price = (
            gas_price
            if gas_price is not None
            else symbol_factory.BitVecSym(f"gasprice{identifier}", 256)
        )

        self.base_fee = (
            base_fee
            if base_fee is not None
            else symbol_factory.BitVecSym(f"basefee{identifier}", 256)
        )

        self.gas_limit = gas_limit

        self.origin = (
            origin
            if origin is not None
            else symbol_factory.BitVecSym(f"origin{identifier}", 256)
        )
        self.code = code

        self.caller = caller
        self.callee_account = callee_account
        
        if call_data is None and init_call_data:
            # self.call_data = SymbolicCalldata(self.id)  # type: BaseCalldata
            print("create init calldata")
            self.call_data = MixedSymbolicCalldata(tx_id=self.id)
        else:
            print("get calldata ")
            if isinstance(call_data, BaseCalldata):
                self.call_data = call_data
            else:
                self.call_data = MixedSymbolicCalldata(self.id)
            
        self.call_value = (
            call_value
            if call_value is not None
            else symbol_factory.BitVecSym(f"callvalue{self.id}", 256)
        )
        self.static = static
        self.return_data = None  # type: str
        # 给 TX 赋值
        self.type = txtype

    def initial_global_state_from_environment(self, environment, active_function):
        """

        :param environment:
        :param active_function:
        :return:
        """
        # Initialize the execution environment
        global_state = GlobalState(self.world_state, environment, None)
        # global_state = GlobalState(deepcopy(self.world_state), environment, None)
        global_state.environment.active_function_name = active_function

        sender = environment.sender
        receiver = environment.active_account.address
        value = (
            environment.callvalue
            if isinstance(environment.callvalue, BitVec)
            else symbol_factory.BitVecVal(environment.callvalue, 256)
        )

        global_state.world_state.constraints.append(
            UGE(global_state.world_state.balances[sender], value)
        )
        # 这里 在 append里面 通过 simplify 之后 简化了

        global_state.world_state.balances[receiver] += value
        global_state.world_state.balances[sender] -= value
        # if not global_state.world_state.constraints.is_possible():
        #     print("Constraint error !! ")
        #     exit(0)
        return global_state

    def initial_global_state(self) -> GlobalState:
        raise NotImplementedError

    def __str__(self) -> str:
        if self.callee_account is None or self.callee_account.address.symbolic is False:
            return "{} {} from {} to {:#42x}".format(
                self.__class__.__name__,
                self.id,
                self.caller,
                int(str(self.callee_account.address)) if self.callee_account else -1,
            )
        else:
            return "{} {} from {} to {}".format(
                self.__class__.__name__,
                self.id,
                self.caller,
                str(self.callee_account.address),
            )
    
        



class MessageCallTransaction(BaseTransaction):
    """Transaction object models an transaction."""

    def __init__(self, *args, **kwargs) -> None:
        super().__init__(*args, **kwargs)
    




    def __deepcopy__(self, memo) -> "MessageCallTransaction":
        if id(self) in memo:
            return memo[id(self)]

                # 生成一个 新的 dx
        new_creation_tx = MessageCallTransaction(
            world_state = None,
            identifier = (self.id),
        )
        memo[id(self)] = new_creation_tx
        
        
        new_creation_tx.__init__(
                    world_state = None,
                    callee_account = None,            
                    caller = deepcopy(self.caller), # 这是一个 address
                    call_data = deepcopy(self.call_data),
                    identifier = copy(self.id),
                    gas_price = deepcopy(self.gas_price),
                    gas_limit = deepcopy(self.gas_limit),  # block gas limit
                    origin = deepcopy(self.origin),
                    # code = self.code,
                    call_value = deepcopy(self.call_value),
                    base_fee = deepcopy(self.base_fee),
                    txtype = deepcopy(self.type),
                )
        new_world_state = deepcopy(self.world_state, memo)
        new_creation_tx.world_state = new_world_state
        callee_acc = new_world_state._accounts[self.callee_account.address.value]
        new_creation_tx.callee_account = callee_acc
        new_creation_tx.call_function = deepcopy(self.call_function)
        new_creation_tx.code = new_creation_tx.callee_account.code
        new_creation_tx.return_data = deepcopy(self.return_data)
        new_creation_tx.call_chain = deepcopy(self.call_chain)
        
        return new_creation_tx 
    #     return deepcopy(self)


    def initial_global_state(self) -> GlobalState:
        """Initialize the execution environment."""
        environment = Environment(
            self.callee_account,
            self.caller,
            self.call_data,
            self.gas_price,
            self.call_value,
            self.origin,
            self.base_fee,
            code=self.code if self.code is not None else self.callee_account.code,
            static=self.static,
        )
        start = ["START"]
        end = ["END"]
        if self.type == "EOA_MessageCall":
            caller_name = "EOA"
        else:    
            caller_name = ""
        caller_func = ""
        callee_name = environment.active_account.contract_name
        callee_func = []
        record = [start,[caller_name,caller_func],[callee_name,callee_func],end]
        
        self.call_chain = record
        # 加上 如果是 调用一个 可识别的 合约 我们加上 constraint
        return super().initial_global_state_from_environment(
            environment, active_function="fallback"
        )

    def end(self, global_state: GlobalState, return_data=None, end_type:str = None) -> None:
        """

        :param global_state:
        :param return_data:
        :param revert:
        """
        revert = False
        print("now in msTX end, the activate_function is: {}".format(global_state.environment.active_function_name))
        # memory return value 
        self.return_data = return_data

        function_name = global_state.environment.active_function_name
        if end_type == "REVERT":
            revert = True
            record = "TX-"+global_state.current_transaction.id.__str__()+"-"+global_state.environment.active_account.contract_name+"-"+function_name+"-"+"revert"
        else:
            record = "TX-"+global_state.current_transaction.id.__str__()+"-"+global_state.environment.active_account.contract_name+"-"+function_name
        # global_state.world_state.transaction_sequence[-1].call_chain.append(record)

        raise TransactionEndSignal(global_state, revert=revert, end_type = end_type, call_chain=record)


class ContractCreationTransaction(BaseTransaction):
    """Transaction object models an transaction."""

    def __init__(
        self,
        world_state: WorldState,
        caller: ExprRef = None,
        call_data=None,
        identifier: Optional[str] = None,
        gas_price=None,
        gas_limit=None,
        origin=None,
        code=None,
        call_value=None,
        contract_name=None,
        contract_address=None,
        base_fee=None,
        fork=False,
        memo = None,
        txtype = None,
    ) -> None:
        # 这里的 prev 只用于值得计算所以 fork 之后应该无需特别赋值操作
        
        self.prev_world_state = deepcopy(world_state, None) # 这时候希望 后续这个 prev_world_state 不改变所以 深拷贝
        # 如果不是 fork 而是从一开始总行的 Creation 那么给他 callee_account
        self.contract_address = (
            contract_address if isinstance(contract_address, int) else None
            )
        if not fork and world_state!=None:
            
            # 新 account 就被装入 原world_state里面了, 找到多个 account 出现的原因了. fork 也运行这里就会出问题.
            callee_account = world_state.create_account(
                0, concrete_storage=True, creator=caller.value, address=contract_address
            )
            callee_account.contract_name = contract_name or callee_account.contract_name
        else:
            callee_account = None
        
        # init_call_data "should" be false, but it is easier to model the calldata symbolically
        # and add logic in codecopy/codesize/calldatacopy/calldatasize than to model code "correctly"
        super().__init__(
            world_state=world_state,
            callee_account=callee_account,
            caller=caller,
            call_data=call_data,
            identifier=identifier,
            gas_price=gas_price,
            gas_limit=gas_limit,
            origin=origin,
            code=code,
            call_value=call_value,
            init_call_data=True,
            base_fee=base_fee,
            txtype = txtype,
        )

    def __deepcopy__(self, memo=None) -> "ContractCreationTransaction":
        
        if id(self) in memo:
            return memo[id(self)]
        new_creation_tx = ContractCreationTransaction(
                    world_state=None,
                    # world_state = new_creation_tx.world_state, 
                    identifier = copy(self.id),
                    gas_price = deepcopy(self.gas_price),
                    gas_limit = deepcopy(self.gas_limit),  # block gas limit
                    origin = deepcopy(self.origin),
                    code = self.code,
                    caller = deepcopy(self.caller),
                    contract_name = copy(self.callee_account.contract_name),
                    call_data = deepcopy(self.call_data),
                    call_value = deepcopy(self.call_value),
                    base_fee = deepcopy(self.base_fee),
                    fork = True,
                    memo=memo,
                )
        memo[id(self)] = new_creation_tx
        
        # 还需要解决 这里会导致 prev 和 world_state 指向同一个空间.
        new_creation_tx.prev_world_state =self.prev_world_state
        new_creation_tx.world_state = deepcopy(self.world_state, memo)
        new_creation_tx.callee_account = new_creation_tx.world_state._accounts[self.callee_account.address.value]
        new_creation_tx.call_function = deepcopy(self.call_function)
        # new_creation_tx.code = new_creation_tx.callee_account.code or self.code
        new_creation_tx.return_data = deepcopy(self.return_data)
        new_creation_tx.call_chain = deepcopy(self.call_chain)
        # copy 结束

        # if new_creation_tx.world_state != new_creation_tx.world_state.transaction_sequence[-1].world_state:
            # print("Error +++++++++++++++++++ world_sate not match")
        # if new_creation_tx != new_creation_tx.world_state.transaction_sequence[-1]:
            # print("Error +++++++++++++++++++ world_sate not match")
        return new_creation_tx
    
    # def __deepcopy__(self, memo=None) -> "ContractCreationTransaction":
        
    #     if id(self) in memo:
    #         return memo[id(self)]
    #     new_creation_tx = ContractCreationTransaction(
    #                 world_state=None,
    #                 # world_state = new_creation_tx.world_state, 
    #                 identifier = copy(self.id),
    #                 gas_price = deepcopy(self.gas_price),
    #                 gas_limit = deepcopy(self.gas_limit),  # block gas limit
    #                 origin = deepcopy(self.origin),
    #                 code = copy(self.code),
    #                 caller = deepcopy(self.caller),
    #                 contract_name = copy(self.callee_account.contract_name),
    #                 call_data = deepcopy(self.call_data),
    #                 call_value = deepcopy(self.call_value),
    #                 base_fee = deepcopy(self.base_fee),
    #                 fork = True,
    #                 memo=memo,
    #             )
    #     memo[id(self)] = new_creation_tx
        
    #     # 还需要解决 这里会导致 prev 和 world_state 指向同一个空间.
    #     new_creation_tx.prev_world_state =self.prev_world_state
    #     new_creation_tx.world_state = deepcopy(self.world_state, memo)
    #     new_creation_tx.callee_account = new_creation_tx.world_state._accounts[self.callee_account.address.value]
    #     new_creation_tx.call_function = deepcopy(self.call_function)
    #     # new_creation_tx.code = new_creation_tx.callee_account.code or deepcopy(self.code)
    #     new_creation_tx.return_data = deepcopy(self.return_data)
    #     # copy 结束

    #     # if new_creation_tx.world_state != new_creation_tx.world_state.transaction_sequence[-1].world_state:
    #         # print("Error +++++++++++++++++++ world_sate not match")
    #     # if new_creation_tx != new_creation_tx.world_state.transaction_sequence[-1]:
    #         # print("Error +++++++++++++++++++ world_sate not match")
    #     return new_creation_tx
    



    def initial_global_state(self) -> GlobalState:
        """Initialize the execution environment."""
        environment = Environment(
            active_account=self.callee_account,
            sender=self.caller,
            calldata=self.call_data,
            gasprice=self.gas_price,
            callvalue=self.call_value,
            origin=self.origin,
            basefee=self.base_fee,
            code=self.code,
        )
        start = ["START"]
        end = ["END"]
        if self.type == "EOA_MessageCall":
            caller_name = "EOA"
        else:
            caller_name = ""
        caller_func = ""
        callee_name = environment.active_account.contract_name
        callee_func = []
        record = [start,[caller_name,caller_func],[callee_name,callee_func],end]
        
        self.call_chain = record

        return super().initial_global_state_from_environment(
            environment, active_function="constructor"
        )
    # 结束之后再发 ENDsignal 之前 会做一些处理
    def end(self, global_state: GlobalState, return_data=None, end_type:str = None):
        """

        :param global_state:
        :param return_data:
        :param revert:
        """
        revert = False
        print("now in creation end, the activate_function is: {}".format(global_state.environment.active_function_name))
        function_name = global_state.environment.active_function_name
        if end_type == "REVERT":
            revert = True
            record = "TX-"+global_state.current_transaction.id.__str__()+"-"+global_state.environment.active_account.contract_name+"-"+function_name+"-"+"revert"
        else:
            record = "TX-"+global_state.current_transaction.id.__str__()+"-"+global_state.environment.active_account.contract_name+"-"+function_name
        # global_state.world_state.transaction_sequence[-1].call_chain.append(record)

        if return_data is None or return_data.size == 0:
            self.return_data = None
            raise TransactionEndSignal(global_state, revert=revert, end_type = end_type, call_chain=record)
        # 在这里 代码会被放入 active_account.code 里面
        global_state.environment.active_account.code.assign_bytecode(
            tuple(return_data.return_data)
        )
        global_state.environment.active_account.code.func_to_parasize = global_state.current_transaction.code.func_to_parasize
        # global_state.environment.active_account.code.func_to_parasize = global_state.current_transaction.code.func_to_parasize
        # print("print creation end info")
        # print(global_state.environment.active_account.code.function_name_to_address)
        # print("print creation end info 2")
        # global_state.environment.active_account.code.assign_func_parasize_post()
        # print(global_state.environment.active_account.code.func_to_parasize)
        return_data = str(hex(global_state.environment.active_account.address.value))
        #设置　TX.return_data
        self.return_data = ReturnData( return_data = return_data, return_data_size = len(return_data) // 2)
        # 最后保存的时候里面放的是 当前 active_account的地址值 可以 copy 或者 deepcopy
        assert global_state.environment.active_account.code.instruction_list != []

        raise TransactionEndSignal(global_state, revert=revert, end_type = end_type,call_chain=record)
