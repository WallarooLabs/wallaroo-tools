use "buffered"
use "net"


interface val _GeneratorBuilder[T: Any val]
  fun apply(): _Generator[T]

interface _Generator[T: Any val]
  fun ref initial_value(): T
  fun ref apply(t: T): T

interface val _Encoder[T: Any val]
  fun apply(t: T, wb: Writer): ByteSeqIter val

primitive GenSender[T: Any val]
  fun apply(env: Env, gb: _GeneratorBuilder[T], encoder: _Encoder[T]):
    _GenSender[T] ?
  =>
    let auth = env.root as AmbientAuth
    let message_limit = MessageLimitArgParser(env.args)
    (let host, let port) = HostPortArgParser(env.args)?
    _GenSender[T](gb, encoder, host, port, auth, message_limit)

actor _GenSender[T: Any val]
  let _wb: Writer = Writer
  let _gen: _Generator[T]
  let _encoder: _Encoder[T]
  var _last_value: T
  let _conn: TCPConnection
  let _host: String
  let _port: String
  let _auth: AmbientAuth
  let _message_limit: USize
  var _sent: USize = 0
  var _paused: Bool = true
  var _epoch: USize = 0

  new create(gb: _GeneratorBuilder[T], encoder: _Encoder[T],
    host: String, port: String, auth: AmbientAuth,
    message_limit: USize = USize.max_value())
  =>
    _gen = gb()
    _last_value = _gen.initial_value()
    _encoder = encoder
    _host = host
    _port = port
    _auth = auth
    _message_limit = message_limit
    let tcp_auth = TCPConnectAuth(_auth)
    _conn = TCPConnection(tcp_auth, _GenSenderNotify[T](this, _host, _port),
      _host, _port)

  be send(epoch: USize) =>
    if _sent < _message_limit then
      if _epoch == epoch then
        let next_value = _gen.apply(_last_value)
        _conn.writev(_encoder(next_value, _wb))
        _last_value = next_value
        _sent = _sent + 1
        send(_epoch)
      end
    else
      _conn.dispose()
    end

  be pause_sending(v: Bool) =>
    if (_paused == true) and (v == false) then
      _paused = v
      send(_epoch)
    elseif (_paused == false) and (v == true) then
      _paused = v
      _epoch = _epoch + 1
    end


class _GenSenderNotify[T: Any val] is TCPConnectionNotify
  let _sender: _GenSender[T]
  let _host: String
  let _port: String

  new iso create(sender: _GenSender[T], h: String, s: String) =>
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
