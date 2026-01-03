**v0.82**
-- Minor Polish
-- Added Github url to -V and -h

**v0.81**
-- Proper SIGINT handling
-- Now proper terminal returning is ensured
-- Now logs start time and running time in logs

**v0.80**
-- Now Multiprocess worker count can be changed manually (Max 256 workers)
-- Now checks if --threads:off and --tlsemulation:off were used during compilation

**v0.79**
-- Added support for logging
-- Recommended Min. RAM-Buffer size increased to 128 from 64

**v0.78**
-- Program now displays which compiler was used and the -d flag
-- errList renamed to msgList as we will record both messages and errors, also added a function/proc to add messages to the list (and preparations to add logging support)

**v0.77**
-- Added check for compiler flag check

**v.0.76**
-- Testing for FreeBSD started
-- Replaced epochTime with CLOCK_MONOTONIC_RAW & CLOCK_MONOTONIC (When RAW isn't available)
-- Now both tStart and tEnd is recorded for debugging reasons
-- Tweaked Simple Math (CPU) method to reduce compiler 'cheating'

**v0.73**
-- Improved RAM benchmarking logic (Using 64bits (8 bytes) per write instead of 1 bits)
-- Improved clarify in RamWrite()
-- Added simple value correctness check in --memory-buffer-size flag

**v0.71**
-- Added various error/fault detection
-- Smaller adjustments in Nim branch to make it more Nim-like
-- Added support for --skip-memory-test and --memory-buffer-size flags

**v0.7**
-- Improved UX with more detail
-- RAM benchmark now tests GB written/s instead of Write ops/s
-- RAM benchmark now uses preallocated buffer over dynamic writing
-- Preparations for implementing new error & error display
-- Python & Go Support dropped

**v0.6**
-- New branch: Nim
-- Clock check frequency reduced from 'after each 1000 work units' to 'after each 10000 work units'

**v0.5**
-- New branch: Go
-- XOR calculation replaced with pow in Complex Math and Multiprocessing Benchmark
-- RMLL Support dropped

**v0.2**
-- Added RAM Write Ops/s benchmark
-- Added Multiprocessing benchmark
-- Minor UX improvement

**v0.1**
-- Initial alpha release in RMLL & Python
