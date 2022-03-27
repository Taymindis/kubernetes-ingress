#!/bin/bash

# Copyright 2021 The Kubernetes Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -o errexit
set -o nounset
set -o pipefail

export NGINX_VERSION=1.21.3
export IF_REQUEST_BODY_VERSION=v2.0.6-alpha

export BUILD_PATH=/tmp/build

rm -rf \
   /var/cache/debconf/* \
   /var/lib/apt/lists/* \
   /var/log/* \
   /tmp/* \
   /var/tmp/*


mkdir -p /etc/nginx
mkdir --verbose -p "$BUILD_PATH"
cd "$BUILD_PATH"

apk add \
  curl \
  git \
  build-base

get_src()
{
  url="$1"
  f="$2"

  echo "Downloading $url"

  curl -sSL "$url" -o "$f"
  tar xzf "$f"
  rm -rf "$f"
}

get_if_req_body_src()
{
  url="$1"
  f="$2"

  echo "Downloading $url"

  curl -sSL "$url" -o "$f"
  tar xzf "$f"
  rm -rf "$f"
  mv nginx-if-request-body* nginx-if-request-body
}


get_src "https://nginx.org/download/nginx-$NGINX_VERSION.tar.gz" "nginx-$NGINX_VERSION.tar.gz"

# Please update version make sure it's really take refresh when building image
get_if_req_body_src "https://github.com/Taymindis/nginx-if-request-body/archive/refs/tags/$IF_REQUEST_BODY_VERSION.tar.gz" "nginx-$NGINX_VERSION.tar.gz"


# improve compilation times
CORES=$(($(grep -c ^processor /proc/cpuinfo) - 1))

export MAKEFLAGS=-j${CORES}

apk add \
  protobuf-dev \
  grpc \
  grpc-dev \
  gtest-dev \
  c-ares-dev \
  pcre-dev

# build nginx
cd "$BUILD_PATH/nginx-$NGINX_VERSION"
./configure \
  --prefix=/usr/local/nginx \
  --with-compat \
  --add-dynamic-module=$BUILD_PATH/nginx-if-request-body

make modules
mkdir -p /etc/nginx/modules

cp objs/ngx_http_if_request_body_module.so /etc/nginx/modules/ngx_http_if_request_body_module.so

# remove .a files
rm -rf objs
