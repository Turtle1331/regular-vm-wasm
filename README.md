# regular-vm-wasm
[REGULAR VM](https://github.com/regular-vm/specification) interpreter written in Wasm text format

## Features

- [x] Core instruction set + `hlt`
- [ ] Program file loader
- [ ] Useful debug messages
- [ ] Environment variable flags
- [ ] Device API extension
- [ ] Memory paging

## Usage

You should be able to run it with any Wasi runtime that supports WASI and preloading.  Here is the command using [Wasmtime](https://github.com/bytecodealliance/wasmtime):

```
wasmtime run interpreter.wat --preload hex_print=hex_print.wat
```

Currently, a recursive Fibonacci program is hard-coded into the data section at the bottom.  It calculates F(22) = 0x452f (17711).  It prints the result as a 32-bit little-endian hex value, so you should see `2f450000`.

It also exports a function named `test` which currently tests a single instruction (2 + 2) and returns the result.  To test with Wasmtime:

```
wasmtime run interpreter.wat --preload hex_print=hex_print.wat --invoke test
```

You should see a warning, followed by `4`.
