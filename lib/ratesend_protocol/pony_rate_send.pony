use "buffered"


// type Mods is Array[U8] val

type RateSendEntry is (U64, Array[U8] val)//, Mods)

primitive RateSendEncoder
  fun apply(send_time: U64, computer_id: U16, socket_id: U16,
    payload: Array[U8] val, mods: Array[U8] val, wb: Writer = Writer):
    ByteSeqIter val
  =>
    wb.u16_be(computer_id)
    wb.u16_be(socket_id)
    wb.u64_be(send_time)
    wb.u32_be(payload.size().u32())
    wb.write(payload)
    // ifdef debug then
    //   if mods.size() != 10 then
    //     @printf[I32]("Mods field must be 10 bytes!\n".cstring())
    //     @exit[None](2)
    //   end
    // end
    // wb.write(mods)
    wb.u64_be(0)
    wb.done()

primitive RateSendEntryDecoder
  fun apply(data: Array[U8] val, rb: Reader = Reader): RateSendEntry ? =>
    rb.append(data)
    let send_time = rb.u64_be()?
    let payload_size = rb.u32_be()?
    let payload = rb.block(payload_size.usize())?
    // let mods = rb.block(10)?
    (send_time, consume payload)//, mods)
