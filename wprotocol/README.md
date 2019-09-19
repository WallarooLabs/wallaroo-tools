# wprotocol

## Generating Pony code

Place one or more `.wproto` files with message type definitions in your 
target directory. Then run the following:

```
python3 wprotocol.py <target-directory> > messages.pony
```

This will create Pony classes, encoders, and decoders for the types
defined in your `.wproto` files in `messages.pony` in your target
directory.

## Defining wprotocol Message Types

```
message Person {
  name: String
  id: U64
  is_friendly: Bool
  job: Job
  interests: Array[String]
}

message Job {
  company: String
  title: String
  team_sizes: Array[U64]
}
```

Fields can either be builtin types or user-defined types.  

## Builtin Types

F32 - 4 bytes  
F64 - 8 bytes  
U32 - 4 bytes unsigned  
U64 - 8 bytes unsigned  
I32 - 4 bytes signed  
I64 - 8 bytes signed  
Bool  
String  
Array\[T\]  

