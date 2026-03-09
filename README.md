# nginx-rtmp-recorder

This project builds a Docker image that compiles NGINX from source with
[`nginx-rtmp-module`](https://github.com/arut/nginx-rtmp-module) enabled and ships
an `nginx.conf` focused on recording incoming RTMP streams to disk.

## Runtime behavior

Container command:

```bash
nginx -g 'daemon off;'
```

The image exposes:

- `1935` for RTMP ingest
- `80` for the RTMP stats HTTP endpoint

Recordings are saved to the /recordings directory in the flv file format.

## How `nginx.conf` Records Streams

The default RTMP application is `record`:

- `live on;` allows live publishing
- `record all;` records incoming streams
- `record_path /recordings;` stores files in the mounted volume
- `record_suffix -%d-%b-%y_%H-%M-%S.flv;` appends a timestamp to filenames

Example publish URL pattern:

```text
rtmp://<host>:1935/record/<stream-key>
```

The HTTP server on port `80` exposes `/stat` for RTMP statistics (XML).

## Usage

### Build

```bash
docker build -t nginx-rtmp-recorder .
```

### Run

```bash
docker run --rm \
  -p 1935:1935 \
  -p 8080:80 \
  -v "$(pwd)/recordings:/recordings" \
  nginx-rtmp-recorder
```

### Publish a test stream with FFmpeg

```bash
ffmpeg -re -stream_loop -1 -i input.mp4 \
  -c copy -f flv rtmp://localhost:1935/record/test
```

You should see timestamped `.flv` recordings appear in `./recordings`.

## Notes

- This repository is not currently positioned as production-ready. Review the configuration before production use.
- There is no security on any of the APIs within this image. You should not expose this image to the internet.
