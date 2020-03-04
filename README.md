# balena-shinobi

shinobi stack for balenaCloud

## Requirements

- NVIDIA Jetson Nano development board
- 32GB microSD card
- External USB drive with a large partition labeled VIDEOS

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
# install pre-commit hook to avoid pushing binary files to git (optional)
ln -s ../../pre-commit .git/hooks/pre-commit

# copy required file(s) from Jetson SDK Manager downloads directory
mkdir l4t-32.3.1
cp ~/Downloads/nvidia/sdkm_downloads/Jetson-210_Linux_R32.3.1_aarch64.tbz2 l4t-32.3.1/
cp ~/Downloads/nvidia/sdkm_downloads/cuda-repo-l4t-10-0-local-10.0.326_1.0-1_arm64.deb l4t-32.3.1/
cp ~/Downloads/nvidia/sdkm_downloads/libcudnn7_7.6.3.28-1+cuda10.0_arm64.deb l4t-32.3.1/
cp ~/Downloads/nvidia/sdkm_downloads/libcudnn7-dev_7.6.3.28-1+cuda10.0_arm64.deb l4t-32.3.1/

# cross build locally for aarch64 (optional)
export DOCKER_CLI_EXPERIMENTAL=enabled
docker run --rm --privileged multiarch/qemu-user-static --reset -p yes
docker buildx create --use --driver docker-container
docker buildx build . --platform linux/arm64 --load --progress plain -t shinobi

# verify some ffmpeg features were included correctly (optional)
docker run --rm -it --entrypoint ldd shinobi /usr/bin/ffmpeg
docker run --rm -it --entrypoint ffmpeg shinobi -encoders | grep 264
docker run --rm -it --entrypoint ffmpeg shinobi -decoders | grep 264

# push to balena app
balena login
balena push shinobi
```

Fix the cpu monitor by adding this to `config.json` via the superuser login.

```json
"customCpuCommand": "top -b -n 2 | awk '{IGNORECASE = 1} /^.?Cpu/ {gsub(\"id,\",\"100\",$8); gsub(\"%\",\"\",$8); print 100-$8}' | tail -n 1",
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
