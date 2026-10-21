#!/bin/bash

#
# Copyright (C) 2023 Nethesis S.r.l.
# SPDX-License-Identifier: GPL-3.0-or-later
#

# Terminate on error
set -e

# Prepare variables for later use
images=()
# The image will be pushed to GitHub container registry
repobase="${REPOBASE:-ghcr.io/mrmarkuz}"
# Configure the image name
reponame="zabbix"

# Zabbix web frontend: the official Alpine image with its php85 packages
# upgraded. The published 7.0.32-alpine image still runs PHP 8.5.11, affected
# by CVE-2026-109618/109619 ("PHP2Shell"); Alpine ships the fix (8.5.12) as a
# package. Remove this image (and use web_upstream in the label again) once
# Zabbix publishes an image with PHP >= php_version.
web_upstream="docker.io/zabbix/zabbix-web-nginx-pgsql:7.0.32-alpine"
php_version="8.5.12"
web_container=$(buildah from "${web_upstream}")
buildah run --user root "${web_container}" -- sh -c 'apk upgrade --no-cache $(apk info | grep "^php85")'
built_php=$(buildah run "${web_container}" -- php-fpm85 -v | sed -n '1s/^PHP \([0-9.]*\) .*/\1/p')
if [[ "${built_php}" != "${php_version}" ]]; then
    echo "Zabbix web image runs PHP ${built_php}, expected ${php_version}" >&2
    exit 1
fi
buildah config \
    --label="org.opencontainers.image.source=https://github.com/mrmarkuz/ns8-zabbix" \
    --label="org.opencontainers.image.description=${web_upstream##*/} with PHP ${php_version}" \
    "${web_container}"
buildah commit "${web_container}" "${repobase}/zabbix-web-nginx-pgsql"
images+=("${repobase}/zabbix-web-nginx-pgsql")

# Create a new empty container image
container=$(buildah from scratch)

# Reuse existing nodebuilder-zabbix container, to speed up builds
if ! buildah containers --format "{{.ContainerName}}" | grep -q nodebuilder-zabbix; then
    echo "Pulling NodeJS runtime..."
    buildah from --name nodebuilder-zabbix -v "${PWD}:/usr/src:Z" docker.io/library/node:lts
fi

echo "Build static UI files with node..."
buildah run \
    --workingdir=/usr/src/ui \
    --env="NODE_OPTIONS=--openssl-legacy-provider" \
    nodebuilder-zabbix \
    sh -c "yarn install && yarn build"

# Add imageroot directory to the container image
buildah add "${container}" imageroot /imageroot
buildah add "${container}" ui/dist /ui
# Setup the entrypoint, ask to reserve one TCP port with the label and set a rootless container
# Select you image(s) with the label org.nethserver.images
# ghcr.io/xxxxx is the GitHub container registry or your own registry or docker.io for Docker Hub
# The image tag is set to latest by default, but can be overridden with the IMAGETAG environment variable
# rootfull=0 === rootless container
# tcp-ports-demand=1 number of tcp Port to reserve , 1 is the minimum, can be udp or tcp
buildah config --entrypoint=/ \
    --label="org.nethserver.max-per-node=1" \
	--label="org.nethserver.min-core=3.12.4-0" \
    --label="org.nethserver.authorizations=node:fwadm traefik@any:routeadm" \
    --label="org.nethserver.tcp-ports-demand=1" \
    --label="org.nethserver.rootfull=0" \
    --label="org.nethserver.images=docker.io/postgres:15.18-alpine docker.io/zabbix/zabbix-server-pgsql:7.0.32-alpine docker.io/zabbix/zabbix-agent2:7.0.32-alpine ${repobase,,}/zabbix-web-nginx-pgsql:${IMAGETAG:-latest}" \
    "${container}"
# Commit the image
buildah commit "${container}" "${repobase}/${reponame}"

# Append the image URL to the images array
images+=("${repobase}/${reponame}")

#
# NOTICE:
#
# It is possible to build and publish multiple images.
#
# 1. create another buildah container
# 2. add things to it and commit it
# 3. append the image url to the images array
#

#
# Setup CI when pushing to Github. 
# Warning! docker::// protocol expects lowercase letters (,,)
if [[ -n "${CI}" ]]; then
    # Set output value for Github Actions
    printf "images=%s\n" "${images[*],,}" >> "${GITHUB_OUTPUT}"
else
    # Just print info for manual push
    printf "Publish the images with:\n\n"
    for image in "${images[@],,}"; do printf "  buildah push %s docker://%s:%s\n" "${image}" "${image}" "${IMAGETAG:-latest}" ; done
    printf "\n"
fi
