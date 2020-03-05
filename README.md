# balena-shinobi

shinobi stack for balenaCloud

## Requirements

- NVIDIA Jetson Nano development board
- 32GB microSD card & reader
- External USB drive with a large partition labeled VIDEOS
- Workstation with the balena CLI

## Getting Started

To get started can either sign up for a free balenaCloud account and push changes to your device remotely via Git.

<https://www.balena.io/docs/learn/getting-started/jetson-nano/>

Or you can skip the balenaCloud account and push changes to your device locally via the balena CLI.

<https://www.balena.io/os/docs/jetson-nano/getting-started/>

## Deployment

Deployment is carried out by downloading the project and pushing it to your device either via Git or the balena CLI.

<https://www.balena.io/docs/reference/balena-cli/>

```bash
# clone project
git clone https://github.com/klutchell/balena-shinobi.git

# push to balenaCloud
balena login
balena push myApp

# OR push to a local device running balenaOS
balena push mydevice.local --env MYSQL_ROOT_PASSWORD=******** --env TZ=America/Toronto
```

Prepare an external drive for recordings by creating a large partition with the label `VIDEOS`.

```bash
parted -a optimal /dev/sda mklabel GPT
parted -a optimal /dev/sda mkpart VIDEOS ext4 primary 0% 100%
```

If this partition is detected it will be automounted to `/media/{UUID}` at boot and from there it can be added to your `config.json`.

```json
  "addStorage": [
      {
         "name": "second",
         "path": "/media/2790e401-37e5-46f8-a8cd-6e0884a1a1a2/videos2"
      }
   ],
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

## Author

Kyle Harding <https://klutchell.dev>

## Acknowledgments

- <https://shinobi.video>
- <https://mariadb.com/>

## License

[MIT License](./LICENSE)
