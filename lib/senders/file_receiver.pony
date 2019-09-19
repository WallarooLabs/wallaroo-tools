

/*

Copyright 2017 The Wallaroo Authors.

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
 implied. See the License for the specific language governing
 permissions and limitations under the License.

*/

use "files"
use "net"
use "time"
use "../bytes"


primitive FileReceiver
  fun apply(env: Env, output_entry_encoder: OutputEntryEncoder) ? =>
    let auth = env.root as AmbientAuth
    (let host, let port) = HostPortArgParser(env.args)?
    let output_fpath = OutputFilePathArgParser(env.args, auth)?
    let report_interval = ReportIntervalArgParser(env.args)

    let tcp_auth = TCPListenAuth(auth)
    TCPListener(tcp_auth,
      ListenerNotify(env.out, env.err, output_fpath, output_entry_encoder,
        report_interval, host, port), host, port)

class ListenerNotify is TCPListenNotify
  let _stdout: OutStream
  let _stderr: OutStream
  let _fpath: FilePath
  let _output_entry_encoder: OutputEntryEncoder
  let _report_interval: U64
  let _host: String
  let _port: String

  new iso create(stdout: OutStream,
    stderr: OutStream,
    fpath: FilePath,
    output_entry_encoder: OutputEntryEncoder,
    report_interval: U64,
    host: String,
    port: String)
  =>
    _stdout = stdout
    _stderr = stderr
    _fpath = fpath
    _output_entry_encoder = output_entry_encoder
    _report_interval = report_interval
    _host = host
    _port = port

  fun ref listening(listen: TCPListener ref) =>
    _stdout.print("Listening on " + _host + ":" + _port)

  fun ref not_listening(listen: TCPListener ref) =>
    _stderr.print("Unable to listen\n")

  fun ref connected(listen: TCPListener ref): TCPConnectionNotify iso^ =>
    ConnectionNotify(_stdout, _stderr, _fpath, _output_entry_encoder,
      _report_interval)

class ConnectionNotify is TCPConnectionNotify
  let _stdout: OutStream
  let _stderr: OutStream
  // let _output_entry_writer: OutputEntryWriter
  let _thr_reporter: ThroughputReporter
  var _read_header: Bool = true

  new iso create(so: OutStream, se: OutStream, fpath: FilePath,
    output_entry_encoder: OutputEntryEncoder, report_interval: U64)
  =>
    _stdout = so
    _stderr = se
    // _output_entry_writer = OutputEntryWriter(output_entry_encoder,
    //   File(fpath))
    _thr_reporter = ThroughputReporter(File(fpath), report_interval)

  fun ref received(conn: TCPConnection ref, d: Array[U8] iso, n: USize): Bool
  =>
    if _read_header then
      try
        let expect = Bytes.to_u32(d(0)?, d(1)?, d(2)?, d(3)?).usize()
        try
          conn.expect(expect)?
        else
          @printf[I32]("Conn expect error!\n".cstring())
        end

        _read_header = false
      else
        _stderr.print("Bad framed header value. Exiting.")
        conn.close()
      end
    else
      // Write receiver output entry
      // _output_entry_writer(consume d)
      _thr_reporter(Time.nanos(), d.size())

      try
        conn.expect(4)?
      else
        @printf[I32]("Conn expect error!\n".cstring())
      end
      _read_header = true
    end

    true

  fun ref accepted(conn: TCPConnection ref) =>
    @printf[I32]("Accepted connection!\n".cstring())
    try
      conn.expect(4)?
    else
      @printf[I32]("Conn expect error!\n".cstring())
    end

  fun ref connect_failed(conn: TCPConnection ref) =>
    None
