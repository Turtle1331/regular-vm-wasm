(module
    ;; Import WASI functions for stdio
    (import "wasi_unstable" "fd_write" (func $fd_write (param i32 i32 i32 i32) (result i32)))
    (import "wasi_unstable" "fd_read" (func $fd_read (param i32 i32 i32 i32) (result i32)))

    (memory 17)  ;; Create 17 pages of memory (2 MiB for program space + 1 page for interpreter data)
    (export "memory" (memory 0))  ;; Export the memory to WASI

    ;; Import hex printing functions
    (import "hex_print" "hex_str_le" (func $hex_str_le (param i32) (result i32 i32)))


    ;; Debug flag
    (global $debug_mode i32 (i32.const 0))


    ;; Global mnemonics for register indices
    ;; Note: registers are on the last page (index 16) and are 32-bit values
    (global $r0  i32 (i32.const 0x10_00_00))
    (global $r1  i32 (i32.const 0x10_00_04))
    (global $r2  i32 (i32.const 0x10_00_08))
    (global $r3  i32 (i32.const 0x10_00_0c))
    (global $r4  i32 (i32.const 0x10_00_10))
    (global $r5  i32 (i32.const 0x10_00_14))
    (global $r6  i32 (i32.const 0x10_00_18))
    (global $r7  i32 (i32.const 0x10_00_1c))
    (global $r8  i32 (i32.const 0x10_00_20))
    (global $r9  i32 (i32.const 0x10_00_24))
    (global $ra  i32 (i32.const 0x10_00_28))
    (global $rb  i32 (i32.const 0x10_00_2c))
    (global $rc  i32 (i32.const 0x10_00_30))
    (global $rd  i32 (i32.const 0x10_00_34))
    (global $re  i32 (i32.const 0x10_00_38))
    (global $rf  i32 (i32.const 0x10_00_3c))
    (global $r10 i32 (i32.const 0x10_00_40))
    (global $r11 i32 (i32.const 0x10_00_44))
    (global $r12 i32 (i32.const 0x10_00_48))
    (global $r13 i32 (i32.const 0x10_00_4c))
    (global $r14 i32 (i32.const 0x10_00_50))
    (global $r15 i32 (i32.const 0x10_00_54))
    (global $r16 i32 (i32.const 0x10_00_58))
    (global $r17 i32 (i32.const 0x10_00_5c))
    (global $r18 i32 (i32.const 0x10_00_60))
    (global $r19 i32 (i32.const 0x10_00_64))
    (global $r1a i32 (i32.const 0x10_00_68))
    (global $r1b i32 (i32.const 0x10_00_6c))
    (global $r1c i32 (i32.const 0x10_00_70))
    (global $r1d i32 (i32.const 0x10_00_74))
    (global $r1e i32 (i32.const 0x10_00_78))
    (global $r1f i32 (i32.const 0x10_00_7c))

    ;; Mnemonics for registers with special names
    (global $pc i32 (i32.const 0x10_00_00))
    (global $at i32 (i32.const 0x10_00_78))
    (global $sp i32 (i32.const 0x10_00_7c))

    ;; Bitmask for program space addresses
    (global $addr_mask i32 (i32.const 0x0f_ff_ff))

    ;; Memory slot for stdout ciovec array (8 slots, 64 bytes)
    (global $stdout_cio_start i32 (i32.const 0x10_00_80))
    (global $stdout_cio_len i32 (i32.const 8))

    ;; Memory slot for printing hex values
    (global $string_hex_start i32 (i32.const 0x10_01_00))
    (global $string_hex_len i32 (i32.const 8))

    ;; Memory slot for number of bytes read/written
    (global $nwritten i32 (i32.const 0x10_01_08))

    ;; Memory slots for static text
    (global $char_newline i32 (i32.const 0x10_01_0c))
    (global $char_space i32 (i32.const 0x10_01_0d))

    (global $text_opcode_start i32 (i32.const 0x10_01_0e))
    (global $text_opcode_len i32 (i32.const 8))
    (global $text_pc_start i32 (i32.const 0x10_01_16))
    (global $text_pc_len i32 (i32.const 4))
    (global $text_ra_start i32 (i32.const 0x10_01_1a))
    (global $text_ra_len i32 (i32.const 4))
    (global $text_rb_start i32 (i32.const 0x10_01_1e))
    (global $text_rb_len i32 (i32.const 4))
    (global $text_rc_start i32 (i32.const 0x10_01_22))
    (global $text_rc_len i32 (i32.const 4))
    (global $text_imm_start i32 (i32.const 0x10_01_26))
    (global $text_imm_len i32 (i32.const 5))
    (global $text_result_start i32 (i32.const 0x10_01_2b))
    (global $text_result_len i32 (i32.const 8))

    ;; Static text
    (data (global.get $char_newline) "\n")
    (data (global.get $char_space) " ")
    (data (global.get $text_opcode_start) "opcode: ")
    (data (global.get $text_pc_start) "pc: ")
    (data (global.get $text_ra_start) "rA: ")
    (data (global.get $text_rb_start) "rB: ")
    (data (global.get $text_rc_start) "rC: ")
    (data (global.get $text_imm_start) "imm: ")
    (data (global.get $text_imm_start) "imm: ")

    ;; Types for if-blocks reading stack values for debugging
    (type $block_debug_pre (func (param $rA i32) (param $rB i32) (param $rC i32) (param $imm i32) (param $pc i32) (param $opcode i32) (result i32 i32 i32 i32 i32 i32)))
    (type $block_debug_post (func (param $rA i32) (param $rB i32) (param $rC i32) (param $imm i32) (param $pc i32) (param $opcode i32) (result i32 i32 i32 i32 i32 i32)))


    ;; Utility functions

    ;; hex_write_le: takes a memory pointer + length and an i32 value to be written to memory as a hex string in little-endian order
    ;; result: 0 if successful, 1 if not enough space
    ;; (copied from hex_print.wat)
    (func $hex_write_le (param $cio_start i32) (param $cio_len i32) (param $value i32) (result i32)
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

    (func $print_to_stdout (param $length i32)
        (drop
            (call $fd_write
                (i32.const 1)                   ;; stdout
                (global.get $stdout_cio_start)  ;; stdio ciovec start
                (i32.rem_u                      ;; stdio ciovec length
                    (local.get $length)
                    (global.get $stdout_cio_len)
                )
                (global.get $nwritten)          ;; slot for number of bytes written
            )
        )
    )

    ;; Print a newline to stdout
    (func $print_newline
        ;; Put newline in stdio ciovec
        (i32.store
            (global.get $stdout_cio_start)
            (global.get $char_newline)
        )
        (i32.store
            offset=4
            (global.get $stdout_cio_start)
            (i32.const 1)
     )

        ;; Print to stdout
        (call $print_to_stdout (i32.const 1))
    )

    (func $print_as_hex (param $value i32)
        (drop
            (call $hex_write_le
                (global.get $string_hex_start)
                (global.get $string_hex_len)
                (local.get $value)
            )
        )

        ;; Put hex slot in first slot of stdio ciovec
        (i32.store
            (global.get $stdout_cio_start)
            (global.get $string_hex_start)
        )
        (i32.store
            offset=4
            (global.get $stdout_cio_start)
            (global.get $string_hex_len)
        )

        ;; Put newline in second slot of stdio ciovec
        (i32.store
            offset=8
            (global.get $stdout_cio_start)
            (global.get $char_newline)
        )
        (i32.store
            offset=12
            (global.get $stdout_cio_start)
            (i32.const 1)
     )

        ;; Print to stdout
        (call $print_to_stdout (i32.const 2))
    )

    ;; Print a variable name (or any text) followed by a hex value to stdout and return the value
    (func $print_var_tee (param $value i32) (param $txt_start i32) (param $txt_len i32) (result i32)
        ;; Convert value to hex
        (drop
            (call $hex_write_le
                (global.get $string_hex_start)
                (global.get $string_hex_len)
                (local.get $value)
            )
        )

        ;; Print variable name
        (i32.store
            (global.get $stdout_cio_start)
            (local.get $txt_start)
        )
        (i32.store
            offset=4
            (global.get $stdout_cio_start)
            (local.get $txt_len)
        )

        ;; Print hex value
        (i32.store
            offset=8
            (global.get $stdout_cio_start)
            (global.get $string_hex_start)
        )
        (i32.store
            offset=12
            (global.get $stdout_cio_start)
            (global.get $string_hex_len)
        )

        ;; Print newline
        (i32.store
            offset=16
            (global.get $stdout_cio_start)
            (global.get $char_newline)
        )
        (i32.store
            offset=20
            (global.get $stdout_cio_start)
            (i32.const 1)
        )

        ;; Print all 3 strings to stdout
        (call $print_to_stdout (i32.const 3))

        ;; Return the value
        (local.get $value)
    )

    ;; Print a variable name (or any text) followed by a hex value to stdout
    (func $print_var (param $value i32) (param $txt_start i32) (param $txt_len i32)
        (drop
            (call $print_var_tee
                (local.get $value)
                (local.get $txt_start)
                (local.get $txt_len)
            )
        )
    )

    ;; Convert an immediate value to a register address
    (func $imm_to_reg (param $imm i32) (result i32)
        (i32.add
            (i32.shl
                (i32.and
                    (local.get $imm)
                    (i32.const 0x1f)  ;; 32 registers total
                )
                (i32.const 2)  ;; Registers take up 32 bits (4 bytes)
            )
            (global.get $r0)  ;; Registers start at r0
        )
    )

    (func $debug_pre (param $rA i32) (param $rB i32) (param $rC i32) (param $imm i32) (param $pc_val i32) (param $opcode i32) (result i32 i32 i32 i32 i32 i32)
        (call $print_var
            (local.get $pc_val)
            (global.get $text_pc_start)
            (global.get $text_pc_len)
        )
        (call $print_var
            (local.get $opcode)
            (global.get $text_opcode_start)
            (global.get $text_opcode_len)
        )
        (call $print_var
            (i32.load (local.get $rA))
            (global.get $text_ra_start)
            (global.get $text_ra_len)
        )
        (call $print_var
            (i32.load (local.get $rB))
            (global.get $text_rb_start)
            (global.get $text_rb_len)
        )
        (call $print_var
            (i32.load (local.get $rC))
            (global.get $text_rc_start)
            (global.get $text_rc_len)
        )
        (call $print_var
            (local.get $imm)
            (global.get $text_imm_start)
            (global.get $text_imm_len)
        )
        (call $print_newline)
        (local.get $rA)
        (local.get $rB)
        (local.get $rC)
        (local.get $imm)
        (local.get $pc_val)
        (local.get $opcode)
    )


    ;; Instructions take up to three parameters and return no output
    (type $reg (func (param $rA i32) (param $rB i32) (param $rC i32) (param $imm i32)))

    ;; Table of instructions
    (table 256 funcref)
    (elem (i32.const 0)
        $reg_nop  ;; 0x00
        $reg_add  ;; 0x01
        $reg_sub  ;; 0x02
        $reg_and  ;; 0x03
        $reg_orr  ;; 0x04
        $reg_xor  ;; 0x05
        $reg_not  ;; 0x06
        $reg_lsh  ;; 0x07
        $reg_ash  ;; 0x08
        $reg_tcu  ;; 0x09
        $reg_tcs  ;; 0x0a
        $reg_set  ;; 0x0b
        $reg_mov  ;; 0x0c
        $reg_ldw  ;; 0x0d
        $reg_stw  ;; 0x0e
        $reg_ldb  ;; 0x0f
        $reg_stb  ;; 0x10
    )
    (elem (i32.const 0xff)
        $reg_hlt  ;; 0xff
    )

    ;; Instruction implementations
    (func $reg_nop (param $rA i32) (param $rB i32) (param $rC i32) (param $imm i32)
        nop
    )

    (func $reg_add (param $rA i32) (param $rB i32) (param $rC i32) (param $imm i32)
        (i32.store
            (local.get $rA)
            (i32.add
                (i32.load (local.get $rB))
                (i32.load (local.get $rC))
            )
        )
    )

    (func $reg_sub (param $rA i32) (param $rB i32) (param $rC i32) (param $imm i32)
        (i32.store
            (local.get $rA)
            (i32.sub
                (i32.load (local.get $rB))
                (i32.load (local.get $rC))
            )
        )
    )

    (func $reg_and (param $rA i32) (param $rB i32) (param $rC i32) (param $imm i32)
        (i32.store
            (local.get $rA)
            (i32.and
                (i32.load (local.get $rB))
                (i32.load (local.get $rC))
            )
        )
    )

    (func $reg_orr (param $rA i32) (param $rB i32) (param $rC i32) (param $imm i32)
        (i32.store
            (local.get $rA)
            (i32.or
                (i32.load (local.get $rB))
                (i32.load (local.get $rC))
            )
        )
    )

    (func $reg_xor (param $rA i32) (param $rB i32) (param $rC i32) (param $imm i32)
        (i32.store
            (local.get $rA)
            (i32.xor
                (i32.load (local.get $rB))
                (i32.load (local.get $rC))
            )
        )
    )

    (func $reg_not (param $rA i32) (param $rB i32) (param i32) (param $imm i32)
        (i32.store
            (local.get $rA)
            (i32.xor
                (i32.load (local.get $rB))
                (i32.const 0xffffffff)
            )
        )
    )

    (func $reg_lsh (param $rA i32) (param $rB i32) (param $rC i32) (param $imm i32)
        (i32.store
            (local.get $rA)
            (if (result i32) (i32.ge_s (local.get $rC) (i32.const 0))
                (then
                    (i32.shl
                        (i32.load (local.get $rB))
                        (i32.load (local.get $rC))
                    )
                ) (else
                    (i32.shr_u
                        (i32.load (local.get $rB))
                        (i32.load (local.get $rC))
                    )
                )
            )
        )
    )

    (func $reg_ash (param $rA i32) (param $rB i32) (param $rC i32) (param $imm i32)
        (i32.store
            (local.get $rA)
            (if (result i32) (i32.ge_s (local.get $rC) (i32.const 0))
                (then
                    (i32.shl
                        (i32.load (local.get $rB))
                        (i32.load (local.get $rC))
                    )
                ) (else
                    (i32.shr_s
                        (i32.load (local.get $rB))
                        (i32.load (local.get $rC))
                    )
                )
            )
        )
    )

    (func $reg_tcu (param $rA i32) (param $rB i32) (param $rC i32) (param $imm i32)
        (i32.store
            (local.get $rA)
            (i32.sub
                (i32.gt_u
                    (local.get $rB)
                    (local.get $rC)
                )
                (i32.lt_u
                    (local.get $rB)
                    (local.get $rC)
                )
            )
        )
    )

    (func $reg_tcs (param $rA i32) (param $rB i32) (param $rC i32) (param $imm i32) (local $rB_val i32) (local $rC_val i32)
        (i32.store
            (local.get $rA)
            (i32.sub
                (i32.gt_s
                    (i32.load (local.get $rB))
                    (i32.load (local.get $rC))
                )
                (i32.lt_s
                    (i32.load (local.get $rB))
                    (i32.load (local.get $rC))
                )
            )
        )
    )

    (func $reg_set (param $rA i32) (param i32) (param i32) (param $imm i32)
        (i32.store
            (local.get $rA)
            (local.get $imm)
        )
    )

    (func $reg_mov (param $rA i32) (param $rB i32) (param i32) (param $imm i32)
        (i32.store
            (local.get $rA)
            (i32.load (local.get $rB))
        )
    )

    (func $reg_ldw (param $rA i32) (param $rB i32) (param i32) (param $imm i32)
        (i32.store
            (local.get $rA)
            (i32.load
                (i32.and
                    (i32.load (local.get $rB))
                    (global.get $addr_mask)
                )
            )
        )
    )

    (func $reg_stw (param $rA i32) (param $rB i32) (param i32) (param $imm i32)
        (i32.store
            (i32.and
                (i32.load (local.get $rA))
                (global.get $addr_mask)
            )
            (i32.load (local.get $rB))
        )
    )

    (func $reg_ldb (param $rA i32) (param $rB i32) (param i32) (param $imm i32)
        (i32.store8
            (local.get $rA)
            (i32.load8_u
                (i32.and
                    (i32.load (local.get $rB))
                    (global.get $addr_mask)
                )
            )
        )
    )

    (func $reg_stb (param $rA i32) (param $rB i32) (param i32) (param $imm i32)
        (i32.store8
            (i32.and
                (i32.load (local.get $rA))
                (global.get $addr_mask)
            )
            (i32.load (local.get $rB))
        )
    )

    (func $reg_hlt (param $rA i32) (param $rB i32) (param i32) (param $imm i32)
        ;; halt is handled by the execution loop
        (call $print_as_hex (i32.load (local.get $rA)))
    )


    ;; Main function
    (func $main (export "_start") (local $pc_val i32) (local $opcode i32)
        (block $exit
            (block $trap
                (loop $loop
                    ;; Fetch program counter
                    (local.set $pc_val
                        (i32.and
                            (i32.load (global.get $pc))
                            (global.get $addr_mask)
                        )
                    )

                    ;; Fetch and decode instruction
                    (local.set $opcode
                        (i32.load8_u (local.get $pc_val))
                    )
                    ;; rA
                    (call $imm_to_reg
                        (i32.load8_u
                            offset=1
                            (local.get $pc_val)
                        )
                    )
                    ;; rB
                    (call $imm_to_reg
                        (i32.load8_u
                            offset=2
                            (local.get $pc_val)
                        )
                    )
                    ;; rC
                    (call $imm_to_reg
                        (i32.load8_u
                            offset=3
                            (local.get $pc_val)
                        )
                    )
                    ;; imm
                    (i32.load16_s
                        offset=2
                        (local.get $pc_val)
                    )

                    ;; Increment pc
                    (i32.store
                        (global.get $pc)
                        (i32.and
                            (i32.add (local.get $pc_val) (i32.const 4))
                            (global.get $addr_mask)
                        )
                    )

                    ;; Debug printing before instruction
                    (local.get $pc_val)
                    (local.get $opcode)
                    (if (type $block_debug_pre)
                        (global.get $debug_mode)
                        (then
                            (call $debug_pre)
                        )
                    )
                    drop
                    drop

                    ;; Execute instruction
                    (call_indirect
                        (type $reg)
                        (local.get $opcode)
                    )

                    ;; Check for halt instruction
                    (br_if $exit
                        (i32.eq
                            (local.get $opcode)
                            (i32.const 0xff)
                        )
                    )

                    ;; Repeat
                    ;; Note: br cleans up the stack automatically, so br_if is needed to validate the stack size
                    (br_if $loop (i32.const 1))
                )
            )
            ;; Trap (aka fatal error) handler
        )
    )


    ;; Test function for debugging an instruction
    ;; Call with $ wasmtime interpreter.wat --invoke test
    (func $test (export "test") (result i32)
        ;; Initialize r1 through r3
        (i32.store (global.get $r1) (i32.const 2))  ;; r1 = 2
        (i32.store (global.get $r2) (i32.const 2))  ;; r2 = 2
        (i32.store (global.get $r3) (i32.const 5))  ;; r3 = 5

        ;; Call $reg_add to perform:
        ;; add r3, r1, r2
        (call $imm_to_reg (i32.const 3))  ;; rA
        (call $imm_to_reg (i32.const 1))  ;; rB
        (call $imm_to_reg (i32.const 2))  ;; rC
        (i32.const -42)     ;; imm
        (call_indirect
            (type $reg)
            (i32.const 0x01)  ;; add
        )

        ;; Read the value in r3
        (i32.load (global.get $r3))
        ;; It should be 2 + 2 = 4
        ;; If it is 5, then $reg_add does not work
    )

    ;; fibonacci.hex
    ;;(;
    (data (i32.const 0x00_00_00)
        "\0b\01\16\00"
        "\0b\1f\08\01"
        "\0b\03\cc\00"
        "\01\00\00\03"
        "\0b\05\01\00"
        "\0b\06\04\00"
        "\01\1f\1f\06"
        "\0d\04\1f\00"
        "\02\1f\1f\06"
        "\0a\07\04\05"
        "\01\07\07\05"
        "\07\07\07\06"
        "\01\00\00\07"
        "\0d\03\1f\00"
        "\0b\04\00\00"
        "\0e\1f\04\00"
        "\0c\00\03\00"
        "\0d\03\1f\00"
        "\0e\1f\05\00"
        "\0c\00\03\00"
        "\00\00\00\00"
        "\02\04\04\05"
        "\02\05\04\05"
        "\01\1f\1f\06"
        "\0e\1f\05\00"
        "\0b\05\1c\00"
        "\01\05\05\00"
        "\01\1f\1f\06"
        "\0e\1f\05\00"
        "\01\1f\1f\06"
        "\0e\1f\04\00"
        "\02\1f\1f\06"
        "\0b\04\88\ff"
        "\01\00\00\04"
        "\0d\04\1f\00"
        "\02\1f\1f\06"
        "\0d\05\1f\00"
        "\0e\1f\04\00"
        "\0b\04\1c\00"
        "\01\04\04\00"
        "\01\1f\1f\06"
        "\0e\1f\04\00"
        "\01\1f\1f\06"
        "\0e\1f\05\00"
        "\02\1f\1f\06"
        "\0b\04\54\ff"
        "\01\00\00\04"
        "\0d\04\1f\00"
        "\02\1f\1f\06"
        "\0d\05\1f\00"
        "\01\04\04\05"
        "\02\1f\1f\06"
        "\0d\03\1f\00"
        "\0e\1f\04\00"
        "\0c\00\03\00"
        "\0b\02\04\00"
        "\0b\03\18\00"
        "\01\03\03\00"
        "\0e\1f\03\00"
        "\01\1f\1f\02"
        "\0e\1f\01\00"
        "\02\1f\1f\02"
        "\0b\03\10\ff"
        "\01\00\00\03"
        "\0d\02\1f\00"
        "\ff\02\00\00"
    )
    ;;)
)
