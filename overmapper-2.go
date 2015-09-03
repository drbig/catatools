// See LICENSE.txt for licensing information.

package main

import (
	"bytes"
	"encoding/gob"
	"encoding/json"
	"flag"
	"fmt"
	"os"
	"path/filepath"
	"strconv"
	"strings"
)

// Terrain holds possible symbols (for different orientations) and color name
// string for an overmap terrain entity.
type Terrain struct {
	Symbols []string
	Color   string
}

var (
	flagVerbose bool // be verbose
	flagPlain   bool // convert to plain-text
	flagWidth   int  // overmap width
	flagHeight  int  // overmap height
	flagLayer   int  // overmap layer

	termap = make(map[string]Terrain, 1024) // global overmap terrain map
	lines  = map[int32]string{              // mappings for line glyphs
		4194424: "\u2502",
		4194417: "\u2500",
		4194413: "\u2514",
		4194412: "\u250C",
		4194411: "\u2510",
		4194410: "\u2518",
		4194420: "\u251C",
		4194422: "\u2534",
		4194421: "\u2524",
		4194423: "\u252C",
		4194414: "\u253C",
	}
	roads = map[string]string{ // mappings for road glyphs
		"north": "│",
		"south": "│",
		"west":  "─",
		"east":  "─",
		"nesw":  "┼",
		"esw":   "┬",
		"nsw":   "┤",
		"new":   "┴",
		"nes":   "├",
		"ns":    "│",
		"ew":    "─",
		"wn":    "┘",
		"ne":    "└",
		"sw":    "┐",
		"es":    "┌",
	}
	dirs      = []string{"north", "east", "south", "west", "ns", "ew", "sn", "we"} // possible orientation etc. strings
	htmlStart = `<html><head><style>
body { background: black; color: #aaaaaa; }
.cl_white { color: #ffffff; }
.cl_blue { color: #0000ff; }
.cl_red { color: #ff0000; }
.cl_brown { color: #a52a2a; }
.cl_green { color: #008000; }
.cl_cyan { color: #00ffff; }
.cl_dark_gray { color: #a9a9a9; }
.cl_magenta { color: #ff00ff; }
.cl_yellow { color: #ffff00; }
.cl_light_blue { color: #add8e6; }
.cl_light_green { color: #90ee90; }
.cl_light_red { color: #ff5555; }
.cl_i_ltred { color: black; background: #ff5555; }
.cl_light_gray { color: #d3d3d3; }
.cl_i_ltgray { color: black; background: #d3d3d3; }
.cl_light_cyan { color: #e0ffff; }
.cl_ltgray_yellow { color: #d3d3d3; background: #ffff00; }
.cl_pink { color: #ffc0cb; }
.cl_yellow_magenta { color: #ffff00; background: #ff00ff; }
.cl_white_magenta { color: #ffffff; background: #ff00ff; }
.cl_i_magenta { color: black; background: #ff00ff; }
.cl_pink_magenta { color: #ffc0cb; background: #ff00ff;  }
.cl_i_green { color: black; background: #008000; }
.cl_i_brown { color: black; background: #a52a2a; }
.cl_h_yellow { color: #ffff00; background: #0000ff; }
.cl_h_dkgray { color: #a9a9a9; background: #0000ff; }
.cl_i_ltblue { color: black; background: #add8e6; }
.cl_i_blue { color: black; background: #0000ff; }
.cl_i_red { color: black; background: #ff0000; }
.cl_ltgreen_yellow { color: #d3d3d3; background: #ffff00; }
.cl_white_white { background: white; }
.cl_i_ltcyan { color: black; background: #e0ffff; }
.cl_yellow_cyan { color: #ffff00; background: #00ffff; }
</style><meta content='text/html; charset=utf-8' http-equiv='Content-Type' />
</head><body><pre>`
	htmlEnd = `</pre></body></html>`
)

func init() {
	flag.Usage = func() {
		fmt.Fprintf(os.Stderr, "Usage: %s [options...] <command> <path>\n", os.Args[0])
		fmt.Fprintf(os.Stderr, "\n	Options:\n\n")
		flag.PrintDefaults()
		fmt.Fprintln(os.Stderr, `
	Commands:

	prepare /path/to/cdda

	Convert C:DDA overmap terrain data to internal format.
	File 'terrain.dat' will be created in current directory.
	NOTE: You need to have the above file for convert to work.
	      You should also re-run it periodically to update the data
	      (e.g. if you see missing tile messages when converting).

	convert /path/to/save > /path/to/output.file

	This will try to convert your save data to HTML by default.
	It will output to stdout so you most likely want to redirect it
	to a file ("> test.html"). You can change the format using the "-p"
	option (for plain text).`)
		os.Exit(1)
	}
	flag.BoolVar(&flagVerbose, "v", false, "be verbose")
	flag.BoolVar(&flagPlain, "p", false, "convert to plain-text")
	flag.IntVar(&flagWidth, "ow", 180, "overmap width")
	flag.IntVar(&flagHeight, "oh", 180, "overmap height")
	flag.IntVar(&flagLayer, "ol", 10, "overmap layer")
}

func main() {
	flag.Parse()
	if flag.NArg() != 2 {
		flag.Usage()
	}
	switch flag.Arg(0) {
	case "prepare":
		runPrepare(flag.Arg(1))
		if flagVerbose {
			fmt.Fprintf(os.Stderr, "Parsed %d terrain items\n", len(termap))
		}
		saveTermap()
	case "convert":
		loadTermap()
		runConvert(flag.Arg(1))
	default:
		flag.Usage()
	}
}

// die prints the error to stderr end exits.
func die(err error) {
	fmt.Fprintln(os.Stderr, "FATAL: ", err)
	os.Exit(2)
}

// warn prints a warning to stderr.
func warn(str string, args ...interface{}) {
	fmt.Fprintf(os.Stderr, "WARN: "+str, args...)
}

// oMapElem holds overmap data from a save.
type oMapElem struct {
	ID  string
	Len int
}

// Custom unmarshaling due to the structure of the overmap data in a save.
func (e *oMapElem) UnmarshalJSON(b []byte) (err error) {
	var id string
	var length int
	tgt := []interface{}{&id, &length}
	if err := json.Unmarshal(b, &tgt); err != nil {
		return err
	}
	e.ID = id
	e.Len = length
	return
}

// getLayer returns a parsed overmap layer or dies trying.
func getLayer(which int, path string) (layer []oMapElem, err error) {
	which++ // as we start from 1 due to silly delimiter counting later on
	file, err := os.Open(path)
	if err != nil {
		return
	}
	defer file.Close()
	if _, err = file.Seek(12, os.SEEK_CUR); err != nil {
		return
	}
	dec := json.NewDecoder(file)
	current := 0
	level := 0
	for {
		t, err := dec.Token()
		if err != nil {
			die(err)
		}
		d, ok := t.(json.Delim)
		if !ok {
			continue
		}
		if d == '[' {
			level++
		} else if d == ']' {
			level--
		}
		if level == 1 {
			current++
		}
		if current == which {
			break
		}
	}
	err = dec.Decode(&layer)
	return
}

// runConvert is the main entry point for conversion.
// It will die on fatal errors.
func runConvert(root string) {
	maps, width, err := getMaps(root)
	if err != nil {
		die(err)
	}
	rowLineBufs := make([][]bytes.Buffer, width)
	for x := 0; x < width; x++ {
		rowLineBufs[x] = make([]bytes.Buffer, flagHeight)
	}
	if !flagPlain {
		fmt.Println(htmlStart)
	}
	for _, row := range maps {
		for x, mapPath := range row {
			if mapPath == "" {
				for line := 0; line < flagHeight; line++ {
					for i := 0; i < flagWidth; i++ {
						rowLineBufs[x][line].Write([]byte(" "))
					}
				}
				continue
			}
			data, err := getLayer(flagLayer, mapPath)
			if err != nil {
				die(err)
			}
			line := 0
			pos := 0
			for _, e := range data {
				color, symbol := getTer(e.ID)
				if !flagPlain {
					if symbol == "<" {
						symbol = "&#x3c;"
					} else if symbol == ">" {
						symbol = "&#x3e;"
					}
				}
				for e.Len > 0 {
					lineLeft := flagWidth - pos
					var howMany int
					if lineLeft < e.Len {
						howMany = lineLeft
					} else {
						howMany = e.Len
					}
					if color != "" && !flagPlain {
						rowLineBufs[x][line].WriteString("<span class=\"cl_")
						rowLineBufs[x][line].WriteString(color)
						rowLineBufs[x][line].WriteString("\">")
					}
					for c := 0; c < howMany; c++ {
						rowLineBufs[x][line].WriteString(symbol)
					}
					if color != "" && !flagPlain {
						rowLineBufs[x][line].WriteString("</span>")
					}
					pos += howMany
					e.Len -= howMany
					if pos == flagWidth {
						pos = 0
						line++
					}
				}
			}
		}
		for line := 0; line < flagHeight; line++ {
			for _, bufs := range rowLineBufs {
				bufs[line].WriteTo(os.Stdout)
				bufs[line].Reset()
			}
			fmt.Printf("\n")
		}
	}
	if !flagPlain {
		fmt.Println(htmlEnd)
	}
}

// getTer tries to retrieve color and symbol strings for a given overmap
// terrain id. It handles rotations, lines and roads (as special cases).
func getTer(id string) (color, symbol string) {
	tile, ok := termap[id]
	if ok {
		return tile.Color, tile.Symbols[0]
	}
	splitAt := strings.LastIndex(id, "_")
	if splitAt < 1 {
		warn("Couldn't split id: %s\n", id)
		return "", "?"
	}
	suffix := id[splitAt+1:]
	nid := id[0:splitAt]
	if nid == "road" {
		symbol, ok = roads[suffix]
		if !ok {
			warn("No road suffix for %s (%s)\n", suffix, id)
			return "", "?"
		}
		return
	}
	tile, ok = termap[nid]
	if !ok {
		warn("Tile not found %s (%s %s)\n", nid, id, suffix)
		return "", "?"
	}
	dir := 0
	for i, d := range dirs {
		if d == suffix {
			dir = i
			break
		}
	}
	dir = dir % 4
	if dir < len(tile.Symbols) {
		symbol = tile.Symbols[dir]
	} else {
		symbol = tile.Symbols[0]
	}
	color = tile.Color
	return
}

// getMaps looks over a save directory and composes an array of arrays
// of maps for processing. The returned array has dimensions of the extent
// of the overmaps saved, with empty overmaps being empty strings.
// It also returns the width in overmaps as it's needed to allocate output
// buffers later.
func getMaps(root string) (maps [][]string, width int, err error) {
	type coord struct {
		x, y int
	}
	var min_x, max_x int
	var min_y, max_y int
	seen := make(map[coord]string)
	err = filepath.Walk(root,
		func(path string, info os.FileInfo, ierr error) (oerr error) {
			if ierr != nil {
				return ierr
			}
			if info.IsDir() {
				return nil
			}
			fname := filepath.Base(path)
			if ok, _ := filepath.Match("o.*", fname); !ok {
				return nil
			}
			if flagVerbose {
				fmt.Fprintf(os.Stderr, "File: %s\n", path)
			}
			parts := strings.Split(fname, ".")
			if len(parts) != 3 {
				warn("Malformed file match: %s\n", fname)
				return nil
			}
			x, oerr := strconv.Atoi(parts[1])
			if oerr != nil {
				return
			}
			y, oerr := strconv.Atoi(parts[2])
			if oerr != nil {
				return
			}
			seen[coord{x, y}] = path
			if x < min_x {
				min_x = x
			}
			if x > max_x {
				max_x = x
			}
			if y < min_y {
				min_y = y
			}
			if y > max_y {
				max_y = y
			}
			return nil
		})
	width = -min_x + 1 + max_x
	height := -min_y + 1 + max_y
	if flagVerbose {
		fmt.Fprintf(os.Stderr, "Maps range from %dx%d to %dx%d for an area of %dx%d\n",
			min_x, min_y, max_x, max_y, width, height)
	}
	maps = make([][]string, height)
	for y := 0; y < height; y++ {
		maps[y] = make([]string, width)
		for x := 0; x < width; x++ {
			rx := min_x + x
			ry := min_y + y
			if path, ok := seen[coord{rx, ry}]; ok {
				maps[y][x] = path
			}
		}
	}
	return
}

// runPrepare is the main entry point for data preprocessing.
// It will die on fatal errors.
// The idea here is that we walk all the possible JSONs paths and try to
// extract anything that looks like a valid overmap terrain entity.
// We can then gob-encode what we found and have it ready to use for
// all future converts.
func runPrepare(root string) {
	err := processTerrainData(filepath.Join(root, "data", "json",
		"overmap_terrain.json"))
	if err != nil {
		die(err)
	}
	err = filepath.Walk(filepath.Join(root, "data", "json", "mapgen"), walkForMapgen)
	if err != nil {
		die(err)
	}
	err = filepath.Walk(filepath.Join(root, "data", "mods"), walkForMods)
	if err != nil {
		die(err)
	}
}

// walkForMapgen walks recursively looking for JSON files and tries to extract
// overmap terrain entities form them.
func walkForMapgen(path string, info os.FileInfo, ierr error) (oerr error) {
	if ierr != nil {
		return ierr
	}
	if info.IsDir() {
		return nil
	}
	if filepath.Ext(path) != ".json" {
		return nil
	}
	return processTerrainData(path)
}

// walkForMods walks recursively looking for JSON files and tries to extract
// overmap terrain entities form them.
func walkForMods(path string, info os.FileInfo, ierr error) (oerr error) {
	if ierr != nil {
		return ierr
	}
	if info.IsDir() {
		return nil
	}
	if filepath.Base(path) != "overmap_terrain.json" {
		return nil
	}
	return processTerrainData(path)
}

// processTerrainData tries to extract all overmap entities form a given
// JSON file.
func processTerrainData(path string) (err error) {
	type oter struct {
		ID    string      `json:"id"`
		Color string      `json:"color"`
		Syms  interface{} `json:"sym"`
	}
	if flagVerbose {
		fmt.Fprintf(os.Stderr, "File: %s\n", path)
	}
	file, err := os.Open(path)
	if err != nil {
		return
	}
	defer file.Close()
	dec := json.NewDecoder(file)
	_, err = dec.Token() // Skip over '['
	if err != nil {
		return
	}
	var rawTer oter
	for dec.More() {
		err = dec.Decode(&rawTer)
		if err != nil {
			warn("Bad item format: %s\n", err)
			continue
		}
		if rawTer.Syms == nil {
			continue
		}
		if _, ok := termap[rawTer.ID]; ok {
			warn("Terrain %v already defined\n", rawTer.ID)
		}
		var syms []string
		switch tsym := rawTer.Syms.(type) {
		case float64:
			syms = make([]string, 1)
			syms[0] = parseSym(int32(tsym))
		case []interface{}:
			syms = make([]string, len(tsym))
			for i, ttsym := range tsym {
				// below will blow up with appropriate message on wrong type
				syms[i] = parseSym(int32(ttsym.(float64)))
			}
		default:
			warn("Unkown sym type: %v\n", tsym)
			continue
		}
		ter := Terrain{syms, rawTer.Color}
		termap[rawTer.ID] = ter
		if flagVerbose {
			fmt.Fprintf(os.Stderr, "Parsed terrain: %v = %v\n", rawTer.ID, ter)
		}
	}
	return
}

// parseSym tries to parse a symbol (integer) into a string.
func parseSym(raw int32) string {
	if raw <= 255 {
		return string(raw)
	}
	if str, ok := lines[raw]; ok {
		return str
	}
	warn("No LINE found for: %v\n", raw)
	return "?"
}

// saveTermap saves the global terrain data or dies.
func saveTermap() {
	file, err := os.Create("terrain.dat")
	if err != nil {
		die(err)
	}
	defer file.Close()
	enc := gob.NewEncoder(file)
	if err = enc.Encode(termap); err != nil {
		die(err)
	}
	if flagVerbose {
		fmt.Fprintf(os.Stderr, "Saved terrain map to terrain.dat\n")
	}
}

// loadTermap loads the global terrain data or dies.
func loadTermap() {
	file, err := os.Open("terrain.dat")
	if err != nil {
		die(err)
	}
	defer file.Close()
	dec := gob.NewDecoder(file)
	if err = dec.Decode(&termap); err != nil {
		die(err)
	}
	if flagVerbose {
		fmt.Fprintf(os.Stderr, "Loaded terrain map (%d items)\n", len(termap))
	}
}
