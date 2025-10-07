from enum import Enum
from typing import Literal, Callable, Any


class AlertOperations(Enum):
    more_than       = "more_than",
    more_than_equal = "more_than_equal",
    less_than       = "less_than",
    less_than_equal = "less_than_equal",
    equal           = "equal",
    contains        = "contains",


    def to_predicate_with_const(self, const_input, const: Literal["left" , "right"]) -> Callable[[Any], bool]:
        if const == "left":
            match self:
                case AlertOperations.more_than:
                    return lambda right: const_input > right

                case AlertOperations.more_than_equal:
                    return lambda right: const_input >= right

                case AlertOperations.less_than:
                    return lambda right: const_input < right

                case AlertOperations.less_than_equal:
                    return lambda right: const_input <= right

                case AlertOperations.equal:
                    return lambda right: const_input == right

                case AlertOperations.contains:
                    return lambda right: const_input in right

                case _:
                    raise "Unhandled case in AlertOperations Predicate"

        elif const == "right":
            match self:
                case AlertOperations.more_than:
                    return lambda left: left > const_input

                case AlertOperations.more_than_equal:
                    return lambda left: left >= const_input

                case AlertOperations.less_than:
                    return lambda left: left < const_input

                case AlertOperations.less_than_equal:
                    return lambda left: left <= const_input

                case AlertOperations.equal:
                    return lambda left: left == const_input

                case AlertOperations.contains:
                    return lambda left: left in const_input

                case _:
                    raise "Unhandled case in AlertOperations Predicate"


    def to_predicate(self) -> Callable[[Any, Any], bool]:
        match self:
            case AlertOperations.more_than:
                return lambda left_param, right_param: left_param > right_param

            case AlertOperations.more_than_equal:
                return lambda left_param, right_param: left_param >= right_param

            case AlertOperations.less_than:
                return lambda left_param, right_param: left_param < right_param

            case AlertOperations.less_than_equal:
                return lambda left_param, right_param: left_param <= right_param

            case AlertOperations.equal:
                return lambda left_param, right_param: left_param == right_param

            case AlertOperations.contains:
                return lambda left_param, right_param: left_param in right_param

            case _:
                raise "Unhandled case in AlertOperations Predicate"

    @staticmethod
    def from_string(value: str) -> "AlertOperations":
        try:
            return AlertOperations(value)
        except ValueError:
            return None