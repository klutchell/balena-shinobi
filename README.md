# balena-shinobi

shinobi stack for balenaCloud

## Requirements

- NVIDIA Jetson Nano development board
- 32GB microSD card & reader
- External USB drive with a large partition labeled VIDEOS
- Workstation with [balena CLI](https://github.com/balena-io/balena-cli/blob/master/INSTALL.md)

## Getting Started

To get started can either sign up for a free balenaCloud account and push changes to your device remotely via Git.

<https://www.balena.io/docs/learn/getting-started/jetson-nano/>

Or you can skip the balenaCloud account and push changes to your device locally via the balena CLI.

<https://www.balena.io/os/docs/jetson-nano/getting-started/>

## Deployment

Deployment is carried out by downloading the project and pushing it to your device either via Git or the balena CLI.

<https://www.balena.io/docs/reference/balena-cli/>

```bash
# push to balenaCloud
balena login
balena push myApp

# OR push to a local device running balenaOS
balena push mydevice.local --env MYSQL_ROOT_PASSWORD=******** --env TZ=America/Toronto
```

### Application Environment Variables

Application envionment variables apply to all services within the application, and can be applied fleet-wide to apply to multiple devices.

|Name|Example|Purpose|
|---|---|---|
|`MYSQL_ROOT_PASSWORD`|`********`|(required) password that will be set for the MariaDB root account|
|`ADMIN_EMAIL`|`admin@shinobi.video`|(optional) email that will be set for the Shinobi superuser account|
|`ADMIN_PASSWORD`|`admin`|(optional) password that will be set for the Shinobi superuser account|
|`TZ`|`America/Toronto`|(optional) inform services of the [timezone](https://en.wikipedia.org/wiki/List_of_tz_database_time_zones) in your location|

## Usage

Login as the superuser to create your first user account.

<http://mydevice.local/super>

The login to the dashboard and start adding monitors (cameras).

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
```

## Contributing

Please open an issue or submit a pull request with any features, fixes, or changes.

## Author

Kyle Harding <https://klutchell.dev>

## Acknowledgments

- <https://shinobi.video>
- <https://mariadb.com/>

## License

[MIT License](./LICENSE)
