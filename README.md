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

RTMP is an unencrypted protocol. If you would like to wrap the RTMP session in a TLS session, you can modify the Nginx configuration as show below. This allows the user to stream to rtmps://[domain]:1935. 

Modified `nginx.conf` to utilize RTMPS:

```Nginx
worker_processes auto;
rtmp_auto_push on;
events{}

stream {
    upstream backend {
        server 127.0.0.1:1936;
    }
    server {
        listen 1935 ssl;
        proxy_pass backend;
        proxy_protocol on;
        ssl_certificate /etc/letsencrypt/live/[domain]/fullchain.pem;
        ssl_certificate_key /etc/letsencrypt/[domain]/privkey.pem;
    }
}

rtmp {
    server {
        listen 1936 proxy_protocol;
        chunk_size 4096;

        application live {
            live on;
            record off;
        }
    }
}

```

## Technical details

* This image is built from the same base official images that most of the other official images, as Python, Node, Postgres, Nginx itself, etc. Specifically, [buildpack-deps](https://hub.docker.com/_/buildpack-deps/) which is in turn based on [debian](https://hub.docker.com/_/debian/). So, if you have any other image locally you probably have the base image layers already downloaded.

* It is built from the official sources of **Nginx** and **nginx-rtmp-module** without adding anything else. (Surprisingly, most of the available images that include **nginx-rtmp-module** are made from different sources, old versions or add several other components).

* It has a simple default configuration that should allow you to send one or more streams to it and have several clients receiving multiple copies of those streams simultaneously. (It includes `rtmp_auto_push` and an automatic number of worker processes).

## Release Notes

### Latest Changes

#### Internal

* 👷 Update `issue-manager.yml`. PR [#95](https://github.com/tiangolo/nginx-rtmp-docker/pull/95) by [@tiangolo](https://github.com/tiangolo).
* ⬆ Bump docker/build-push-action from 5 to 6. PR [#92](https://github.com/tiangolo/nginx-rtmp-docker/pull/92) by [@dependabot[bot]](https://github.com/apps/dependabot).
* 👷 Update `latest-changes` GitHub Action. PR [#93](https://github.com/tiangolo/nginx-rtmp-docker/pull/93) by [@tiangolo](https://github.com/tiangolo).
* ⬆ Bump docker/build-push-action from 2 to 5. PR [#68](https://github.com/tiangolo/nginx-rtmp-docker/pull/68) by [@dependabot[bot]](https://github.com/apps/dependabot).
* ⬆ Bump docker/setup-buildx-action from 1 to 3. PR [#67](https://github.com/tiangolo/nginx-rtmp-docker/pull/67) by [@dependabot[bot]](https://github.com/apps/dependabot).
* ⬆ Bump docker/login-action from 1 to 3. PR [#69](https://github.com/tiangolo/nginx-rtmp-docker/pull/69) by [@dependabot[bot]](https://github.com/apps/dependabot).
* 👷 Update issue-manager.yml GitHub Action permissions. PR [#76](https://github.com/tiangolo/nginx-rtmp-docker/pull/76) by [@tiangolo](https://github.com/tiangolo).
* 👷 Update issue-manager.yml GitHub Action permissions. PR [#75](https://github.com/tiangolo/nginx-rtmp-docker/pull/75) by [@tiangolo](https://github.com/tiangolo).
* 🔧 Add GitHub templates for discussions and issues, and security policy. PR [#72](https://github.com/tiangolo/nginx-rtmp-docker/pull/72) by [@alejsdev](https://github.com/alejsdev).
* 🔧 Update `latest-changes.yml`. PR [#70](https://github.com/tiangolo/nginx-rtmp-docker/pull/70) by [@alejsdev](https://github.com/alejsdev).

### 0.0.1

#### Features

* ✨ Allow using debug directives, enable ` --with-debug` compile option. PR [#16](https://github.com/tiangolo/nginx-rtmp-docker/pull/16) by [@agconti](https://github.com/agconti).
* ✨ Add support for multiarch builds, including ARM (e.g. Mac M1). PR [#65](https://github.com/tiangolo/nginx-rtmp-docker/pull/65) by [@tiangolo](https://github.com/tiangolo).

#### Fixes

* 👷 Fix multiarch deploy build. PR [#66](https://github.com/tiangolo/nginx-rtmp-docker/pull/66) by [@tiangolo](https://github.com/tiangolo).

#### Docs

* ✏️ Fix a typo in README. PR [#20](https://github.com/tiangolo/nginx-rtmp-docker/pull/20) by [@Irishsmurf](https://github.com/Irishsmurf).

#### Upgrades

* ⬆️ Upgrade Nginx to 1.23.2 and OS to bullseye. PR [#40](https://github.com/tiangolo/nginx-rtmp-docker/pull/40) by [@tiangolo](https://github.com/tiangolo).
* ⬆ Upgrade to nginx-1.19.7. PR [#26](https://github.com/tiangolo/nginx-rtmp-docker/pull/26) by [@cesarandreslopez](https://github.com/cesarandreslopez).
* ⬆ Update RTMP module version to 1.2.2. PR [#28](https://github.com/tiangolo/nginx-rtmp-docker/pull/28) by [@louis70109](https://github.com/louis70109).
* Upgrade Nginx to version 1.18.0. PR [#13](https://github.com/tiangolo/nginx-rtmp-docker/pull/13) by [@Nathanael-Mtd](https://github.com/Nathanael-Mtd).

#### Internal

* 👷 Update token for latest changes. PR [#50](https://github.com/tiangolo/nginx-rtmp-docker/pull/50) by [@tiangolo](https://github.com/tiangolo).
* 👷 Add GitHub Action for Docker Hub description. PR [#45](https://github.com/tiangolo/nginx-rtmp-docker/pull/45) by [@tiangolo](https://github.com/tiangolo).
* Bump tiangolo/issue-manager from 0.3.0 to 0.4.0. PR [#42](https://github.com/tiangolo/nginx-rtmp-docker/pull/42) by [@dependabot[bot]](https://github.com/apps/dependabot).
* Bump actions/checkout from 2 to 3. PR [#43](https://github.com/tiangolo/nginx-rtmp-docker/pull/43) by [@dependabot[bot]](https://github.com/apps/dependabot).
* 🎨 Format CI config. PR [#44](https://github.com/tiangolo/nginx-rtmp-docker/pull/44) by [@tiangolo](https://github.com/tiangolo).
* 👷 Add Dependabot and funding configs. PR [#41](https://github.com/tiangolo/nginx-rtmp-docker/pull/41) by [@tiangolo](https://github.com/tiangolo).
* 👷 Add scheduled CI. PR [#39](https://github.com/tiangolo/nginx-rtmp-docker/pull/39) by [@tiangolo](https://github.com/tiangolo).
* 👷 Add alls-green GitHub Action. PR [#38](https://github.com/tiangolo/nginx-rtmp-docker/pull/38) by [@tiangolo](https://github.com/tiangolo).
* 👷 Build to test on CI for PRs, update GitHub Actions. PR [#37](https://github.com/tiangolo/nginx-rtmp-docker/pull/37) by [@tiangolo](https://github.com/tiangolo).
* 👷 Add Latest Changes GitHub Action. PR [#29](https://github.com/tiangolo/nginx-rtmp-docker/pull/29) by [@tiangolo](https://github.com/tiangolo).
* Add CI with GitHub actions. PR [#15](https://github.com/tiangolo/nginx-rtmp-docker/pull/15).
* ⬆ Bump peter-evans/dockerhub-description from 3 to 4. PR [#63](https://github.com/tiangolo/nginx-rtmp-docker/pull/63) by [@dependabot[bot]](https://github.com/apps/dependabot).
* ⬆ Bump tiangolo/issue-manager from 0.4.1 to 0.5.0. PR [#64](https://github.com/tiangolo/nginx-rtmp-docker/pull/64) by [@dependabot[bot]](https://github.com/apps/dependabot).
* Bump actions/checkout from 3 to 4. PR [#52](https://github.com/tiangolo/nginx-rtmp-docker/pull/52) by [@dependabot[bot]](https://github.com/apps/dependabot).
* ⬆ Bump tiangolo/issue-manager from 0.4.0 to 0.4.1. PR [#61](https://github.com/tiangolo/nginx-rtmp-docker/pull/61) by [@dependabot[bot]](https://github.com/apps/dependabot).
* 👷 Update dependabot. PR [#55](https://github.com/tiangolo/nginx-rtmp-docker/pull/55) by [@tiangolo](https://github.com/tiangolo).
* 👷 Update latest-changes. PR [#54](https://github.com/tiangolo/nginx-rtmp-docker/pull/54) by [@tiangolo](https://github.com/tiangolo).

## License

This project is licensed under the terms of the MIT License.
