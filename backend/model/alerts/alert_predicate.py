from typing import Literal

from backend.model.alerts.alert_operations import AlertOperations


class AlertPredicate:
    def __init__(self,
                 op: AlertOperations,
                 left,
                 right,
                 const: Literal["left", "right", ""]
    ):
        # TODO: FIX DYNAMIC GETTERS
        # we assume both getters are dynamic, and require to fetch from the dataset
        self.get_left = lambda dataset: dataset[left.lstrip("&")]
        self.get_right = lambda dataset: dataset[right.lstrip("&")]

        # if const == "", then it's a binary predicate,
        # both left and right are to be fetched from the datasets
        if const == "":
            self.predicate = op.to_predicate()

        # if const is not empty, then we have a const parameter
        # which turns our predicate into a unary predicate
        # we also override the getter to return the value, instead of fetching it from the dataset
        else:
            if const == "left":
                self.predicate = op.to_predicate_with_const(const_input=left, const=const)
                self.get_left = lambda dataset: left

            elif const == "right":
                self.predicate = op.to_predicate_with_const(const_input=right, const=const)
                self.get_right = lambda dataset: right
            else:
                raise f"Invalid value '{const}' for const param. Const can only be 'left', 'right' or ''"


