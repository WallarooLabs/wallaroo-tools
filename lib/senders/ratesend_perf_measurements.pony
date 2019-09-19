use "collections"
use "files"
use "regex"
use "../bytes"


primitive RatesendPerfMeasurer
  fun sender_throughput(auth: AmbientAuth, sender_output_dir: String):
    Map[String, USize] ?
  =>
    let sender_odir = Directory(FilePath(auth, sender_output_dir)?)?
    let sender_ofiles = Map[String, File]
    _load_sender_entries(auth, sender_odir, sender_ofiles) ?
    let sender_throughputs = Map[String, USize]
    for (ids, file) in sender_ofiles.pairs() do
      let thr = _calculate_avg_sender_throughput(file)?
      sender_throughputs(ids) = thr
    end
    sender_throughputs

  fun receiver_throughput(auth: AmbientAuth, receiver_output_file: String):
    USize ?
  =>
    let rcvr_ofile = File(FilePath(auth, receiver_output_file)?)
    _calculate_avg_receiver_throughput(rcvr_ofile)?

  // fun apply(auth: AmbientAuth, data_file: String, sender_output_dir: String,
  //   receiver_output_file: String): String ?
  // =>
  //   let dfile = File(FilePath(auth, data_file)?)
  //   let rcvr_ofile = File(FilePath(auth, receiver_output_file)?)
  //   let sender_odir = Directory(FilePath(auth, sender_output_dir)?)
  //   let sender_ofiles = Map[String, File]
  //   _load_sender_entries(sender_odir, sender_ofiles)

  fun _load_sender_entries(auth: AmbientAuth, dir: Directory,
    m: Map[String, File]) ?
  =>
    let ofile_pattern: Regex = Regex("^sender-output-(\\d+)\\:(\\d+)")?
    for e in dir.entries()?.values() do
      try
        let matched = ofile_pattern(e)?
        let computer_id = matched(1)?.u16()?
        let socket_id = matched(2)?.u16()?
        let file = File(FilePath(auth, e)?)
        m(computer_id.string() + ":" + socket_id.string()) = file
      // TODO: The Regex library uses errors for control here.
      end
    end

  fun _calculate_avg_receiver_throughput(file: File): USize ? =>
    var earliest_ts: U64 = _convert_to_ts(file.read(8))?
    var latest_ts: U64 = 0
    file.seek_start(0)
    var total_msgs: USize = 0
    while file.position() < file.size() do
      total_msgs = total_msgs + 1
      let next_ts = _convert_to_ts(file.read(8))?
      latest_ts = next_ts
      let next_size = _convert_to_size(file.read(4))?
      file.seek(next_size.isize())
    end
    let total_seconds = (latest_ts - earliest_ts) / 1_000_000_000
    total_msgs / total_seconds.usize()

  fun _calculate_avg_sender_throughput(file: File): USize ? =>
    let total_msgs = file.size() / 8
    var earliest_ts: U64 = _convert_to_ts(file.read(8))?
    file.seek_end(8)
    var latest_ts: U64 = _convert_to_ts(file.read(8))?
    let total_seconds = (latest_ts - earliest_ts) / 1_000_000_000
    total_msgs / total_seconds.usize()

  fun _convert_to_ts(data: Array[U8] box): U64 ? =>
    Bytes.to_u64(data(0)?, data(1)?, data(2)?, data(3)?, data(4)?, data(5)?,
      data(6)?, data(7)?)

  fun _convert_to_size(data: Array[U8] box): USize ? =>
    Bytes.to_u32(data(0)?, data(1)?, data(2)?, data(3)?).usize()

