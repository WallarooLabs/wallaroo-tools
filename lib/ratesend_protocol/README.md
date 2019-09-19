# ratesend protocol

A protocol used for controlling the times at which messages are sent into a 
system. For each message to be sent, you specify a computer:socket pair that will be sending it as well as a send time. The send time is an offset from the start time, which can either be calculated at a sender or shared across senders to sync them.

An example of a script for generating data files based on this protocol can be found in the Bid Deduplicator project [here](../../apps/bid_deduplicator/data_gen/rate_generator/blaster_gen.py).

## Format

```
 2 bytes - computer id (U16)  <-- Identifies sending computer
 2 bytes - socket id (U16)    <-- Identifies socket on sending computer
 4 bytes - entry size (U32)   <-- Header
 8 bytes - send time (U64)    <-- Ideal send time offset from start time
 4 bytes - payload size (U32) 
 n bytes - payload (bytes)    <-- The message (which might include its own 
                                  header)
```

