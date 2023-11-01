"""This module contains the class used to represent disassembly code."""
from mythril.ethereum import util
from mythril.disassembler import asm
from mythril.support.signatures import SignatureDB
# from mythril.laser.ethereum.state.global_state import GlobalState
from typing import Dict, List, Tuple
from mythril.laser.ethereum import util
from mythril.support.my_utils import build_calldata

class Disassembly(object):
    """Disassembly class.

    Stores bytecode, and its disassembly.
    Additionally it will gather the following information on the existing functions in the disassembled code:
    - function hashes
    - function name to entry point mapping
    - function entry point to function name mapping
    """

    def __init__(self, code: str, enable_online_lookup: bool = False, sig:dict = None) -> None:
        """

        :param code:
        :param enable_online_lookup:
        """
        self.bytecode = code
        if type(code) == str:
            self.instruction_list = asm.disassemble(util.safe_decode(code))
        else:
            self.instruction_list = asm.disassemble(code)
        self.func_hashes = []  # type: List[str]
        self.function_name_to_address = {}  # type: Dict[str, int]
        self.address_to_function_name = {}  # type: Dict[int, str]
        self.hash_to_function_name = {}     # type: Dict[int, str]
        self.func_to_parasize = {}          # type: Dict[str, int]
        self.enable_online_lookup = enable_online_lookup
        self.sig = sig
        print("sig is {}, type is {}".format(sig, type(sig)))
        self.assign_bytecode(bytecode=code)
        self.assign_func_parasize()
        print("print func_sig {}".format(self.func_to_parasize))
        



    def assign_bytecode(self, bytecode):
        self.bytecode = bytecode
        # open from default locations
        # control if you want to have online signature hash lookups
        signatures = SignatureDB(enable_online_lookup=self.enable_online_lookup)
        self.instruction_list = asm.disassemble(bytecode)
        # Need to take from PUSH1 to PUSH4 because solc seems to remove excess 0s at the beginning for optimizing
        jump_table_indices = asm.find_op_code_sequence(
            [("PUSH1", "PUSH2", "PUSH3", "PUSH4"), ("EQ",)], self.instruction_list
        )

        for index in jump_table_indices:
            function_hash, jump_target, function_name = get_function_info(
                index, self.instruction_list, signatures
            )
            self.func_hashes.append(function_hash)
            
            if jump_target is not None and function_name is not None:
                self.function_name_to_address[function_name] = jump_target
                print("Function : {} with hash {} , address {} found".format(function_name, function_hash, jump_target))
                self.address_to_function_name[jump_target] = function_name
                self.hash_to_function_name[function_hash] = function_name

    def get_easm(self):
        """

        :return:
        """
        return asm.instruction_list_to_easm(self.instruction_list)
    
    # 用来 通过 heuristic 判断 codesize 
    def get_init_para_size(self, pattern, offset):

        instruction_list = self.instruction_list
        
        jump_table_indices = asm.find_op_code_sequence(pattern, instruction_list)
        
        return_list = []
        # 每个 index 都是 pattern的 起始位置, 不过不是在 bytecode中的 index 而是在 isntructionlist中的 index
        for index in jump_table_indices:

            try:
                para_size = instruction_list[index+offset]["argument"]
                
                if type(para_size) == tuple:
                    para_size = bytes(para_size).hex()
                para_size = int(para_size, 16)
                return_list.append((index,para_size))
            except(KeyError, IndexError):
                print("error, find codesize problem")
                return return_list
        return return_list
        
    

    # # 通过 heuristic 判断 calldatasize 
    # # 不同于 constructor， 函数 会有好几个， 参数大小也是多种多样， 不过 EVM 仅仅判断了是否 小于 固定值， 所以我们可以取 多个函数中需要的函数参数中的最大值。 
    # # 或者 根据函数签名 提供对应的 参数大小也可以呢。 
           
    def assign_func_parasize(self):
        # init_pattern = [("CODESIZE"),("SUB"),("DUP1"),("PUSH1", "PUSH2", "PUSH3", "PUSH4"),("DUP4"),("CODECOPY"),("DUP2"),("DUP2"),("ADD"),("PUSH1", "PUSH2", "PUSH3", "PUSH4"),("MSTORE"),
        #         ("PUSH1", "PUSH2", "PUSH3", "PUSH4"),("DUP2"),("LT"),("ISZERO"),("PUSH1", "PUSH2", "PUSH3", "PUSH4"),("JUMPI")]
        # init_para_size = self.get_init_para_size(init_pattern, 11)
        # if init_para_size != [] and self.sig is not None:
        #     print("assign constructor para size {}".format(init_para_size[0][1]))
        #     print("sig is {}".format(self.sig))
        print("[assign_func_parasize] sig is {}, type is {}".format(self.sig, type(self.sig)))
        
        if self.sig is not None:
            for function, sig in self.sig.items():
                len_ = len(build_calldata(sig))*32
                print("calldata size match success {}".format(len_))
                self.func_to_parasize[function] = len_
        
    # def assign_func_parasize_post(self):
    #     ### constructor 结束 开始看 各大 函数 
    #     func_pattern = [("CALLDATASIZE"),("SUB"),("PUSH1", "PUSH2", "PUSH3", "PUSH4"),("DUP2"),("LT"),("ISZERO"),("PUSH1", "PUSH2", "PUSH3", "PUSH4"),("JUMPI")]
    #     func_para_sizes = self.get_init_para_size(func_pattern, 2)
    #     for (jump_addr, para_size) in func_para_sizes:
    #         # print("jump_addr is {}".format(jump_addr))
    #         # print("size is {}".format(para_size))
    #         # print("address to funcname is {}".format(self.address_to_function_name))
    #         # if jump_target in self.address_to_function_name:
    #         # index = util.get_instruction_index(self.instruction_list, jump_addr)
    #         calldataqsize_addr = self.instruction_list[jump_addr]["address"]
    #         # print("index is {}".format(calldataqsize_addr))
    #         close_func_name = self.find_closest_func(self.address_to_function_name,calldataqsize_addr)
    #             # function_name = self.address_to_function_name[jump_target]
    #         if close_func_name is not None:
                
    #             self.func_to_parasize[close_func_name] = para_size
    #         else:
    #             print("jump_target is not in list")
        
    # def find_closest_func(self, address_to_function_name, index):
    #     temp = 99999999
    #     na = None
    #     for (key_, name) in address_to_function_name.items():
    #         if key_ > index:
    #             continue
    #         if temp >= index - key_:
    #             temp = index - key_
    #             na = (key_, name)
    #     if temp == 99999999:
    #         print("guess function entry failed")
    #         return None
    #     else:
    #         # print("guess function entry is {}, and function name is {}".format(na[0],na[1]))
    #         return na[1]

def get_function_info(
    index: int, instruction_list: list, signature_database: SignatureDB
) -> Tuple[str, int, str]:
    """Finds the function information for a call table entry Solidity uses the
    first 4 bytes of the calldata to indicate which function the message call
    should execute The generated code that directs execution to the correct
    function looks like this:

    - PUSH function_hash
    - EQ
    - PUSH entry_point
    - JUMPI

    This function takes an index that points to the first instruction, and from that finds out the function hash,
    function entry and the function name.

    :param index: Start of the entry pattern
    :param instruction_list: Instruction list for the contract that is being analyzed
    :param signature_database: Database used to map function hashes to their respective function names
    :return: function hash, function entry point, function name
    """

    # Append with missing 0s at the beginning
    if type(instruction_list[index]["argument"]) == tuple:
        try:
            function_hash = "0x" + bytes(
                instruction_list[index]["argument"]
            ).hex().rjust(8, "0")
        except AttributeError:
            raise ValueError(
                "Mythril currently does not support symbolic function signatures"
            )
    else:
        function_hash = "0x" + instruction_list[index]["argument"][2:].rjust(8, "0")

    function_names = signature_database.get(function_hash)

    if len(function_names) > 0:
        function_name = " or ".join(set(function_names))
    else:
        function_name = "_function_" + function_hash

    try:
        offset = instruction_list[index + 2]["argument"]
        if type(offset) == tuple:
            offset = bytes(offset).hex()
        entry_point = int(offset, 16)
    except (KeyError, IndexError):
        return function_hash, None, None

    return function_hash, entry_point, function_name


