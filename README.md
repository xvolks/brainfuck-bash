# bf - Brainfuck Interpreter in Bash

A full Brainfuck interpreter written in Bash (tested on bash 5+). Parses and executes Brainfuck source code.

## Features

- Supports all standard Brainfuck commands: `>` `<` `+` `-` `.` `,` `[` `]`
- 1024-byte memory tape (cells initialized to 0)
- Loop handling (`[`/`]` with zero/non-zero jump logic)
- Debug mode via `DEBUG` environment variable
- Reads Brainfuck source from a file argument

## Usage

```bash
./bf <filename.bf>
```

Or pass multiple files as arguments.

## Debug Mode

Set `DEBUG=1` to see tracing output during execution:

```bash
DEBUG=1 ./bf hello.bf
```

## Example

```bf
+++++++++[>++++++++>++++++++>+++++>+++<<<<-]>++.>+.+++++++..+++.>++.<<+++++++++++++++.>.+++.------.--------.>+.>
```

Run:

```bash
./bf /path/to/script.bf
```

## Requirements

- Bash version 5 or higher (the script checks and exits with an error on older versions)

## Internals

The interpreter:

1. **Parses** Brainfuck source into an operations array with format `op;operand`
2. **Handles loops** using stack/jump arrays for backpatching `[`/`]` targets
3. **Executes** operations on a 1024-cell memory tape with a head pointer
4. Supports: `inc`/`dec` (increment/decrement), `left`/`right` (move tape), `jz`/`jnz` (jump if zero/non-zero), `out` (output byte), `in` (input byte)