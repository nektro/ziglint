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

## Built With
- Zig master `0.11.0`
- [Zigmod](https://github.com/nektro/zigmod) package manager
- See [`zig.mod`](./zig.mod)

# Available Rules
- `dupe_import`: warn against duplicate `@import` calls with the same value
- `todo`: list all `// TODO` comments
- `file_as_struct`: checks for file name capitalization in the presence of top level fields
- `unused_decl`: checks for unused container level `const`/`var`s

Want to propose more? Open an issue here on Github.

## Using in Github Actions
```yml
jobs:
  lint:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v2

      - name: Setup Zig
        uses: goto-bus-stop/setup-zig@v1
        with:
          version: "0.11.0"

      - uses: nektro/actions-setup-zigmod@v1
      - run: zigmod aq install 1/nektro/ziglint
      - run: ~/.zigmod/bin/ziglint -skip todo
```

## License
MIT
