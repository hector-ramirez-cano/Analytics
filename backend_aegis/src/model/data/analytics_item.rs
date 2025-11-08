use serde::Serialize;

use crate::model::data::device::Device;
use crate::model::data::link::Link;
use crate::model::data::group::Group;

#[derive(Clone, Debug)]
pub enum AnalyticsItem {
    Device(Device),
    Link(Link),
    Group(Group),
}

impl Serialize for AnalyticsItem {
    fn serialize<S>(&self, serializer: S) -> Result<S::Ok, S::Error>
    where
        S: serde::Serializer {
        match self {
            AnalyticsItem::Device(device) => device.serialize(serializer),
            AnalyticsItem::Link(link) => link.serialize(serializer),
            AnalyticsItem::Group(group) => group.serialize(serializer),
        }
    }
}
