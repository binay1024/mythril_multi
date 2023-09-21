"""This module declares classes to represent call data."""
from typing import cast, Union, Tuple, List


from typing import Any, Union
import z3
from z3 import Model, unsat, unknown
from z3.z3types import Z3Exception


from mythril.laser.ethereum.util import get_concrete_int

from mythril.laser.smt import (
    Array,
    BitVec,
    Bool,
    Concat,
    Expression,
    If,
    K,
    simplify,
    symbol_factory,
    Solver,
)


class BaseCalldata:
    """Base calldata class This represents the calldata provided when sending a
    transaction to a contract."""

    def __init__(self, tx_id: str) -> None:
        """

        :param tx_id:
        """
        self.tx_id = tx_id

    @property
    def calldatasize(self) -> BitVec:
        """

        :return: Calldata size for this calldata object
        """
        result = self.size
        if isinstance(result, int):
            return symbol_factory.BitVecVal(result, 256)
        return result

    def get_word_at(self, offset: int) -> Expression:
        """Gets word at offset.

        :param offset:
        :return:
        """
        parts = self[offset : offset + 32]
        return simplify(Concat(parts))

    def __getitem__(self, item: Union[int, slice, BitVec]) -> Any:
        """

        :param item:
        :return:
        """
        if isinstance(item, int) or isinstance(item, Expression):

            if item > self.size-1:
                print("Error, out of read bound")
                raise ValueError
            return self._load(item)

        if isinstance(item, slice):
            start = 0 if item.start is None else item.start
            step = 1 if item.step is None else item.step
            stop = self.size if item.stop is None else item.stop

            try:
                current_index = (
                    start
                    if isinstance(start, BitVec)
                    else symbol_factory.BitVecVal(start, 256)
                )
                parts = []
                while True:
                    s = Solver()
                    s.set_timeout(1000)
                    s.add(current_index != stop)
                    s.add(current_index != self.size)
                    result = s.check()
                    # 这是 退出条件 当 index == stop 俺么 check 就不满足了
                    if result in (unsat, unknown):
                        break
                    element = self._load(current_index)
                    if not isinstance(element, Expression):
                        element = symbol_factory.BitVecVal(element, 8)

                    parts.append(element)
                    current_index = simplify(current_index + step)

            except Z3Exception:
                print("error Invalid calldata slice")
                raise IndexError("Invalid Calldata Slice")
            return parts
        print("unkown error in getitem")
        raise ValueError

    def _load(self, item: Union[int, BitVec]) -> Any:
        """

        :param item:
        """
        raise NotImplementedError()

    @property
    def size(self) -> Union[BitVec, int]:
        """Returns the exact size of this calldata, this is not normalized.

        :return: unnormalized call data size
        """
        raise NotImplementedError()

    def concrete(self, model: Model) -> list:
        """Returns a concrete version of the calldata using the provided model.

        :param model:
        """
        raise NotImplementedError


class ConcreteCalldata(BaseCalldata):
    """A concrete call data representation."""

    def __init__(self, tx_id: str, calldata: list) -> None:
        """Initializes the ConcreteCalldata object.

        :param tx_id: Id of the transaction that the calldata is for.
        :param calldata: The concrete calldata content
        """
        self._concrete_calldata = calldata
        self._calldata = K(256, 8, 0)
        for i, element in enumerate(calldata, 0):
            element = (
                symbol_factory.BitVecVal(element, 8)
                if isinstance(element, int)
                else element
            )
            self._calldata[symbol_factory.BitVecVal(i, 256)] = element

        super().__init__(tx_id)

    def _load(self, item: Union[int, BitVec]) -> BitVec:
        """

        :param item:
        :return:
        """
        item = symbol_factory.BitVecVal(item, 256) if isinstance(item, int) else item
        return simplify(self._calldata[item])

    def concrete(self, model: Model) -> list:
        """

        :param model:
        :return:
        """
        return self._concrete_calldata

    @property
    def size(self) -> int:
        """

        :return:
        """
        return len(self._concrete_calldata)


class BasicConcreteCalldata(BaseCalldata):
    """A base class to represent concrete call data."""

    def __init__(self, tx_id: str, calldata: list) -> None:
        """Initializes the ConcreteCalldata object, that doesn't use z3 arrays.

        :param tx_id: Id of the transaction that the calldata is for.
        :param calldata: The concrete calldata content
        """
        self._calldata = calldata
        super().__init__(tx_id)

    def _load(self, item: Union[int, Expression]) -> Any:
        """

        :param item:
        :return:
        """
        if isinstance(item, int):
            try:
                return self._calldata[item]
            except IndexError:
                return 0

        value = symbol_factory.BitVecVal(0x0, 8)
        for i in range(self.size):
            value = If(cast(Union[BitVec, Bool], item) == i, self._calldata[i], value)
        return value

    def concrete(self, model: Model) -> list:
        """

        :param model:
        :return:
        """
        return self._calldata

    @property
    def size(self) -> int:
        """

        :return:
        """
        return len(self._calldata)


class SymbolicCalldata(BaseCalldata):
    """A class for representing symbolic call data."""

    def __init__(self, tx_id: str) -> None:
        """Initializes the SymbolicCalldata object.

        :param tx_id: Id of the transaction that the calldata is for.
        """
        self._size = symbol_factory.BitVecSym(str(tx_id) + "_calldatasize", 256)
        self._calldata = Array("{}_calldata".format(tx_id), 256, 8)
        super().__init__(tx_id)

    def _load(self, item: Union[int, BitVec]) -> Any:
        """

        :param item:
        :return:
        """
        item = symbol_factory.BitVecVal(item, 256) if isinstance(item, int) else item
        return simplify(
            If(
                item < self._size,
                simplify(self._calldata[cast(BitVec, item)]),
                symbol_factory.BitVecVal(0, 8),
            )
        )

    def concrete(self, model: Model) -> list:
        """

        :param model:
        :return:
        """
        concrete_length = model.eval(self.size.raw, model_completion=True).as_long()
        result = []
        for i in range(concrete_length):
            value = self._load(i)
            c_value = model.eval(value.raw, model_completion=True).as_long()
            result.append(c_value)

        return result

    @property
    def size(self) -> BitVec:
        """

        :return:
        """
        return self._size


class BasicSymbolicCalldata(BaseCalldata):
    """A basic class representing symbolic call data."""

    def __init__(self, tx_id: str) -> None:
        """Initializes the SymbolicCalldata object.

        :param tx_id: Id of the transaction that the calldata is for.
        """
        self._reads = []  # type: List[Tuple[Union[int, BitVec], BitVec]]
        self._size = symbol_factory.BitVecSym(str(tx_id) + "_calldatasize", 256)
        super().__init__(tx_id)

    def _load(self, item: Union[int, BitVec], clean=False) -> Any:
        expr_item = (
            symbol_factory.BitVecVal(item, 256) if isinstance(item, int) else item
        )  # type: BitVec

        symbolic_base_value = If(
            expr_item >= self._size,
            symbol_factory.BitVecVal(0, 8),
            BitVec(
                symbol_factory.BitVecSym(
                    "{}_calldata_{}".format(self.tx_id, str(item)), 8
                )
            ),
        )
        return_value = symbolic_base_value
        for r_index, r_value in self._reads:
            return_value = If(r_index == expr_item, r_value, return_value)
        if not clean:
            self._reads.append((expr_item, symbolic_base_value))
        return simplify(return_value)

    def concrete(self, model: Model) -> list:
        """

        :param model:
        :return:
        """
        concrete_length = get_concrete_int(model.eval(self.size, model_completion=True))
        result = []
        for i in range(concrete_length):
            value = self._load(i, clean=True)
            c_value = get_concrete_int(model.eval(value, model_completion=True))
            result.append(c_value)

        return result

    @property
    def size(self) -> BitVec:
        """

        :return:
        """
        return self._size

class MixedSymbolicCalldata(BaseCalldata):
    """ A class for representing mixed symbolic call data.
        size is concrete 
    """

    def __init__(self, tx_id: str, calldata:list = None ,total_length = None) -> None:
        """Initializes the SymbolicCalldata object.

        :param tx_id: Id of the transaction that the calldata is for.
        :_size: 我们让他 是一个 int 类型的整数
        """
        if type(total_length) == int:
            self._size = total_length
            self._calldata = Array("{}_calldata".format(tx_id), 256, 8)
        elif type(total_length) == BitVec:
            self._size = total_length.value
            self._calldata = Array("{}_calldata".format(tx_id), 256, 8)
        else:
            print("waring!, mixedSymbolicCalldata size is symbolic")
            self._size = symbol_factory.BitVecSym(str(tx_id) + "_calldatasize", 256)
            self._calldata = Array("{}_calldata".format(tx_id), 256, 8)

        # 这里 期望的 calldata是 byte单位的数字 组成的 list
        if calldata != None and type(self._size) == int:
            for i, element in enumerate(calldata, 0):
                element = (
                    symbol_factory.BitVecVal(element, 8)
                    if isinstance(element, int)
                    else element
                )
                self._calldata[symbol_factory.BitVecVal(i, 256)] = element

        # self.solver = Solver()
        super().__init__(tx_id)

    # 写入 byte
    def assign_value_at_index(self, index:Union[int, BitVec], value:Union[int, BitVec]):
        """为指定索引赋值。"""
        
        # 如果是具体值，则使用BitVecVal进行转换
        value = symbol_factory.BitVecVal(value, 8) if isinstance(value, int) else value
        index = symbol_factory.BitVecVal(index, 256) if isinstance(index, int) else index
        # 用到了 BasicCalldata的 setitem
        self._calldata[index] = value 
        # self._calldata.raw = z3.Store(self.raw, index.raw, value.raw)
        # print("[TEST] print calldata {}".format(self._calldata[index]))

    # 读取 byte
    def _load(self, index: Union[int, BitVec]) -> Any:
        """

        :param item: item表示 第几个 byte 的 index
        :return:
        """
        index = symbol_factory.BitVecVal(index, 256) if isinstance(index, int) else index
        result =  simplify(
                If(
                    index < self._size,
                    # 可能是一个表达式 也可能是一个具体值, 用到了 BasicCalldata的 getitem
                    simplify(self._calldata[cast(BitVec, index)]), 
                    symbol_factory.BitVecVal(0, 8),
                )
        )
        return result


    def concrete(self, model: Model) -> list:
        """

        :param model:
        :return:
        """
        concrete_length = model.eval(self.size.raw, model_completion=True).as_long()
        result = []
        for i in range(concrete_length):
            value = self._load(i)
            c_value = model.eval(value.raw, model_completion=True).as_long()
            result.append(c_value)

        return result

    @property
    def size(self) -> BitVec:
        """

        :return:
        """
        return self._size