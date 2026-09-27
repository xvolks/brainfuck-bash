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

## Tests

`./run-tests.sh` runs every program of `samples/` and compares the output byte for byte:

```bash
./run-tests.sh              # all tests
./run-tests.sh hello        # only tests whose name contains "hello"
VERBOSE=1 ./run-tests.sh    # full output on failure
```

| sample | what it checks | expected output |
| --- | --- | --- |
| `hello` | canonical Hello World, nested loops | `Hello World!` |
| `hello_world_full` | one multiply loop per letter | `Hello World!` |
| `counter` | increment loop | `123456789` |
| `countdown` | decrement loop, two cells | `987654321` |
| `abc` | short programs, 3 cells | `abc` |
| `multi_cell` | one cell pair per character | `multi` |
| `garbage` | non-command characters are ignored | `d` |
| `line` | several cells, no trailing newline | two `\n` |
| `wrap_around` | cell underflow wraps to 255 | `#` |
| `empty` | empty program | nothing |
| `test` | print a string | JIPPS/YSVPH0 |

## Requirements

- Bash version 5 or higher (the script checks and exits with an error on older versions)

## Internals

The interpreter:

1. **Parses** Brainfuck source into an operations array with format `op;operand`
2. **Handles loops** using stack/jump arrays for backpatching `[`/`]` targets
3. **Executes** operations on a 1024-cell memory tape with a head pointer
4. Supports: `inc`/`dec` (increment/decrement), `left`/`right` (move tape), `jz`/`jnz` (jump if zero/non-zero), `out` (output byte), `in` (input byte)
