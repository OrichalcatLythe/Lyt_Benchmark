## APACHE 2.0 LICENSE
## original at https://github.com/OrichalcatLythe/Lyt_Benchmark

import std/[os, math, random, strutils, strformat, posix, volatile]

# Global Configuration
const VER = "v0.82"
var
    firstRow, secondRow, thirdRow, fourthRow, fifthRow, sixthRow: seq[string] = @[".........", ".........", ".........", "........."]
var
  skipMemoryTest = false
  memoryBufferSizeMB = 256'i64 #Default 256MB for RAM test
  multiprocessworker_count = 32
  enableLogging = true
  interrupted {.volatile.} = false
  startMonotonic: float
  startWallTime: string

var msgList = ""

## Do NOT use const instead of let here, since CLOCK_MONOTONIC aren't exposed as compile-time constants on BSD it will break BSD support since it can't evaluate it as constants.
when declared(CLOCK_MONOTONIC_RAW):
  let RawClock = CLOCK_MONOTONIC_RAW
  const ClockType = "MONOTRONIC_RAW"
else:
  let RawClock = CLOCK_MONOTONIC
  const ClockType = "MONOTRONIC_NON-RAW"

const BenchFault = -1 ##We'll use -1 in score to indicate FAULT as we never should receive a negative score and it's the simplest without rewriting the architecture significantly
const BenchSkip = -2 ##Same reason as above, used when the utility is told to skip a specific test from CLI
const NoDisplay = false ##Helper for addMessage to make the function more readable when we don't want to display the message, only log if logging is enabled, may replace this with enum later for clarity

proc monotonicSeconds(): float =
  var ts: Timespec
  discard clock_gettime(RawClock, ts)
  result = ts.tv_sec.float + ts.tv_nsec.float * 1e-9

proc addMessage(message: string, showmsg: bool = true, log: bool = true) =
  let offset = monotonicSeconds() - startMonotonic
  let timestamp = fmt"[{offset:>8.3f}s] "

  if showmsg:
    msgList &= message & "\n"
  if log and enableLogging:
    var logfile: File
    try:
      logfile = open("lyt_benchmark.log", fmAppend)
      if message in ["[Benchmark Binary Started]"]: ##We leave it like this incase we need to expand it in the future
        logfile.write(message & "\n")
      else:
        logfile.write(timestamp & message & "\n")
    except CatchableError as e:
      enableLogging = false
      msgList &= "⚠ Logger failed! Unable to append \"" & message & "\" !\n[" & $e.name & "] " & e.msg & "\n"
    finally:
      if not isNil(logfile):
        logfile.close()

proc getFormattedWallTime(): string =
  var ts: Timespec
  discard clock_gettime(CLOCK_REALTIME, ts)
  var tm: Tm
  var t: Time = ts.tv_sec

  discard localtime_r(t, tm)

  var buffer = newString(64)
  let res = strftime(cast[cstring](addr buffer[0]), buffer.len, "%Y-%b-%d %H:%M", tm)
  if res > 0:
    buffer.setLen(res.int)
    return buffer
  else:
    return "Unknown Time"

proc printHelpAndExit() =
  let textOut = fmt"""

  Lythe's Simple Server Performance Benchmark {VER}
╟╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╣
 Special Arguments
|| --skip-memory-test - Skips RAM test
|| --memory-buffer-size=## - Sets memory buffer size for RAM test (Given in MB, default is 256)
|| --disableLog - Disables logging.
|| --multiprocess-workers=## - Sets worker count for multiprocess scoring, default is 32, max is 256

For more information check out the original branch on : https://github.com/OrichalcatLythe/Lyt_Benchmark
  """
  stdout.write textOut
  quit(0)

proc parseArgs() =
  if commandLineParams().contains("--disableLog"):
    enableLogging = false
    addMessage("|| Logging disabled via --disableLog")
  else:
    addMessage("[Benchmark Binary Started]", NoDisplay)
  for arg in commandLineParams():
    case arg
    of "-h", "--help":
      printHelpAndExit()
    of "-V", "--version":
      echo "Lythe's Simple Server Performance Benchmark ", VER
      echo "For updates check https://github.com/OrichalcatLythe/Lyt_Benchmark"
      quit(0)
    of "--skip-memory-test", "--skipMemory":
      skipMemoryTest = true
      addMessage("|| RAM write test skipped via --skip-memory-test")
    of "--disableLog":
      discard
    elif arg.startsWith("--memory-buffer-size="):
      let val = arg.split("=", 1)[1]
      try:
        memoryBufferSizeMB = val.parseInt.int64
        if memoryBufferSizeMB < 128:
          addMessage("🛈 Memory Buffer size set below recommended size (128MB), RAM results may be inaccurate.")
        if memoryBufferSizeMB < 1:
          skipMemoryTest = true
          addMessage("⚠ Memory Buffer size set below valid range, skipping.")
      except ValueError:
        addMessage("⚠ Invalid value for --memory-buffer-size (must be integer MB) , using default 256M.")
    elif arg.startsWith("--multiprocess-workers"):
      let val = arg.split("=", 1)[1]
      try:
        multiprocessworker_count = clamp(val.parseInt, 1, 256)
        addMessage("🛈 Multiprocess worker count changed from default to : " & $multiprocessworker_count)
      except ValueError:
        addMessage("⚠ Invalid value for --multiprocess-workers , using default (32).")
    else:
      addMessage("⚠ Unknown option: " & arg & "\n")

##Detect Compiler and -d flag, Clang usually outputs better performant binaries especially with -d:danger
when defined(gcc):
  const COMPILER = "GCC"
elif defined(clang):
  const COMPILER = "Clang"
else:
  const COMPILER = "Unknown"

when defined(danger):
  const COMPILER_MODE = "Danger"
elif defined(release):
  const COMPILER_MODE = "Release"
elif defined(debug):
  const COMPILER_MODE = "Debug"
else:
  const COMPILER_MODE = "Unknown"

const COMPILER_INFO_STR = "Compiler: ⦗" & COMPILER & ":" & COMPILER_MODE & "⦘ Clock: ⦗" & ClockType & "⦘"

proc drawOutput() =
    stdout.write("\e[H\e[2J")

    let textOut = fmt"""
╔═════════════════════════════════════════════════════════════════════════════╗
║ Lythe's Simple Server Performance Benchmark {VER}                           ║
╚═════════════════════════════════════════════════════════════════════════════╝

╔═══════════════════╤════════════════╤════════════════════╤═════════════════╦═╗
║ CPU (Simple Math) ┆ CPU (Complex)  ┆ CPU (Multiprocess) ┆ RAM Write Speed ║ ║
╠═══════════════════╧════════════════╧════════════════════╪═════════════════╬═╣
║                   ╷ M work units/s ╷                    ┆  MB/s (Forced)  ║ ║
╟╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌┼╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌┼╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌┼╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌║ ║
║ {firstRow[0]:<18}┆ {firstRow[1]:<14} ┆ {firstRow[2]:<18} ┆ {firstRow[3]:<13}   ║U║
║ {secondRow[0]:<18}┆ {secondRow[1]:<14} ┆ {secondRow[2]:<18} ┆ {secondRow[3]:<13}   ║n║
║ {thirdRow[0]:<18}┆ {thirdRow[1]:<14} ┆ {thirdRow[2]:<18} ┆ {thirdRow[3]:<13}   ║i║
║ {fourthRow[0]:<18}┆ {fourthRow[1]:<14} ┆ {fourthRow[2]:<18} ┆ {fourthRow[3]:<13}   ║t║
║ {fifthRow[0]:<18}┆ {fifthRow[1]:<14} ┆ {fifthRow[2]:<18} ┆ {fifthRow[3]:<13}   ║s║
╟╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌┼╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌┼╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌┼╌╌╌╌╌╌╌╌╌╌╌╌╌╌╔══╩═╣
║ {sixthRow[0]:<18}┆ {sixthRow[1]:<14} ┆ {sixthRow[2]:<18} ┆ {sixthRow[3]:<13}║Avg.║
╚═══════════════════╧════════════════╧════════════════════╧══════════════╩════╝
{COMPILER_INFO_STR & "\n" & msgList}
   """
    stdout.write textOut

#########################
## SIGINT HANDLER START##
proc onSigInt(sig: cint) {.noconv.} =
  interrupted = true

proc installSigIntHandler() =
  var sa: Sigaction
  sa.sa_handler = onSigInt
  discard sigemptyset(sa.sa_mask)
  sa.sa_flags = 0
  discard sigaction(SIGINT, sa, nil)

proc sigint_restoreTerminal() =
  stdout.write("\e[H\e[2J")   # clear
  addMessage("⚠ Benchmark interrupted (SIGINT: " & $SIGINT & ") \n[Binary Terminated prematurely]\n")
  drawOutput()
  echo "" ##Ensure new line to properly return to terminal

proc sigint_cleanup() =
  sigint_restoreTerminal()
  quit(130)

## SIGINT HANDLER END##
#######################

proc cpuSimpleCalc(): float =
  var score: int = 0
  let tStart = monotonicSeconds()
  let tEnd = tStart + 1.0
  while true:
    for _ in 0..10000:
      volatileStore(addr score, score + 1) ##Don't replace this with 'inc score' , both Clang and Wyvern will optimize the loop away as Score+10000 that way.
    if monotonicSeconds() >= tEnd: break
  return score.float / 1_000_000.0

proc cpuComplexCalc(): float =
  var score: int = 0
  randomize()
  let tStart = monotonicSeconds()
  let tEnd = tStart + 1.0
  while true:
    for _ in 0..10000:
      discard 913 + 9311
      discard 53 - 21
      discard 91 / 1339
      discard rand(0..950000000)
      discard sin(17.1)
      discard cos(37.0)
      discard pow(7.0, 31.0)
      discard sin(pow(3.0, 17.0))
      inc score
    if monotonicSeconds() >= tEnd: break
  return score.float / 1_000_000.0

proc multiprocessWorker(): int =
  var score: int = 0
  randomize()
  let tStart = monotonicSeconds()
  let tEnd = tStart + 1.0
  while true:
    for _ in 0..10000:
      discard 913 + 9311
      discard 53 - 21
      discard 91 / 1339
      discard rand(0..950000000)
      discard sin(17.1)
      discard cos(37.0)
      discard pow(7.0, 31.0)
      discard sin(pow(3.0, 17.0))
      inc score
    if monotonicSeconds() >= tEnd: break
  return score

proc cpuMultiprocess(): float =
  let workers = multiprocessworker_count
  # Use sequences instead of fixed-size arrays
  var pipes = newSeq[array[2, cint]](workers)
  var pids = newSeq[Pid](workers)

  for i in 0..<workers:
    if pipe(pipes[i]) != 0:
      quit("pipe() failed")

    let pid = fork()
    if pid == 0:
      # Child
      discard close(pipes[i][0]) # close read end

      let score = multiprocessWorker()
      discard write(pipes[i][1], addr score, sizeof(score))
      discard close(pipes[i][1])
      quit(0)

    # Parent
    pids[i] = pid
    discard close(pipes[i][1]) # close write end

  var totalScore = 0
  for i in 0..<workers:
    var s: int
    discard read(pipes[i][0], addr s, sizeof(s))
    discard close(pipes[i][0])
    totalScore += s
    var status: cint
    discard waitpid(pids[i], status, 0)

  return totalScore.float / 1_000_000.0


proc ramWrite(): float =
    if skipMemoryTest:
      return BenchSkip
    let bufSizeMB = memoryBufferSizeMB
    let tmpElements = (bufSizeMB * 1024 * 1024) div 8 #Using uint64 | 8 bytes
    var buf: seq[uint64]

    try:
      buf = newSeq[uint64](tmpElements)
    except CatchableError:
      addMessage("⚠ Unable to assign RAM buffer (" &
                $bufSizeMB & " MB).")
      return BenchFault

    var writtenBytes: int64 = 0
    var idx = 0
    let tStart = monotonicSeconds()
    let tEnd = tStart + 1.0

    {.push boundChecks: off.}
    while true:
      for _ in 1..10000:
        volatileStore(addr buf[idx], 1'u64)
        inc idx
        inc writtenBytes, 8
        if idx == tmpElements:
          idx = 0
      if monotonicSeconds() >= tEnd: break
    {.pop.}
    return writtenBytes.float / 1_000_000.0

proc formatVal(val: float): string =
    if val == BenchFault: return "FAULT"
    if val == BenchSkip: return "SKIPPED"
    return fmt"{val:06.3f}"

proc runBenchmark(rowIdx: int, colIdx: int, task: proc(): float) =
  if interrupted: sigint_cleanup()
  let score = task()
  case rowIdx
  of 0: firstRow[colIdx] = formatVal(score)
  of 1: secondRow[colIdx] = formatVal(score)
  of 2: thirdRow[colIdx] = formatVal(score)
  of 3: fourthRow[colIdx] = formatVal(score)
  of 4: fifthRow[colIdx] = formatVal(score)
  else: discard
  drawOutput()

proc calculateAverage(colIdx: int) =
  try:
    let vals = [
      firstRow[colIdx],
      secondRow[colIdx],
      thirdRow[colIdx],
      fourthRow[colIdx],
      fifthRow[colIdx]
    ]

    var sum = 0.0
    for v in vals:
      if v == "FAULT" or v == "SKIPPED":
        sixthRow[colIdx] = v
        drawOutput()
        return
      sum += v.parseFloat
    sixthRow[colIdx] = formatVal(sum / 5.0)
    drawOutput()
  except CatchableError:
    sixthRow[colIdx] = "FAULT"
  drawOutput()

proc main() =
  startMonotonic = monotonicSeconds()
  startWallTime = getFormattedWallTime()

  installSigIntHandler()
  parseArgs()
  addMessage("Start time : " & startWallTime, NoDisplay)
  addMessage(COMPILER_INFO_STR, NoDisplay)
  when compileOption("threads"):
    addMessage("🛈 Threads support is enabled in the binary, this is not recommended.")
  when compileOption("tlsemulation"):
    addMessage("🛈 TLSemulation is enabled in the binary, this is not recommended and is almost certain to skew Complex and Multiprocess results.")
  drawOutput()
  for col in 0..3:
      for row in 0..4:
        if interrupted: sigint_cleanup()
        case col
          of 0: runBenchmark(row, col, cpuSimpleCalc)
          of 1: runBenchmark(row, col, cpuComplexCalc)
          of 2: runBenchmark(row, col, cpuMultiprocess)
          of 3: runBenchmark(row, col, ramWrite)
          else: discard
      calculateAverage(col)
  addMessage("Benchmark finished with the following average scores : " & sixthRow[0] & " (CPU Simple Math)┆ " & sixthRow[1] & " (CPU Complex Math)┆ " & sixthRow[2] & " (Multiprocess) ┆ " & sixthRow[3] & " (RAM Write MB/s (Forced))", NoDisplay)
  addMessage("[End of benchmark]\n\n", NoDisplay)
  echo "" ##Ensure new line to properly return to terminal
if isMainModule:
  main()
