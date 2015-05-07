# catatools

Assorted [Cataclysm: Dark Days Ahead](http://en.cataclysmdda.com/) scripts.

## Current stuff

### overmapper.rb

Turn you save's seen data into a *big* image of visited areas.

*Requires*: [Ruby](https://www.ruby-lang.org/en/), [chunky_png](https://rubygems.org/gems/chunky_png)

```bash
$ ./overmapper.rb
Usage:  ./overmapper.rb [option...] save_path name.png
        Version: 0.4

    -h, --help                       Display this message
    -v, --verbose                    Enable debug output
    -x, --mapx MAPX                  Set overmap width (MAPX)
    -y, --mapy MAPY                  Set overmap height (MAPY)
    -l, --level L                    Set map layer (L)
    -s, --scale INT                  Set pixel scale
    -g, --[no-]grid                  Draw grid
    -o, --[no-]origin                Draw origin
```

E.g.

![Penn Yan](http://i.imgur.com/1KTtSeN.png)

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

