# iotest

Minimal CLI tool to verify program output using a simple input/output test file.

## Example Usage

`myscript.iotest`:

```iotest
input1
---
output1
===
input2
---
output2
```

Run tests:

```sh
iotest myscript.iotest ./myscript.sh
```

Each of the two tests is run against `./myscript.sh`, passing the input to
stdin and asserting that stdout matches the expected output.

## File Format

* Each test case consists of **input** and **expected output**.

* Separate **input** and **output** with `---`.

* Separate **multiple tests** with `===`.
