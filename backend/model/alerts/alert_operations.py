from enum import Enum
from typing import Literal, Callable, Any


class AlertReduceLogic(Enum):
    ALL = "all"
    ANY = "any"

    @staticmethod
    def from_str(value: str):
        """
        Parses from string. Returns None if didn't match either "all" or "any"

        :param value string representation, either "all" or "any"
        :returns: AlertBooleanOperation or None, if didn't match
        """
        match value.lower():
            case "all":
                return AlertReduceLogic.ALL

            case "any":
                return AlertReduceLogic.ANY

        return None

    def __str__(self):
        match self:
            case AlertReduceLogic.ALL:
                return "ALL"

            case AlertReduceLogic.ANY:
                return "ANY"

            case _:
                return "UNKNOWN"


# TODO: Rename to alert Predicate Operation
class AlertOperation(Enum):
    MORE_THAN = "more_than"
    MORE_THAN_EQUAL = "more_than_equal"
    LESS_THAN = "less_than"
    LESS_THAN_EQUAL = "less_than_equal"
    EQUAL = "equal"
    NOT_EQUAL = "not_equal"
    CONTAINS = "contains"

    def __str__(self):
        match self:
            case AlertOperation.MORE_THAN:
                return "MORE_THAN"

            case AlertOperation.MORE_THAN_EQUAL:
                return "MORE_THAN_EQUAL"

            case AlertOperation.LESS_THAN:
                return "LESS_THAN"

            case AlertOperation.LESS_THAN_EQUAL:
                return "LESS_THAN_EQUAL"

            case AlertOperation.EQUAL:
                return "EQUAL"

            case AlertOperation.NOT_EQUAL:
                return "NOT_EQUAL"

            case AlertOperation.CONTAINS:
                return "CONTAINS"

            case _:
                return "UNKNOWN"

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
                case AlertOperation.MORE_THAN:
                    return lambda right: const_input > right

                case AlertOperation.MORE_THAN_EQUAL:
                    return lambda right: const_input >= right

                case AlertOperation.LESS_THAN:
                    return lambda right: const_input < right

                case AlertOperation.LESS_THAN_EQUAL:
                    return lambda right: const_input <= right

                case AlertOperation.EQUAL:
                    return lambda right: const_input == right

                case AlertOperation.CONTAINS:
                    return lambda right: const_input in right

                case AlertOperation.NOT_EQUAL:
                    return lambda right: const_input != right

                case _:
                    # keep "unreachable" code, in case new operations are added, so it doesn't silently fail
                    # noinspection PyUnreachableCode
                    raise Exception("Unhandled case in AlertOperations Predicate")

        elif const == "right":
            match self:
                case AlertOperation.MORE_THAN:
                    return lambda left: left > const_input

                case AlertOperation.MORE_THAN_EQUAL:
                    return lambda left: left >= const_input

                case AlertOperation.LESS_THAN:
                    return lambda left: left < const_input

                case AlertOperation.LESS_THAN_EQUAL:
                    return lambda left: left <= const_input

                case AlertOperation.EQUAL:
                    return lambda left: left == const_input

                case AlertOperation.CONTAINS:
                    return lambda left: left in const_input

                case AlertOperation.NOT_EQUAL:
                    return lambda left: left != const_input

                case _:
                    # keep "unreachable" code, in case new operations are added, so it doesn't silently fail
                    # noinspection PyUnreachableCode
                    raise Exception("Unhandled case in AlertOperations Predicate")

    def to_predicate(self) -> Callable[[Any, Any], bool]:
        """
            Creates a binary predicate (lambda) for fast evaluation.
            It uses `self` as operation between left and right.

            :returns: Callable as unary predicate (lambda left, right: ...) where ... contains a logic operation between left and right
        """
        match self:
            case AlertOperation.MORE_THAN:
                return lambda left_param, right_param: left_param > right_param

            case AlertOperation.MORE_THAN_EQUAL:
                return lambda left_param, right_param: left_param >= right_param

            case AlertOperation.LESS_THAN:
                return lambda left_param, right_param: left_param < right_param

            case AlertOperation.LESS_THAN_EQUAL:
                return lambda left_param, right_param: left_param <= right_param

            case AlertOperation.EQUAL:
                return lambda left_param, right_param: left_param == right_param

            case AlertOperation.NOT_EQUAL:
                return lambda left_param, right_param: left_param != right_param

            case AlertOperation.CONTAINS:
                return lambda left_param, right_param: left_param in right_param

            case _:
                # keep "unreachable" code, in case new operations are added, so it doesn't silently fail
                # noinspection PyUnreachableCode
                raise Exception("Unhandled case in AlertOperations Predicate")

    @staticmethod
    def from_str(value: str) -> "AlertOperation":
        """Parses from string

        Args:
            value (str): String representation of the AlertOperation

        Returns:
            AlertOperation: AlertOperation instance, or null if no value matches
        """
        try:
            return AlertOperation(value.lower())
        except ValueError:
            return None
