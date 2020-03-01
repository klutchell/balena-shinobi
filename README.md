# balena-shinobi

shinobi stack for balenaCloud

## Requirements

- NVIDIA Jetson Nano development board wih SD card
- An external USB drive with a partition labeled VIDEOS

## Getting Started

To get started you'll first need to sign up for a free balenaCloud account and flash your device.

<https://www.balena.io/docs/learn/getting-started>

## Deployment

Once your account is set up, deployment is carried out by downloading the project and pushing it to your device either via the balena CLI.

### Application Environment Variables

Application envionment variables apply to all services within the application, and can be applied fleet-wide to apply to multiple devices.

|Name|Example|Purpose|
|---|---|---|
|`MYSQL_ROOT_PASSWORD`|`********`|password that will be set for the MariaDB root account|
|`TZ`|`America/Toronto`|(optional) inform services of the [timezone](https://en.wikipedia.org/wiki/List_of_tz_database_time_zones) in your location|

## Usage

```bash
# install pre-commit hook (optional)
ln -s ../../pre-commit .git/hooks/pre-commit

# copy required file(s) from Jetson SDK Manager downloads directory
cp ~/Downloads/nvidia/sdkm_downloads/Jetson-210_Linux_R32.3.1_aarch64.tbz2 .

# cross build locally for aarch64 (optional)
export DOCKER_CLI_EXPERIMENTAL=enabled
docker run --rm --privileged multiarch/qemu-user-static --reset -p yes
docker buildx create --use --driver docker-container
docker buildx build . --platform linux/arm64 --load --progress plain --target final -t shinobi

# push to balena app
balena login
balena push shinobi
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
