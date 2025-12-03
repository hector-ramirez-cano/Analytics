use std::collections::HashMap;
use std::{io, process::Command};
use regex::Regex;
use rocket::futures;
use tokio::task;
use futures::future::join_all;

use crate::types::{MetricValue, Metrics, Status};
use crate::model::cache::Cache;
use crate::model::data::device_state::DeviceStatus;
use crate::model::facts::icmp::icmp_status::IcmpStatus;

lazy_static::lazy_static! {
    // Unwrap: if this regex is for some reason invalid, it _must_ panic
    static ref RTT_RE: Regex = Regex::new(
        r"rtt min/avg/max/mdev = ([\d.]+)/([\d.]+)/([\d.]+)/([\d.]+) ms"
    ).unwrap();

    // Unwrap: if this regex is for some reason invalid, it _must_ panic
    static ref LOSS_RE: Regex = Regex::new(r"(\d+(?:\.\d+)?)% packet loss").unwrap();
}

/// Try to parse a f64, returning a default on failure.
fn parse_float(s: &str, default: f64) -> f64 {
    s.parse::<f64>().unwrap_or(default)
}

/// Result tuple returned by the blocking ping function:
/// (return_code, host, status, rtt_avg_ms, loss_pct)
type PingResult = (i32, String, IcmpStatus, f64, f64);


/// Run `ping -A -c 3 <host>` and extract (returncode, host, status, rtt_avg_ms, loss_pct)
/// Note: this uses the Unix-style `ping` output format used in your Python snippet.
fn ping_host_once(host: &str) -> io::Result<(i32, String, IcmpStatus, f64, f64)> {
    // static string patterns
    const UNREACHABLE_PATTERN: &str = "Destination Host Unreachable";
    const NAME_RESOLUTION_ERROR_PATTERN: &str = "Temporary failure in name resolution";
    const TIMEOUT_ERROR_PATTERN: &str = "Request Timed Out";
    const HOST_NOT_FOUND_PATTERN: &str = "Could Not Find Host";

    // run ping subprocess
    let output = Command::new("ping")
        .arg("-A")
        .arg("-c")
        .arg("3")
        .arg(host)
        .output()?; // propagate io::Error on failure to spawn

    let return_code = output.status.code().unwrap_or(-1);
    let stdout = String::from_utf8_lossy(&output.stdout);
    let stderr = String::from_utf8_lossy(&output.stderr);

    // defaults
    let mut rtt_avg_ms = 0.0f64;
    let mut loss_pct = 100.0f64;
    let status =
    if return_code == 0 {
        // try extract RTT avg
        if let Some(cap) = RTT_RE.captures(&stdout) {
            // capture group 2 is avg in your pattern
            if let Some(avg) = cap.get(2) {
                rtt_avg_ms = parse_float(avg.as_str(), 0.0);
            }
        }
        // try extract loss
        if let Some(cap) = LOSS_RE.captures(&stdout) {
            if let Some(loss) = cap.get(1) {
                loss_pct = parse_float(loss.as_str(), 0.0);
            }
        }
        IcmpStatus::Reachable
    } else {
        // examine stderr text for known errors (same order/logic as Python)
        let stderr_s = stderr.as_ref();
        let stdout_s = stdout.as_ref();
        if stderr_s.contains(UNREACHABLE_PATTERN) || stdout_s.contains(UNREACHABLE_PATTERN) {
            IcmpStatus::Unreachable(stderr_s.to_string())
        } else if stderr_s.contains(TIMEOUT_ERROR_PATTERN) || stdout_s.contains(TIMEOUT_ERROR_PATTERN) {
            IcmpStatus::Timeout(stderr_s.to_string())
        } else if stderr_s.contains(NAME_RESOLUTION_ERROR_PATTERN) || stdout_s.contains(NAME_RESOLUTION_ERROR_PATTERN) {
            IcmpStatus::NameResolutionError(stderr_s.to_string())
        } else if stderr_s.contains(HOST_NOT_FOUND_PATTERN) || stdout_s.contains(HOST_NOT_FOUND_PATTERN) {
            IcmpStatus::HostNotFound(stderr_s.to_string())
        } else {
            dbg!(&stderr_s, &stdout);
            IcmpStatus::Unknown(format!("stdout={}, stderr={}", stdout_s.to_string(), stderr_s.to_string()))
        }
    };

    Ok((return_code, host.to_string(), status, rtt_avg_ms, loss_pct))
}

async fn ping_devices(
    hosts: Vec<String>,
) -> (Metrics, Status) {
    // spawn_blocking for each host (equivalent to loop.run_in_executor(None, func, host))
    let tasks: Vec<_> = hosts
        .into_iter()
        .map(|host| {
            // move host into the blocking closure
            task::spawn_blocking(move || {
                // call your synchronous ping function here
                // returns io::Result<PingResult>
                let res: io::Result<PingResult> = ping_host_once(&host);
                (host, res)
            })
        })
        .collect();

    // Await all tasks in parallel (like asyncio.gather)
    let join_results = join_all(tasks).await;

    // prepare output maps
    let mut metrics_map: Metrics = HashMap::new();
    let mut status_map: Status = HashMap::new();

    for join_res in join_results {
        match join_res {
            // spawn_blocking succeeded
            Ok((host, res)) => {
                match res {
                    Ok((_rc, _host_str, icmp_status, rtt, loss)) => {
                        // populate metrics
                        metrics_map.insert(
                            host.clone(),
                            HashMap::from([
                                ("icmp_status".to_string(), MetricValue::String(icmp_status.type_to_string().to_string())),
                                ("icmp_rtt".to_string(), MetricValue::Number(rtt.into())),
                                ("icmp_loss_percent".to_string(), MetricValue::Number(loss.into()))
                            ])
                        );

                        // populate status wrapper (msg left empty like your Python)
                        status_map.insert(
                            host,
                            DeviceStatus::new_icmp(icmp_status)
                        );
                    }
                    // ping_host_once failed to run or parse; mark as unreachable and defaults
                    Err(_e) => {
                        metrics_map.insert(
                            host.clone(),
                            HashMap::from([
                                ("icmp_status".to_string(), MetricValue::Integer(IcmpStatus::Unreachable(_e.to_string()).to_i32().into())),
                                ("icmp_rtt".to_string(), MetricValue::Number(0.0.into())),
                                ("icmp_loss_percent".to_string(), MetricValue::Number(100.0.into()))
                            ])
                        );
                        status_map.insert(
                            host,
                            DeviceStatus::new_icmp(IcmpStatus::Unreachable(_e.to_string()))
                        );
                    }
                }
            }
            // The blocking task panicked or join failed; record a generic failure
            Err(join_err) => {
                // join_err does not include the host; choose how to log/handle this in real code
                eprintln!("ping task join error: {}", join_err);
            }
        }
    }

    (metrics_map, status_map)
}

pub async fn gather_facts(
    // TODO: Change Metric into MetricValue to make it generic
) -> (Metrics, Status) {
    log::info!("[INFO ][FACTS][ICMP] Starting ping sweep...");
    let targets = Cache::instance().icmp_inventory().await;

    let results = ping_devices(targets).await;

    log::info!("[INFO ][FACTS][ICMP] Ping sweep done.");

    results
}

pub fn init() {

    println!("[INFO ][FACTS][ICMP] Init ICMP backend");
}

#[cfg(test)]
mod tests {
    use super::*;

    // These tests are lightweight structural checks;
    #[test]
    fn parse_float_ok() {
        assert_eq!(parse_float("1.234", 0.0), 1.234);
        assert_eq!(parse_float("not-a-number", 5.0), 5.0);
    }

    #[test]
    fn result_tuple_shape() {
        let host = "8.8.8.8";
        let res = ping_host_once(host);
        // It may error if ping is not present or execution fails; we only assert error type handling.
        if let Ok((_rc, h, _status, _rtt, _loss)) = res {
            assert_eq!(h, host.to_string());
        }
    }
}
