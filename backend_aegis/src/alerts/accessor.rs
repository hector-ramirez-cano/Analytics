use crate::{alerts::Accessor};
use crate::model::facts::generics::{MetricSet, MetricValue};

impl Accessor {
    pub fn new (key: &str) -> Self {
        Accessor { key: key.to_string() }
    }

    pub fn access<'a>(&self, dataset: &'a MetricSet) -> Option<&'a MetricValue> {
        dataset.get(&self.key)
    }
}