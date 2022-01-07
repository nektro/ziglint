# ziglint
![loc](https://sloc.xyz/github/nektro/ziglint)
[![license](https://img.shields.io/github/license/nektro/ziglint.svg)](https://github.com/nektro/ziglint/blob/master/LICENSE)

A linting suite for Zig.

## Usage
```
$ ./ziglint
```

This will search the current directory for `.zig` files and lint them against the various tests in the suite. See the [bad/](./bad/) folder for examples of the caught lints.

## Installation
This requires having [Zig](https://ziglang.org) and [Zigmod](https://github.com/nektro/zigmod) installed.

- https://ziglang.org/download/
- https://github.com/nektro/zigmod/releases

```sh
$ zigmod aq install 1/nektro/ziglint
```

# Available Rules
- `dupe_import`: warn against duplicate `@import` calls with the same value
- `todo`: list all `// TODO` comments

Want to propose more? Open an issue here on Github.

## License
MIT
