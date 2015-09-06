# catatools

Assorted [Cataclysm: Dark Days Ahead](http://en.cataclysmdda.com/) scripts.

## Current stuff

Note on Go binaries: distributed outside the repo, checksums here for some notion "authenticity" (check the Rakefile).

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

Go version *requires*: [Go](https://golang.org/dl/). The Go version is the one that will be maintained. It also already has additional feature: it extracts overmap terrain entities from mods data.

Ruby version *requires*: [Ruby](https://www.ruby-lang.org/en/), [oj](https://rubygems.org/gems/chunky_pn://rubygems.org/gems/oj)

```bash
Usage: ./overmapper-2 [options...] <command> <path>

        Options:

  -a    print coordinate axes
  -oh int
        overmap height (default 180)
  -ol int
        overmap layer (default 10)
  -ow int
        overmap width (default 180)
  -p    convert to plain-text
  -v    be verbose

        Commands:

        prepare /path/to/cdda

        Convert C:DDA overmap terrain data to internal format.
        File 'terrain.dat' will be created in current directory.
        NOTE: You need to have the above file for convert to work.
              You should also re-run it periodically to update the data
              (e.g. if you see missing tile messages when converting).

        convert /path/to/save > /path/to/output.file

        This will try to convert your save data to HTML by default.
        It will output to stdout so you most likely want to redirect iy
        to a file ("> test.html"). You can change the format using the "-p"
        option (for plain text).
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

