# Senders

Senders is a library that makes it easy to quickly prototype external TCP Sources for Wallaroo applications. 

Available sender types:

* `GenSender`: generate messages on the fly and send them over the wire using a generator and an encoder.
* `RateFileSender`: send data from a rate format file. 
* `FixedLengthMessageBlaster`: Reads fixed length messages from a file and blasts them as fast as possible at a TCP location. \[Not yet complete.\]

## Arg Parsing Helper Primitives

The library also provides some general helper Primitives for arg parsing (each one takes `env.args` as an argument to `apply()`: 

* `FilePathArgParser`: `--file`. Specifies the file/s that will be used for sending data. For more than one file, use comma-separation, e.g. `--file file1.txt,file2.txt`.
* `HostPortArgParser`: `--host`. Must be an address in the format `127.0.0.1:8080`. You can use this to derive the `host` and `service` values that must be passed to `GenSender` when constructing it.
* `MessageLimitArgParser`: `--message-limit`. Specifies the max number of messages that will be sent.
* `SenderTypeArgParser`: `--sender-type`. A convenience in case you want to use a `String` to select a sender type at runtime.

## GenSender

You provide the `GenSender` actor with a generator builder and an encoder, and it will use them to generate inputs on the fly, encoding them and sending them over TCP. 

### Example

```
actor Main
  new create(env: Env) =>
    try
      GenSender[U32](env, U32GeneratorBuilder, U32Encoder)
    end

class val U32GeneratorBuilder
  fun apply(): U32Generator =>
    U32Generator

class U32Generator
  fun ref initial_value(): U32 =>
    0

  fun ref apply(u: U32): U32 =>
    u + 1

primitive U32Encoder
  fun apply(u: U32, wb: Writer): ByteSeqIter val =>
    wb.u32_be(u)
    wb.done()
```

```bash
./sender \
--host 127.0.0.1:7000
```

## RateFileSender

You provide the `RateFileSender` actor with a `FilePath` to a file (or an `Array[FilePath] val`) using the rate data file protocol, and it will send data as close to the specified schedule as possible. You must specify a `computer_id` and `socket_id`, which are concepts from the rate file protocol.

Until it hits the optional message limit, `RateFileSender` will read through the provided files in sequence, looping when it reaches the end of the sequence.

### Helper Primitives

* `ComputerSocketArgParser`: `--computer-socket`. To parse a colon separated computer id and socket id.

### Example

```
actor Main
  new create(env: Env) =>
    try
      RateFileSender(env)
    end
```


```bash
./sender \
--file ./data_gen/rate_generator/gen_data.msg \
--host 127.0.0.1:7000 --computer-socket 0:0
```

## Fixed Length Message Blaster

Reads fixed length messages from a file and blasts them as fast as possible at a TCP location. Loads all data from a file into memory and potentially creates many copies of it in order to:

* keep data distribution of messages even with the file
* match the required batch size supplied by the user

Be wary with using with particularly large data files.

### Usage

Has 4 required parameters:

* `--host` ip address to send to, in the format of "HOST:PORT" for example 127.0.01:7669
* `--file` the file to read data from
* `--msg-size` the size of each message in the file
* `--batch-size` the number of messages to send each time we send

```
actor Main
  new create(env: Env) =>
    FixedLengthMessageBlaster(env)
```

```bash
./sender \
--file ../../data/market_spread/nbbo/350-symbols_initial-nbbo-fixish.msg \
--host 127.0.0.1:7669 --batch-size 100 --msg-size 46
```
