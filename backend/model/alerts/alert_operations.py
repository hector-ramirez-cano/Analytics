from enum import Enum
from typing import Literal, Callable, Any


class AlertBooleanOperation(Enum):
    boolean_and = "and",
    boolean_or = "or",

    @staticmethod
    def from_str(value: str):
        """
        Parses from string. Returns None if didn't match either "and" or "or"

        :param value string representation, either "and" or "or"
        :returns: AlertBooleanOperation or None, if didn't match
        """
        match value:
            case "and":
                return AlertBooleanOperation.boolean_and

            case "or":
                return AlertBooleanOperation.boolean_or

        return None


class AlertOperation(Enum):
    more_than = "more_than",
    more_than_equal = "more_than_equal",
    less_than = "less_than",
    less_than_equal = "less_than_equal",
    equal = "equal",
    not_equal = "not_equal",
    contains = "contains",

    def to_predicate_with_const(self, const_input, const: Literal["left", "right"]) -> Callable[[Any], bool]:
        """
            Creates a unary predicate (lambda) out of a binary predicate with a constant value for fast evaluation.
            That is, if one side is constant, this value does not need to be evaluated each time the predicate is evaluated.
            It uses `self` as operation between left and right.

            :param const_input input that will be fixed as constant
            :param const definition of which side of the operation is defined as constant. Can be either "left" or "right"

            :returns: Callable as unary predicate (lambda x: ...)
        """
        if const == "left":
            match self:
                case AlertOperation.more_than:
                    return lambda right: const_input > right

                case AlertOperation.more_than_equal:
                    return lambda right: const_input >= right

                case AlertOperation.less_than:
                    return lambda right: const_input < right

                case AlertOperation.less_than_equal:
                    return lambda right: const_input <= right

                case AlertOperation.equal:
                    return lambda right: const_input == right

                case AlertOperation.contains:
                    return lambda right: const_input in right

                case AlertOperation.not_equal:
                    return lambda right: const_input != right

                case _:
                    # keep "unreachable" code, in case new operations are added, so it doesn't silently fail
                    # noinspection PyUnreachableCode
                    raise "Unhandled case in AlertOperations Predicate"

        elif const == "right":
            match self:
                case AlertOperation.more_than:
                    return lambda left: left > const_input

                case AlertOperation.more_than_equal:
                    return lambda left: left >= const_input

                case AlertOperation.less_than:
                    return lambda left: left < const_input

                case AlertOperation.less_than_equal:
                    return lambda left: left <= const_input

                case AlertOperation.equal:
                    return lambda left: left == const_input

                case AlertOperation.contains:
                    return lambda left: left in const_input

                case AlertOperation.not_equal:
                    return lambda left: left != const_input

                case _:
                    # keep "unreachable" code, in case new operations are added, so it doesn't silently fail
                    # noinspection PyUnreachableCode
                    raise "Unhandled case in AlertOperations Predicate"

    def to_predicate(self) -> Callable[[Any, Any], bool]:
        """
            Creates a binary predicate (lambda) for fast evaluation.
            It uses `self` as operation between left and right.

            :returns: Callable as unary predicate (lambda left, right: ...) where ... contains a logic operation between left and right
        """
        match self:
            case AlertOperation.more_than:
                return lambda left_param, right_param: left_param > right_param

            case AlertOperation.more_than_equal:
                return lambda left_param, right_param: left_param >= right_param

            case AlertOperation.less_than:
                return lambda left_param, right_param: left_param < right_param

            case AlertOperation.less_than_equal:
                return lambda left_param, right_param: left_param <= right_param

            case AlertOperation.equal:
                return lambda left_param, right_param: left_param == right_param

            case AlertOperation.not_equal:
                return lambda left_param, right_param: left_param != right_param

            case AlertOperation.contains:
                return lambda left_param, right_param: left_param in right_param

            case _:
                # keep "unreachable" code, in case new operations are added, so it doesn't silently fail
                # noinspection PyUnreachableCode
                raise "Unhandled case in AlertOperations Predicate"

    @staticmethod
    def from_str(value: str) -> "AlertOperation":
        try:
            return AlertOperation(value)
        except ValueError:
            return None
