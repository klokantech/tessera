# tileserver-mapnik

Mapnik-based tile server generating raster tiles from tilelive-js sources (MapBox Studio project + custom vector tiles for example).
It supports also static maps API.

## How to use

### Docker

The easiest way to run tileserver-mapnik is using the precompiled docker container (https://hub.docker.com/r/klokantech/tileserver-mapnik/).

Detailed instructions how to use the tileserver-mapnik with docker: http://osm2vectortiles.org/docs/serve-raster-tiles-docker/

### Without docker

Follow the commands in `Dockerfile` to install the necessary packages, download common fonts and prepare the environment.

Usage: `node bin/tessera.js [options]`

Options:
 - `-c CONFIG` - Configuration file
 - `-p PORT` - HTTP port [8080]
 - `-C SIZE` - Cache size in MB [10]
 - `-S SIZE` - Source cache size (in # of sources)  [10]

#### Example configuration file

```javascript
{
  "/style1": {
    "source": "tmstyle://./style1.tm2"
  },
  "/style2": {
    "source": "tmstyle:///home/user/style2.tm2"
  },
  "/vector": {
    "source": "mbtiles:///home/user/data.mbtiles"
  }
}
```

**Note**: For tm2 styles, you need to make sure the content of style's `project.yml` (its `source` property) points to a valid mbtiles file (e.g. `source: "mbtiles://./data.mbtiles"`).

## Available URLs

- If you visit the server on the configured port (default 8080) you should see your maps appearing in the browser.
- The tiles itself are served at `/{basename}/{z}/{x}/{y}[@2x].{format}`
  - The optional `@2x` part can be used to render HiDPI (retina) tiles
- Static images are rendered at:
  - `/{basename}/static/{lon},{lat},{zoom}/{width}x{height}[@2x].{format}` (center-based)
  - `/{basename}/static/{minx},{miny},{maxx},{maxy}/{zoom}[@2x].{format}` (area-based)
- TileJSON at `/{basename}/index.json`
