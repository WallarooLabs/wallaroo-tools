use "buffered"
use "files"
use "net"
use "options"
use "time"
use "../bytes"
use "../ratesend_protocol"


primitive RateFileSender
  fun apply(env: Env, output_entry_encoder: OutputEntryEncoder):
    _RateFileSender ?
  =>
    let auth = env.root as AmbientAuth
    let message_limit = MessageLimitArgParser(env.args)
    (let host, let port) = HostPortArgParser(env.args)?
    let filepaths = FilePathArgParser(env.args, auth)?
    (let computer_id, let socket_id) = ComputerSocketArgParser(env.args)?
    let output_dir = OutputFileDirArgParser(env.args, auth)?
    let output_fpath_name = output_dir + "/sender-output-" + computer_id.string() + ":" + socket_id.string()
    let output_fpath = FilePath(auth, output_fpath_name)?
    let report_interval = ReportIntervalArgParser(env.args)
    _RateFileSender(filepaths, output_fpath, output_entry_encoder,
      report_interval, host, port, computer_id, socket_id, auth, message_limit)

actor _RateFileSender
  let _conn: TCPConnection
  // let _output_entry_writer: OutputEntryWriter
  let _host: String
  let _port: String
  let _computer_id: U16
  let _socket_id: U16
  let _auth: AmbientAuth
  let _message_limit: USize
  var _sent: USize = 0
  var _paused: Bool = true
  var _epoch: USize = 0
  let _all_files: Array[File] = Array[File]
  var _file_idx: USize = 0
  var _cur_file: (File | None) = None

  var _start_time: U64
  var _last_send_time: U64

  let _thr_reporter: ThroughputReporter

  var _timers: Timers = Timers

  // For mods...
  // let prog: Regex = Regex("t([MU])([-+])(\\d+)@(\\d+)")

  new create(input_fpath: (FilePath | Array[FilePath] val),
    output_fpath: FilePath, output_entry_encoder: OutputEntryEncoder,
    report_interval: U64,
    host: String, port: String, computer_id: U16, socket_id: U16,
    auth: AmbientAuth, message_limit: USize = USize.max_value())
  =>
    match input_fpath
    | let f: FilePath =>
      _all_files.push(File(f))
    | let fs: Array[FilePath] val =>
      for f in fs.values() do
        _all_files.push(File(f))
      end
    end
    // _output_entry_writer = OutputEntryWriter(output_entry_encoder,
    //   File(output_fpath))
    _host = host
    _port = port
    _computer_id = computer_id
    _socket_id = socket_id
    _auth = auth
    _message_limit = message_limit
    _start_time = Time.nanos()
    _last_send_time = _start_time
    _thr_reporter = ThroughputReporter(File(output_fpath), report_interval)
    let tcp_auth = TCPConnectAuth(_auth)
    _conn = TCPConnection(tcp_auth, _RateFileSenderNotify(this, _host,
      _port), _host, _port)
    try
      _cur_file = _all_files(0)?
    else
      @printf[I32]("_RateFileSender: No file specified!\n".cstring())
      _conn.dispose()
    end

  be send_next(epoch: USize) =>
    try
      let file = _cur_file as File
      if _sent < _message_limit then
        if _epoch == epoch then
          if file.position() < file.size() then
            let c_id_bs = file.read(2)
            let computer_id = Bytes.to_u16(c_id_bs(0)?, c_id_bs(1)?)
            let s_id_bs = file.read(2)
            let socket_id = Bytes.to_u16(s_id_bs(0)?, c_id_bs(1)?)
            let e_size_bs = file.read(4)
            let entry_size = Bytes.to_u32(e_size_bs(0)?, e_size_bs(1)?,
              e_size_bs(2)?, e_size_bs(3)?)


            if (_computer_id == computer_id) and (_socket_id == socket_id) then
              // Read header and entry
              (let send_time, let payload) =
                RateSendEntryDecoder(file.read(entry_size.usize()))?
              let t_next = _start_time + send_time

              // For mods...
              // res = r(a(3)?)?
              // t   = (send time, mod, raw data)
              // mod = (s|M|U, -|+, time delta, offset)

              // let mod =
              //   if res.size() == 0 then
              //     ("s", "+", 0, 0)
              //   else
              //     (res(1)?, res(2)?, res(3)?.u64(), res(4)?)

              // For mods...
              // new_data = apply_mod(t_next, mod, payload)

              let now = Time.nanos()
              if t_next > now then
                let t_delta = t_next - now
                _timers(Timer(_DelaySendNext(this, payload, send_time),
                  t_delta))
              else
                _send_data(payload, send_time)
              end
            else
              // Skip this entry since it's not for us.
              file.seek(entry_size.isize())
              send_next(_epoch)
            end
          else
            _line_up_next_file()
            send_next(_epoch)
          end
        end
      else
        _conn.dispose()
      end
    else
      @printf[I32]("_RateFileSender: failed.\n".cstring())
      _conn.dispose()
    end

  be send_data(payload: Array[U8] val, send_time: U64) =>
    _send_data(payload, send_time)

  fun ref _send_data(payload: Array[U8] val, send_time: U64) =>
    _conn.write(payload)
    _last_send_time = send_time
    _sent = _sent + 1
    // (_cur_file as File).write(Bytes.from_u64(Time.nanos(), _buf))
    // (_cur_file as File).seek(8)

    // Write entry to sender output file (trimming off header for encoder)
    // _output_entry_writer(payload.trim(4))
    _thr_reporter(Time.nanos(), payload.size())

    send_next(_epoch)

  fun ref _line_up_next_file() =>
    _file_idx = (_file_idx + 1) % _all_files.size()
    try
      _cur_file = _all_files(_file_idx)?
    end
    // We need a new start time since we're starting a new file with
    // new relative offsets.
    _start_time = _start_time + _last_send_time

  be pause_sending(v: Bool) =>
    if (_paused == true) and (v == false) then
      _paused = false
      send_next(_epoch)
    elseif (_paused == false) and (v == true) then
      _paused = true
      _epoch = _epoch + 1
    end

class _RateFileSenderNotify is TCPConnectionNotify
  let _sender: _RateFileSender
  let _host: String
  let _port: String

  new iso create(sender: _RateFileSender, h: String, s: String) =>
    _sender = sender
    _host = h
    _port = s

  fun ref connect_failed(conn: TCPConnection ref) =>
    @printf[I32]("Unable to connect\n".cstring())
    conn.dispose()

  fun ref closed(conn: TCPConnection ref) =>
    @printf[I32]("Connection closed!\n".cstring())
    conn.dispose()

  fun ref connected(conn: TCPConnection ref) =>
    if conn.local_address() != conn.remote_address() then
      conn.set_nodelay(true)
    end
    @printf[I32]("Connected to %s:%s\n".cstring(), _host.cstring(),
      _port.cstring())
    _sender.pause_sending(false)

  fun ref throttled(conn: TCPConnection ref) =>
    _sender.pause_sending(true)

  fun ref unthrottled(conn: TCPConnection ref) =>
    _sender.pause_sending(false)

class _DelaySendNext is TimerNotify
  let _sender: _RateFileSender
  let _payload: Array[U8] val
  let _send_time: U64

  new iso create(s: _RateFileSender, payload: Array[U8] val,
    send_time: U64)
  =>
    _sender = s
    _payload = payload
    _send_time = send_time

  fun ref apply(timer: Timer, count: U64): Bool =>
    _sender.send_data(_payload, _send_time)
    false

primitive ComputerSocketArgParser
  fun apply(args: Array[String] box): (U16, U16) ? =>
    var computer_id: (U16 | None) = None
    var socket_id: (U16 | None) = None
    var options = Options(args, false)
    options
      .add("computer-socket", "", StringArgument)

    for option in options do
      match option
      | ("computer-socket", let arg: String) =>
        let cs = arg.split(":")
        computer_id = cs(0)?.u16()?
        socket_id = cs(1)?.u16()?
      end
    end

    match (computer_id, socket_id)
    | (let c_id: U16, let s_id: U16) =>
      (c_id, s_id)
    else
      @printf[I32](("ComputerSocketArgParser: --computer-socket argument " +
        "required. Provide colon-separated computer and socket ids." +
        "e.g. --computer-socket 1:5").cstring())
      error
    end
