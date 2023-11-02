from abc import ABC, abstractmethod
from typing import List
from mythril.laser.ethereum.state.global_state import GlobalState


class BasicSearchStrategy(ABC):
    """
    A basic search strategy which halts based on depth
    """

    def __init__(self, work_list, max_depth, **kwargs):
        self.work_list = work_list  # type: List[GlobalState]
        self.max_depth = max_depth

    def __iter__(self):
        return self

    @abstractmethod
    def get_strategic_global_state(self):
        """"""
        raise NotImplementedError("Must be implemented by a subclass")

    def run_check(self):
        return True

    def __next__(self):
        try:
            # 这个实际上就是pop 但是为什么没有 pop上捏？ 
            global_state = self.get_strategic_global_state()
            if global_state.mstate.depth >= self.max_depth:
                print("mstate.depth overthan maxdepth error")
                return self.__next__()
            
            return global_state
        
        except (IndexError):
            # print("IndexError in BasicSearchStrategy")
            raise StopIteration
        
        except (StopIteration):
            # print("stop signal in BasicSearchStrategy")
            raise StopIteration


class CriterionSearchStrategy(BasicSearchStrategy):
    """
    If a criterion is satisfied, the search halts
    """

    def __init__(self, work_list, max_depth, **kwargs):
        super().__init__(work_list, max_depth, **kwargs)
        self._satisfied_criterion = False

    def get_strategic_global_state(self):
        if self._satisfied_criterion:
            # print("IndexError in CriterionSearchStrategy")
            raise StopIteration
        try:
            return self.get_strategic_global_state()
        except StopIteration:
            # print("IndexError in CriterionSearchStrategy")
            raise StopIteration

    def set_criterion_satisfied(self):
        self._satisfied_criterion = True
