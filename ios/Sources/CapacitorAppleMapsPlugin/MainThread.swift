import Foundation

/// Runs `block` synchronously on the main thread and returns its result.
///
/// Unlike `DispatchQueue.main.sync`, this is safe to call from the main thread:
/// it runs the block inline instead of deadlocking. Capacitor dispatches plugin
/// calls off the main thread, so the bridge methods normally hop over via the
/// `DispatchQueue.main.sync` path; this guard keeps them correct if any path ever
/// reaches them already on the main thread (a lifecycle callback, a test, a
/// future caller).
@discardableResult
func runOnMainSync<T>(_ block: () -> T) -> T {
    if Thread.isMainThread {
        return block()
    }
    return DispatchQueue.main.sync(execute: block)
}
