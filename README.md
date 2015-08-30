# catatools

Assorted [Cataclysm: Dark Days Ahead](http://en.cataclysmdda.com/) scripts.

## Current stuff

### overmapper.rb

Turn your save's seen data into a *big* image of visited areas.

*Requires*: [Ruby](https://www.ruby-lang.org/en/), [chunky_png](https://rubygems.org/gems/chunky_png)

```bash
$ ./overmapper.rb
Usage:  ./overmapper.rb [option...] save_path name.png
        Version: 0.7

    -h, --help                       Display this message
    -v, --verbose                    Enable debug output
    -x, --mapx MAPX                  Set overmap width (MAPX)
    -y, --mapy MAPY                  Set overmap height (MAPY)
    -l, --level L                    Set map layer (L)
    -s, --scale INT                  Set pixel scale
    -g, --[no-]grid                  Draw grid
    -o, --[no-]origin                Draw origin
    -n, --[no-]notes                 Draw notes
```

E.g.

![Penn Yan](http://i.imgur.com/1KTtSeN.png)

### overmapper-2.rb / overmapper-2.go

Turn your save's overmaps data into *humongus* map view text/HTML files.
Works only with saves since JSON overmap saving [became a thing](https://github.com/CleverRaven/Cataclysm-DDA/pull/12790).

Ruby version *requires*: [Ruby](https://www.ruby-lang.org/en/), [oj](https://rubygems.org/gems/chunky_pn://rubygems.org/gems/oj)

Go version *requires*: [Go](https://golang.org/dl/)

```bash
$ ./overmapper-2.rb
Usage:
      ./overmapper-2.rb preprocess /path/to/cdda_dir

      Convert CDDA overmap terrain data for later use.
      File 'terrain.dat' will be created in current directory.
      NOTE: You need to have that file for convert to work.

      ./overmapper-2.rb convert [format] /path/to/save_dir

      format: html, txt. default: html

      This will try to convert overmap data to given format.
      It will output to stdout so you better redirect it to a file.
```

E.g.

![Debug 0.C](http://i.imgur.com/vGaJWnG.png)

(at 25% zoom; HTML file for 3x4 overmaps world weights at ~ 5 MB)

## Contributing

Follow the usual GitHub workflow:

 1. Fork the repository
 2. Make a new branch for your changes
 3. Work (and remember to commit with decent messages)
 4. Check if tests pass, maybe add your own cases
 5. Push your feature branch to your origin
 6. Make a Pull Request on GitHub

## Licensing

Standard two-clause BSD license, see LICENSE.txt for details.

Copyright (c) 2015 Piotr S. Staszewski

