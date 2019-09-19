use "files"
use "time"


class ThroughputReporter
  let _file: File
  let _report_interval: U64
  let _report_interval_nanos: U64
  var _initial_ts: U64 = 0 // needs to be updated by first message
  var _interval_initial_ts: U64 = 0
  var _count: U64 = 0
  var _total_bytes: USize = 0
  var _interval_count: U64 = 0
  var _interval_total_bytes: USize = 0

  new create(file: File, report_interval: U64) =>
    _file = file
    _file.set_length(0)
    _report_interval = report_interval
    _report_interval_nanos = report_interval * 1_000_000_000
    _file.print("ts,total time,report interval,interval thr,interval bytes,total thr,total bytes")

  fun ref apply(ts: U64, bytes: USize) =>
    if _initial_ts == 0 then
      _initial_ts = ts
      _interval_initial_ts = ts
    end
    if ts > (_interval_initial_ts + _report_interval_nanos) then
      _report(ts)
      _interval_count = 0
      _interval_total_bytes = 0
      _interval_initial_ts = ts
    end
    _interval_count = _interval_count + 1
    _interval_total_bytes = _interval_total_bytes + bytes
    _count = _count + 1
    _total_bytes = _total_bytes + bytes

  fun ref _report(now: U64) =>
    let vnow = _interval_initial_ts + _report_interval_nanos
    let total_time = vnow - _initial_ts
    let interval_thr = _interval_count / _report_interval
    let interval_thr_bytes = _interval_total_bytes / _report_interval.usize()
    let total_thr = _count / (total_time / 1_000_000_000)
    let total_thr_bytes = _total_bytes / (total_time.usize() / 1_000_000_000)
    @printf[I32]("%s,%s,%s,%s,%s,%s\n".cstring(), _interval_count.string().cstring(), _interval_total_bytes.string().cstring(), _count.string().cstring(), _total_bytes.string().cstring(), total_thr.string().cstring(), total_thr_bytes.string().cstring())
    _file.print(
      now.string() + "," +
      total_time.string() + "," +
      _report_interval.string() + "," +
      interval_thr.string() + "," +
      interval_thr_bytes.string() + "," +
      total_thr.string() + "," +
      total_thr_bytes.string())
