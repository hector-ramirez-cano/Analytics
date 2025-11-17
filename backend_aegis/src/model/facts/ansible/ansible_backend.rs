use std::{collections::{HashMap}, env, io, path::{Component, Path, PathBuf}};

use pyo3::{Bound, PyAny, PyErr, Python, types::{PyAnyMethods, PyDict, PyIterator, PyModule}};

use crate::{config::Config, model::{cache::Cache, data::device_state::DeviceStatus, facts::{ansible::ansible_status::AnsibleStatus, generics::{MetricValue, Metrics, StatusT, ToMetrics}}}};



fn normalize_no_symlink(p: &Path) -> PathBuf {
    let mut out = PathBuf::new();
    for comp in p.components() {
        match comp {
            Component::Prefix(prefix) => out.push(prefix.as_os_str()), // Windows drive/UNC
            Component::RootDir => out.push(Component::RootDir.as_os_str()),
            Component::CurDir => {}
            Component::ParentDir => {
                // pop one component if possible, otherwise keep ParentDir for relative paths
                if !out.pop() {
                    // if out was empty and path was relative, preserve a leading ".."
                    out.push("..");
                }
            }
            Component::Normal(c) => out.push(c),
        }
    }
    out
}

pub fn abspath_with_cwd<P: AsRef<Path>, C: AsRef<Path>>(path: P, cwd: C) -> PathBuf {
    let p = path.as_ref();
    if p.is_absolute() {
        normalize_no_symlink(p)
    } else {
        normalize_no_symlink(&cwd.as_ref().join(p))
    }
}

pub fn abspath<P: AsRef<Path>>(path: P) -> io::Result<PathBuf> {
    let cwd = env::current_dir()?;
    Ok(abspath_with_cwd(path, cwd))
}


async fn run_playbook(targets: Vec<String>) -> (Metrics, StatusT) {
    let config   = Config::instance();
    let playbook :String = config.get("backend/model/playbooks/fact_gathering", "/")
        .expect("Config file does not contain playbook for fact gathering");
    let private :String = config.get("backend/model/private_data_dir", "/")
        .expect("Config file does not contain a private directory");

    let cwd = env::current_dir().expect("Failed to get current working directory");
    let private = abspath_with_cwd(private, &cwd);

    let targets = targets.join("\n");
    
    let inventory = format!("[servers]\n{targets}");

    let mut metrics: Metrics = HashMap::new();
    let mut status: StatusT = HashMap::new();

    /*
        All this is equivalent to this python code:
        runner = ansible_runner.run(
            private_data_dir=private,
            playbook=playbook,
            inventory=inventory,
            artifact_dir="/tmp/runner_output",
            quiet=True,
        )
        metrics = {}
        status = {}
        # Extract metrics into dictionary, for easy access
        for event in runner.events:
            if event['event'] == 'runner_on_ok':
                host = event['event_data']['host']
                res = event['event_data']['res']

                if 'ansible_facts' in res:
                    metrics.setdefault(host, {}).update(res['ansible_facts'])

                # Set status only if it hasn't failed
                if status.get(host) is None:
                    status[host] = { "ansible_status": {"status": AnsibleStatus.REACHABLE, "msg": ""} }

            if event['event'] == 'runner_on_unreachable':
                host = event['event_data']['host']
                res = event['event_data']['res']

                # Override status
                status[host] = {"ansible_status": {"status": AnsibleStatus.DARK, "msg": res['msg']}}

        return metrics, status
     */
    let result = rocket::tokio::task::spawn_blocking(move || -> Result<(Metrics, StatusT), PyErr> {
        // acquire the python environment, and extract data
        Python::attach(|py| -> Result<(Metrics, StatusT), PyErr> {
            let ansible_runner = PyModule::import(py, "ansible_runner").expect("[FATAL]Ansible runner python module is not present");
            let json_mod = PyModule::import(py, "json").expect("[FATAL]Json python module is not present!");

            let kwargs = PyDict::new(py);
            kwargs.set_item("private_data_dir", &private)?;
            kwargs.set_item("playbook", &playbook)?;
            kwargs.set_item("inventory", inventory)?;
            kwargs.set_item("artifact_dir", "/tmp/runner_output")?;
            kwargs.set_item("quiet", true)?;

            // call ansible_runner.run(**kwargs)
            let runner_obj = ansible_runner.call_method("run", (), Some(&kwargs));
            let runner_obj = match runner_obj {
                Ok(r) => r,
                Err(e) => {
                    let cwd = env::current_dir().expect("Failed to get current working directory");
                    log::error!("[FATAL] Ansible runner can't run, e='{e}'");
                    log::info!("[INFO ] Current working directory was={}", cwd.display());
                    log::info!("[INFO ] Current config file was={}", Config::instance().get_curr_config_path());
                    log::info!("[INFO ] Playbook directory was={}", playbook);
                    log::info!("[INFO ] Private directory was={}", private.display());
                    panic!("[FATAL] Ansible runner can't run, e='{e}'");
                }
            };

            let events = runner_obj.getattr("events").expect("[FATAL]Ansible runner instance should contain events attribute");
            let iter = PyIterator::from_object(&events)?;
            for event in iter {
                let ev_dict = event?.cast::<PyDict>().expect("[FATAL]Event should be a dictionary").clone();

                let event_name : String = match ev_dict.get_item("event") {
                    Ok(v) => v.extract()?,
                    Err(_) => continue,
                };

                let event_data: Bound<'_, PyAny> = match ev_dict.get_item("event_data") {
                    Ok(v) => v,
                    Err(_) => continue,
                };

                let host : String = match event_data.get_item("host") {
                    Ok(v) => v.extract()?,
                    Err(_) => continue,
                };

                let res: Bound<'_, PyDict> = match event_data.get_item("res") {
                    Ok(v) => v.extract()?,
                    Err(_) => continue,
                };

                if event_name == "runner_on_ok" {
                    // get values from dict, if 'ansible_facts' is present, merge into metrics
                    let af: Bound<'_, PyDict> = match res.get_item("ansible_facts") {
                        Ok(af) => af.extract()?,
                        Err(_) => continue,
                    };

                    // Convert Output into json string
                    let kwargs = PyDict::new(py);
                    kwargs.set_item("ensure_ascii", false)?;
                    let af = json_mod.call_method("dumps", (af,), Some(&kwargs));

                    let af: String = match af {
                        Ok(v) => v.extract()?,
                        Err(_) => continue,
                    };
                    
                    let af : serde_json::Value = match serde_json::from_str(&af) {
                        Ok(v) => v, Err(_) => continue,
                    };

                    let af : HashMap<String, MetricValue> = af.to_metrics(None);

                    // get or insert to metrics
                    match metrics.get_mut(&host) {
                        None => { metrics.insert(host.clone(), af); }
                        Some(existing)  => {
                            for (k, v) in af {
                                existing.insert(k.clone(), v);
                            }
                        }
                    }

                    // Update status, only if it hasn't been overriden
                    if !status.contains_key(&host) {
                        status.insert(host, DeviceStatus::new_ansible(AnsibleStatus::Reachable));
                    }
                } 
                else if event_name == "runner_on_unreachable" {
                    // override status with dark, and inform what failed
                    let msg = res.get_item("msg").and_then(|v| Ok(v.extract::<String>()?)).unwrap_or("".to_owned()).to_string();
                    status.insert(host, DeviceStatus::new_ansible(AnsibleStatus::Dark(msg)));
                }
            }

            Ok((metrics, status))
        })
    });

    let result = result.await;

    match result {
        Ok(Ok((metrics, status))) => (metrics, status),
        Ok(Err(_)) => (HashMap::new(), HashMap::new()),
        Err(_) => (HashMap::new(), HashMap::new()),
    }
}

pub async fn gather_facts() -> (Metrics, StatusT) {
    log::info!("[INFO ][FACTS][ANSIBLE] Starting playbook execution");
    
    let targets = Cache::instance().ansible_inventory().await;
    let results = run_playbook(targets).await;

    log::info!("[INFO ][FACTS][ANSIBLE] Playbook execution done.");

    results
}

pub fn init() {
    Python::initialize();
}