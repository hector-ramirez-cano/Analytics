import ast
from typing import Literal

from model.alerts.alert_operations import AlertOperation


def compile_accessor(path: str, sep='>'):
    """
    Compiles a Python AST to access nested arguments inside dictionaries for fast lookup
    Returns a lambda that can be called with a dictionary as parameter
    :param path definition of nested lookups.
    :param sep separator of levels

    E.g.
        accessor = compile_accessor("config>values>device>size", sep=">")
    accessor(d) === d["config"]["values"]["device"]["size"]


    the accessor raises if the item is not found, or if any keys are missing from the input dictionary
    """
    keys = path.lstrip("&").split(sep)

    def accessor(d):
        for key in keys:
            d = d[key]
        return d

    return accessor


class AlertPredicate:
    def __init__(self,
                op: AlertOperation,
                left,
                right,
                const: Literal["left", "right", ""]
        ):
        self.op = op
        # if const == "", then it's a binary predicate,
        # both left and right are to be fetched from the datasets
        if const == "":
            self.predicate = op.to_predicate()

            # create the accessors/getters that will look into the dictionary
            self.eval_left = compile_accessor(left)
            self.eval_right = compile_accessor(right)
            self.eval = lambda d: self.predicate(self.eval_left(d), self.eval_right(d))

        # if const is not empty, then we have a const parameter
        # which turns our predicate into a unary predicate
        # we also override the getter to return the value, instead of fetching it from the dataset
        else:
            if const == "left":
                self.predicate = op.to_predicate_with_const(const_input=left, const=const)
                self.eval_left = lambda _: left
                self.eval_right = compile_accessor(right)
                self.eval = lambda d: self.predicate(self.eval_right(d))

            elif const == "right":
                self.predicate = op.to_predicate_with_const(const_input=right, const=const)
                self.eval_right = lambda _: right
                self.eval_left = compile_accessor(left)
                self.eval = lambda d: self.predicate(self.eval_left(d))

            else:
                # noinspection PyUnreachableCode
                raise Exception(f"Invalid value '{const}' for const param. Const can only be 'left', 'right' or ''")


    @staticmethod
    def from_dict(d: dict) -> "AlertPredicate":
        raise Exception("Not implemented")