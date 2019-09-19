use "files"
use "options"

primitive HostPortArgParser
  fun apply(args: Array[String] box): (String, String) ? =>
    var h_arg: (Array[String] | None) = None
    var options = Options(args, false)
    options
      .add("host", "", StringArgument)

    for option in options do
      match option
      | ("host", let arg: String) =>
        h_arg = arg.split(":")
      end
    end

    match h_arg
    | let addr: Array[String] =>
      if addr.size() != 2 then
        @printf[I32](
          "'--host' argument should be in format: '127.0.0.1:8080\n"
          .cstring())
        error
      end
      (addr(0)?, addr(1)?)
    else
      @printf[I32]("Must supply required '--host' argument\n".cstring())
      error
    end

primitive MessageLimitArgParser
  fun apply(args: Array[String] box): USize =>
    var message_limit: USize = USize.max_value()
    var options = Options(args, false)
    options
      .add("message-limit", "", I64Argument)

    for option in options do
      match option
      | ("message-limit", let arg: I64) =>
        message_limit = arg.usize()
      end
    end

    if message_limit == USize.max_value() then
      @printf[I32](("MessageLimitParser: No message limit command line " +
        "argument found. Setting as unlimited.\n").cstring())
    end
    message_limit

primitive FilePathArgParser
  fun apply(args: Array[String] box, auth: AmbientAuth): Array[FilePath] val ?
  =>
    var files = Array[String]
    var options = Options(args, false)
    options
      .add("file", "", StringArgument)

    for option in options do
      match option
      | ("file", let arg: String) =>
        let fs = arg.split(",")
        for f in (consume fs).values() do
          files.push(f)
        end
      end
    end

    if files.size() > 0 then
      let filepaths = recover iso Array[FilePath] end
      for f in files.values() do
        filepaths.push(FilePath(auth, f)?)
      end
      consume filepaths
    else
      @printf[I32](("FilePathArgParser: --file/-f argument required. " +
        "Provide comma-separated list of files to read for sending.")
        .cstring())
      error
    end

primitive OutputFilePathArgParser
  fun apply(args: Array[String] box, auth: AmbientAuth): FilePath val ?
  =>
    var file: String = ""
    var options = Options(args, false)
    options
      .add("output-file", "", StringArgument)

    for option in options do
      match option
      | ("output-file", let arg: String) =>
        file = arg
      end
    end

    if file == "" then
      @printf[I32](("OutputFilePathArgParser: --output-file argument " +
        " required. Provide file for writing outputs.").cstring())
      error
    else
      FilePath(auth, file)?
    end

primitive OutputFileDirArgParser
  fun apply(args: Array[String] box, auth: AmbientAuth): String ? =>
    var dir: String = ""
    var options = Options(args, false)
    options
      .add("output-dir", "", StringArgument)

    for option in options do
      match option
      | ("output-dir", let arg: String) =>
        dir = arg
      end
    end

    if dir == "" then
      @printf[I32](("OutputFileDirArgParser: --output-dir argument " +
        " required. Provide file for writing outputs.").cstring())
      error
    else
      dir
    end

primitive SenderTypeArgParser
  fun apply(args: Array[String] box, default: String = "gen"): String =>
    var sender_type: String = default
    var options = Options(args, false)
    options
      .add("sender-type", "", StringArgument)

    for option in options do
      match option
      | ("sender-type", let arg: String) =>
        sender_type = arg
      end
    end

    sender_type

primitive ReceiverTypeArgParser
  fun apply(args: Array[String] box): String ? =>
    var receiver_type: String = ""
    var options = Options(args, false)
    options
      .add("receiver-type", "", StringArgument)

    for option in options do
      match option
      | ("receiver-type", let arg: String) =>
        receiver_type = arg
      end
    end

    if receiver_type == "" then
      @printf[I32]("ReceiverTypeArgParser: --receiver-type is required!\n"
        .cstring())
      error
    else
      receiver_type
    end

primitive ReportIntervalArgParser
  fun apply(args: Array[String] box, default: U64 = 10): U64 =>
    // in seconds
    var report_interval = default
    var options = Options(args, false)
    options
      .add("report-interval", "", I64Argument)

    for option in options do
      match option
      | ("report-interval", let arg: I64) =>
        report_interval = arg.u64()
      end
    end

    report_interval
