/*

Copyright 2018 The Wallaroo Authors.

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

use "ponytest"
use "./../../lib/encode_decode"


actor Main is TestList
  new create(env: Env) => PonyTest(env, this)
  new make() => None
  fun tag tests(test: PonyTest) =>
    test(_DecoderCanDecodeWhatEncoderProduces)
    test(_EncoderSetsTheCorrectPayloadLength)

class iso _DecoderCanDecodeWhatEncoderProduces is UnitTest
  fun name(): String =>
    "wprotocol/pony_tests/" + __loc.type_name()

  fun apply(h: TestHelper) ? =>
    // given
    let item1 = Item("item1")
    let item2 = Item("item2")
    let inner_thing = InnerThing(recover [item1; item2] end, 10)
    let outer_thing = OuterThing(1, 2, 3, 4, 5.0, 6.0, true, "thing",
      recover [7; 8; 9] end, recover [recover [1; 2] end; recover [3] end] end,
      inner_thing)
    let encoded = OuterThingEncoder(outer_thing)
    // We're assuming that the encoder uses a 4 byte header.
    (_, let stripped_encoded) =
      PayloadSizeAndPayload.from_byte_seq_iter(encoded, 4)?

    // when
    let decoded = OuterThingDecoder(stripped_encoded as Array[U8] val)?

    // then
    h.assert_eq[OuterThing](decoded, outer_thing)

class iso _EncoderSetsTheCorrectPayloadLength is UnitTest
  fun name(): String =>
    "bid_deduplicator/bid/" + __loc.type_name()

  fun apply(h: TestHelper) ? =>
    // given
    let item1 = Item("item1")
    let item2 = Item("item2")
    let inner_thing = InnerThing(recover [item1; item2] end, 10)
    let outer_thing = OuterThing(1, 2, 3, 4, 5.0, 6.0, true, "thing",
      recover [7; 8; 9] end, recover [recover [1; 2] end; recover [3] end] end,
      inner_thing)

    let encoded = OuterThingEncoder(outer_thing)

    // when
    // We're assuming that the encoder uses a 4 byte header.
    (let payload_size, let payload) =
      PayloadSizeAndPayload.from_byte_seq_iter(encoded, 4)?

    // then
    h.assert_eq[USize](payload_size, payload.size())
