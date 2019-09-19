use "buffered"


primitive PayloadSizeAndPayload
  fun apply(bs: ByteSeq val, header_size: USize, rb: Reader = Reader):
    (USize, ByteSeq) ?
  =>
    rb.append(bs)
    _payload_size_and_payload(header_size, rb)?

  fun from_byte_seq_iter(bsi: ByteSeqIter val, header_size: USize,
    rb: Reader = Reader): (USize, ByteSeq) ?
  =>
    for bs in bsi.values() do
      rb.append(bs)
    end
    _payload_size_and_payload(header_size, rb)?

  fun _payload_size_and_payload(header_size: USize, rb: Reader):
    (USize, ByteSeq) ?
  =>
    let payload_size =
      match header_size
      | 1 => rb.u8()?
      | 2 => rb.u16_be()?
      | 4 => rb.u32_be()?
      | 8 => rb.u64_be()?
      else
        error
      end
    (payload_size.usize(), rb.block(rb.size())?)
