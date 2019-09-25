#!/usr/bin/env bash
set -e

curl -s "https://get.sdkman.io" | bash
source "$HOME/.sdkman/bin/sdkman-init.sh"
sdk install gradle
sdk use kotlin 1.3.41
sdk install kotlin