# simple-semver-release
Simple bash script to tag git repository based on semantic versioning strategy.

Include `release.sh` and the tools folder in your repository. The `release.sh` script calls a script `build.sh` not included in this repo. You can replace that command or create a `build.sh` script to build your code for the newly created release.

Before start using the script, create the first git tag in the format `v[0-9]+\.[0-9]+\.[0-9]+` (for example v0.0.0).
