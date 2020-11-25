# balena-shinobi

shinobi video stack for balenaCloud

## Requirements

- NVIDIA Jetson Nano development board
- Optional external USB drive for video storage

## Getting Started

You can one-click-deploy this project to balena using the button below:

[![deploy button](https://balena.io/deploy.png)](https://dashboard.balena-cloud.com/deploy?repoUrl=https://github.com/klutchell/balena-shinobi&defaultDeviceType=jetson-nano)

## Manual Deployment

Alternatively, deployment can be carried out by manually creating a [balenaCloud account](https://dashboard.balena-cloud.com) and application, flashing a device, downloading the project and pushing it via either Git or the [balena CLI](https://github.com/balena-io/balena-cli).

### Application Environment Variables

Application envionment variables apply to all services within the application, and can be applied fleet-wide to apply to multiple devices.

|Name|Example|Purpose|
|---|---|---|
|`MYSQL_ROOT_PASSWORD`|`********`|(required) password that will be set for the MariaDB root account|
|`ADMIN_EMAIL`|`admin@shinobi.video`|(optional) email that will be set for the Shinobi superuser account|
|`ADMIN_PASSWORD`|`admin`|(optional) password that will be hashed and set for the Shinobi superuser account|
|`TZ`|`America/Toronto`|(optional) inform services of the [timezone](https://en.wikipedia.org/wiki/List_of_tz_database_time_zones) in your location|

## Usage

<https://shinobi.video/docs/>

Log in as superuser to create your first user account. The default credentials are in your device logs.

<http://mydevice.local/super>

Then log in to the dashboard and start adding monitors (cameras).

<http://mydevice.local>

## Development

```bash
# cross build for aarch64 on an amd64 or i386 workstation with Docker
export DOCKER_CLI_EXPERIMENTAL=enabled
docker run --rm --privileged multiarch/qemu-user-static --reset -p yes
docker buildx create --use --driver docker-container
docker buildx build . --platform linux/arm64 --load --progress plain -t shinobi

# review which ffmpeg features were included
docker run --rm -it --entrypoint ldd shinobi /usr/bin/ffmpeg
docker run --rm -it --entrypoint ffmpeg shinobi -hwaccels
docker run --rm -it --entrypoint ffmpeg shinobi -encoders | grep 264
docker run --rm -it --entrypoint ffmpeg shinobi -decoders | grep 264

# dump the flags being passed to ffmpeg (while connected to running container)
ps -eo args | grep ffmpeg | head -n -1
```

## Contributing

Please open an issue or submit a pull request with any features, fixes, or changes.

## Acknowledgments

- <https://shinobi.video>
- <https://mariadb.com/>
