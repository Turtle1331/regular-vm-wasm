(module
    ;; Import WASI functions for stdio
    (import "wasi_unstable" "fd_write" (func $fd_write (param i32 i32 i32 i32) (result i32)))
    (import "wasi_unstable" "fd_read" (func $fd_read (param i32 i32 i32 i32) (result i32)))

    (memory 1)  ;; Create one page of memory
    (export "memory" (memory 0))  ;; Export the memory to WASI

    (func $hex_digit (export "hex_digit") (param $value i32) (result i32)
        ;; Take the last 4 bits of the value
        (local.set $value
            (i32.and
                (local.get $value)
                (i32.const 0xf)
            )
        )
        ;; Character is value plus offset
        (i32.add
            (local.get $value)
            ;; Split into cases 0-9 and a-f
            (if (result i32)
                (i32.le_u (local.get $value) (i32.const 0x9))
                (then
                    (i32.const 0x30)  ;; 0-9 offset is '0' (0x30)
                )
                (else
                    (i32.const 0x57)  ;; a-f offset is 'a' (0x61) - 0xa
                )
            )
        )
    )

    ;; hex_write_le: takes a memory pointer + length and an i32 value to be written to memory as a hex string in little-endian order
    ;; result: 0 if successful, 1 if not enough space
    (func $hex_write_le (export "hex_write_le") (param $cio_start i32) (param $cio_len i32) (param $value i32) (result i32)
        (if (result i32)
            (i32.ge_u (local.get $cio_len) (i32.const 8))  ;; memory length must be at least 8 (digits needed for 32-bit hex value)
            (then
                ;; reuse $cio_len as for-loop counter
                (local.set $cio_len (i32.const 4))
                (loop $loop
                    ;; write lower 4 bits as hex digit
                    (i32.store8
                        offset=1
                        (local.get $cio_start)
                        (call $hex_digit
                            (local.get $value)
                        )
                    )
                    ;; write upper 4 bits as hex digit
                    (i32.store8
                        (local.get $cio_start)
                        (call $hex_digit
                            (i32.shr_u (local.get $value) (i32.const 4))
                        )
                    )

                    ;; Move to next byte
                    (local.set $value
                        (i32.shr_u (local.get $value) (i32.const 8))
                    )
                    (local.set $cio_start
                        (i32.add (local.get $cio_start) (i32.const 2))
                    )
                    ;; Decrement loop counter and repeat if not zero
                    ;; Repeat until all 4 bytes (8 digits) written
                    (br_if $loop
                        (local.tee $cio_len
                            (i32.sub (local.get $cio_len) (i32.const 1))
                        )
                    )
                )
                (i32.const 0)  ;; success
            )
            (else
                (i32.const 1)  ;; error: not enough space
            )
        )
    )

    ;; hex_str_le: takes a i32 value and returns two i32 values containing the hex representation of the value
    (func $hex_str_le (export "hex_str_le") (param $value i32) (result i32 i32)
        (i32.or
            (i32.or
                (call $hex_digit
                    (i32.shr_u (local.get $value) (i32.const 4))
                )
                (i32.shl
                    (call $hex_digit (local.get $value))
                    (i32.const 8)
                )
            )
            (i32.or
                (i32.shl
                    (call $hex_digit
                        (i32.shr_u (local.get $value) (i32.const 8))
                    )
                    (i32.const 24)
                )
                (i32.shl
                    (call $hex_digit
                        (i32.shr_u (local.get $value) (i32.const 12))
                    )
                    (i32.const 16)
                )
            )
        )
        (i32.or
            (i32.or
                (i32.shl
                    (call $hex_digit
                        (i32.shr_u (local.get $value) (i32.const 16))
                    )
                    (i32.const 8)
                )
                (call $hex_digit
                    (i32.shr_u (local.get $value) (i32.const 20))
                )
            )
            (i32.or
                (i32.shl
                    (call $hex_digit
                        (i32.shr_u (local.get $value) (i32.const 24))
                    )
                    (i32.const 24)
                )
                (i32.shl
                    (call $hex_digit
                        (i32.shr_u (local.get $value) (i32.const 28))
                    )
                    (i32.const 16)
                )
            )
        )
    )

    ;; To use hex_write_le in another program, copy the function below:
    (;

    ;; hex_write_le: takes a memory pointer + length and an i32 value to be written to memory as a hex string in little-endian order
    ;; result: 0 if successful, 1 if not enough space
    (func $hex_write_le (export "hex_write_le") (param $cio_start i32) (param $cio_len i32) (param $value i32) (result i32)
        (if (result i32)
            (i32.ge_u (local.get $cio_len) (i32.const 8))  ;; memory length must be at least 8 (digits needed for 32-bit hex value)
            (then
                (i32.store
                    (local.get $cio_start)
                    (call $hex_str_le (local.get $value))
                    (local.set $value)  ;; grab second result to use later
                )
                (i32.store
                    offset=4
                    (local.get $cio_start)
                    (local.get $value)
                )
                (i32.const 0)  ;; success
            )
            (else
                (i32.const 1)  ;; error: not enough space
            )
        )
    )

    ;;)

    (data (i32.const 8) "override\n")

    ;; Main function
    (func $main (export "_start")
        (i32.store (i32.const 0) (i32.const 8))
        (i32.store (i32.const 4) (i32.const 9))

        (call $hex_write_le
            (i32.const 8)
            (i32.const 8)
            (i32.const 0xefbeadde)
        )
        drop

        (call $fd_write
            (i32.const 1)  ;; stdout
            (i32.const 0)  ;; iovec array start
            (i32.const 1)  ;; iovec array length
            (i32.const 17) ;; place to store number of bytes written
        )
        drop
    )
)
