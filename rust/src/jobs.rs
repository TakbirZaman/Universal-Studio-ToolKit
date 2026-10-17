use crate::model::*;
use std::sync::{
    Arc, Mutex,
    atomic::{AtomicBool, Ordering},
};
#[derive(Clone, Copy, Debug, PartialEq, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum JobState {
    Queued,
    Running,
    Cancelling,
    Cancelled,
    Succeeded,
    Failed,
    PartiallySucceeded,
}
#[derive(Clone)]
pub struct Cancellation(pub Arc<AtomicBool>);
impl Default for Cancellation {
    fn default() -> Self {
        Self(Arc::new(AtomicBool::new(false)))
    }
}
impl Cancellation {
    pub fn cancel(&self) {
        self.0.store(true, Ordering::SeqCst)
    }
    pub fn is_cancelled(&self) -> bool {
        self.0.load(Ordering::SeqCst)
    }
}
pub struct BatchResult {
    pub state: JobState,
    pub items: Vec<Result<PreparedOutput>>,
}
/// One bounded worker; a failed item does not discard successful outputs.
/// Blocking engine calls cancel between stages, never by killing an in-flight write.
pub fn photo_batch(
    inputs: &[Vec<u8>],
    options: &PhotoOptions,
    cancel: &Cancellation,
) -> BatchResult {
    let mut items = Vec::new();
    for input in inputs {
        if cancel.is_cancelled() {
            break;
        }
        items.push(crate::photo::process_cancellable(input, options, &|| {
            cancel.is_cancelled()
        }));
    }
    let ok = items.iter().filter(|r| r.is_ok()).count();
    let state = if cancel.is_cancelled() {
        if ok > 0 {
            JobState::PartiallySucceeded
        } else {
            JobState::Cancelled
        }
    } else if ok == inputs.len() && !inputs.is_empty() {
        JobState::Succeeded
    } else if ok == 0 {
        JobState::Failed
    } else {
        JobState::PartiallySucceeded
    };
    BatchResult { state, items }
}
static ENGINE: Mutex<()> = Mutex::new(());
pub fn serial<T>(f: impl FnOnce() -> Result<T>) -> Result<T> {
    let _guard = ENGINE
        .lock()
        .map_err(|_| invalid("Processing service needs to be restarted."))?;
    f()
}

/// Wait for the bounded engine slot without making a queued cancellation wait
/// for an unrelated document to finish. Running engines own their stop policy.
pub fn serial_cancellable<T>(cancel: &Cancellation, f: impl FnOnce() -> Result<T>) -> Result<T> {
    loop {
        if cancel.is_cancelled() {
            return Err(StudioError::Cancelled);
        }
        match ENGINE.try_lock() {
            Ok(_guard) => {
                if cancel.is_cancelled() {
                    return Err(StudioError::Cancelled);
                }
                return f();
            }
            Err(std::sync::TryLockError::WouldBlock) => {
                std::thread::sleep(std::time::Duration::from_millis(25));
            }
            Err(std::sync::TryLockError::Poisoned(_)) => {
                return Err(invalid("Processing service needs to be restarted."));
            }
        }
    }
}

#[cfg(test)]
mod cancellation_tests {
    use super::*;
    use std::{sync::mpsc, time::Duration};

    #[test]
    fn cancelling_a_queued_job_does_not_wait_for_the_engine_slot() {
        let guard = ENGINE.lock().unwrap();
        let cancel = Cancellation::default();
        let worker_cancel = cancel.clone();
        let (send, receive) = mpsc::channel();
        let worker = std::thread::spawn(move || {
            let result = serial_cancellable(&worker_cancel, || {
                panic!("Cancelled queued work must never enter the engine")
            });
            send.send(matches!(result, Err::<(), _>(StudioError::Cancelled)))
                .unwrap();
        });
        cancel.cancel();
        // Keep ENGINE locked until the cancellation result arrives.
        assert!(receive.recv_timeout(Duration::from_secs(1)).unwrap());
        drop(guard);
        worker.join().unwrap();
    }
}
