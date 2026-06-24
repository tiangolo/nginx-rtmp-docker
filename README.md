[![Deploy](https://github.com/tiangolo/nginx-rtmp-docker/workflows/Deploy/badge.svg)](https://github.com/tiangolo/nginx-rtmp-docker/actions?query=workflow%3ADeploy)

## Supported tags and respective `Dockerfile` links

* [`latest` _(Dockerfile)_](https://github.com/tiangolo/nginx-rtmp-docker/blob/master/Dockerfile)

**Note**: Note: There are [tags for each build date](https://hub.docker.com/r/tiangolo/nginx-rtmp/tags). If you need to "pin" the Docker image version you use, you can select one of those tags. E.g. `tiangolo/nginx-rtmp:latest-2020-08-16`.

# nginx-rtmp

[**Docker**](https://www.docker.com/) image with [**Nginx**](http://nginx.org/en/) using the [**nginx-rtmp-module**](https://github.com/arut/nginx-rtmp-module) module for live multimedia (video) streaming.

## Description

This [**Docker**](https://www.docker.com/) image can be used to create an RTMP server for multimedia / video streaming using [**Nginx**](http://nginx.org/en/) and [**nginx-rtmp-module**](https://github.com/arut/nginx-rtmp-module), built from the current latest sources (Nginx 1.15.0 and nginx-rtmp-module 1.2.1).

This was inspired by other similar previous images from [dvdgiessen](https://hub.docker.com/r/dvdgiessen/nginx-rtmp-docker/), [jasonrivers](https://hub.docker.com/r/jasonrivers/nginx-rtmp/), [aevumdecessus](https://hub.docker.com/r/aevumdecessus/docker-nginx-rtmp/) and by an [OBS Studio post](https://obsproject.com/forum/resources/how-to-set-up-your-own-private-rtmp-server-using-nginx.50/).

The main purpose (and test case) to build it was to allow streaming from [**OBS Studio**](https://obsproject.com/) to different clients at the same time.

**GitHub repo**: <https://github.com/tiangolo/nginx-rtmp-docker>

**Docker Hub image**: <https://hub.docker.com/r/tiangolo/nginx-rtmp/>

## Details

## How to use

* For the simplest case, just run a container with this image:

```bash
docker run -d -p 1935:1935 --name nginx-rtmp tiangolo/nginx-rtmp
```

## How to test with OBS Studio and VLC

* Run a container with the command above


* Open [OBS Studio](https://obsproject.com/)
* Click the "Settings" button
* Go to the "Stream" section
* In "Stream Type" select "Custom Streaming Server"
* In the "URL" enter the `rtmp://<ip_of_host>/live` replacing `<ip_of_host>` with the IP of the host in which the container is running. For example: `rtmp://192.168.0.30/live`
* In the "Stream key" use a "key" that will be used later in the client URL to display that specific stream. For example: `test`
* Click the "OK" button
* In the section "Sources" click the "Add" button (`+`) and select a source (for example "Screen Capture") and configure it as you need
* Click the "Start Streaming" button


* Open a [VLC](http://www.videolan.org/vlc/index.html) player (it also works in Raspberry Pi using `omxplayer`)
* Click in the "Media" menu
* Click in "Open Network Stream"
* Enter the URL from above as `rtmp://<ip_of_host>/live/<key>` replacing `<ip_of_host>` with the IP of the host in which the container is running and `<key>` with the key you created in OBS Studio. For example: `rtmp://192.168.0.30/live/test`
* Click "Play"
* Now VLC should start playing whatever you are transmitting from OBS Studio

## Manual RTMP playback test

You can also verify retransmission by watching the stream yourself. First build and run the image:

```bash
docker build -t nginx-rtmp-test .
docker run --rm --name nginx-rtmp-test -p 1935:1935 nginx-rtmp-test
```

In a second terminal, publish a generated test stream:

```bash
./scripts/publish-test-stream.sh
```

This publisher is intentionally long-running and will not exit on its own. Leave it running while you watch the stream, then stop it with `Ctrl+C`.

In a third terminal, watch the retransmitted stream:

```bash
ffplay rtmp://127.0.0.1:1935/live/test
```

You should see the moving FFmpeg test pattern and hear a generated tone. VLC can also open `rtmp://127.0.0.1:1935/live/test` as a network stream.

## Debugging

If something is not working you can check the logs of the container with:

```bash
docker logs nginx-rtmp
```

## Extending

If you need to modify the configurations you can create a file `nginx.conf` and replace the one in this image using a `Dockerfile` that is based on the image, for example:

```Dockerfile
FROM tiangolo/nginx-rtmp

COPY nginx.conf /etc/nginx/nginx.conf
```

The current `nginx.conf` contains:

```Nginx
worker_processes auto;
rtmp_auto_push on;
events {}
rtmp {
    server {
        listen 1935;
        listen [::]:1935 ipv6only=on;

        application live {
            live on;
            record off;
        }
    }
}
```

You can start from it and modify it as you need. Here's the [documentation related to `nginx-rtmp-module`](https://github.com/arut/nginx-rtmp-module/wiki/Directives).

## RTMPS (RTMP with TLS)

This image includes Nginx stream SSL support, so you can terminate TLS in Nginx and proxy the decrypted RTMP connection to the RTMP application. With this setup, clients publish and play through `rtmps://<domain>/live/<key>` on port `1935`, while the internal RTMP server listens on `127.0.0.1:1936`.

Create an `nginx.conf` like this, replacing the certificate paths with paths available inside your container:

```Nginx
worker_processes auto;
rtmp_auto_push on;
events {}

stream {
    upstream backend {
        server 127.0.0.1:1936;
    }

    server {
        listen 1935 ssl;
        proxy_pass backend;
        ssl_certificate /etc/nginx/certs/fullchain.pem;
        ssl_certificate_key /etc/nginx/certs/privkey.pem;
    }
}

rtmp {
    server {
        listen 1936;
        chunk_size 4096;

        application live {
            live on;
            record off;
        }
    }
}
```

Then build a small image with your custom configuration:

```Dockerfile
FROM tiangolo/nginx-rtmp

COPY nginx.conf /etc/nginx/nginx.conf
```

Run it with your TLS certificates mounted into the container:

```bash
docker run -d \
  -p 1935:1935 \
  -v /path/to/certs:/etc/nginx/certs:ro \
  --name nginx-rtmps \
  your-nginx-rtmps-image
```

For example, if your certificate files are mounted as
`/etc/nginx/certs/fullchain.pem` and `/etc/nginx/certs/privkey.pem`, configure an
RTMPS client to use:

```text
rtmps://<domain>/live/<key>
```

## Technical details

* This image is built from the same base official images that most of the other official images, as Python, Node, Postgres, Nginx itself, etc. Specifically, [buildpack-deps](https://hub.docker.com/_/buildpack-deps/) which is in turn based on [debian](https://hub.docker.com/_/debian/). So, if you have any other image locally you probably have the base image layers already downloaded.

* It is built from the official sources of **Nginx** and **nginx-rtmp-module** without adding anything else. (Surprisingly, most of the available images that include **nginx-rtmp-module** are made from different sources, old versions or add several other components).

* It has a simple default configuration that should allow you to send one or more streams to it and have several clients receiving multiple copies of those streams simultaneously. (It includes `rtmp_auto_push` and an automatic number of worker processes).

## License

This project is licensed under the terms of the MIT License.
