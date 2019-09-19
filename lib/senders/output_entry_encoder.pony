use "buffered"
use "files"
use "time"
use "../bytes"


trait val OutputEntryEncoder
  fun apply(data: Array[U8] val, wb: Writer): ByteSeqIter box

class OutputEntryWriter
  let _encoder: OutputEntryEncoder
  let _file: File
  let _wb: Writer = Writer
  let _buf: Array[U8] = Array[U8](8)

  new create(e: OutputEntryEncoder, f: File) =>
    _encoder = e
    _file = f

  fun ref apply(data: Array[U8] val) =>
    _buf.clear()
    _file.write(Bytes.from_u64(Time.nanos(), _buf))
    _buf.clear()
    let entry = _encoder(data, _wb)
    var size: USize = 0
    for bs in entry.values() do
      size = size + bs.size()
    end
    _file.write(Bytes.from_u32(size.u32(), _buf))
    _file.writev(entry)

  fun ref write_time() =>
    _buf.clear()
    _file.write(Bytes.from_u64(Time.nanos(), _buf))
