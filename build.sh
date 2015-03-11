#!/bin/bash -e

. version.sh

DIR="$PWD"

if [ -d ${DIR}/${package_name}_${package_version} ] ; then
	rm -rf ${DIR}/${package_name}_${package_version} || true
fi

if [ ! -d ${DIR}/git/ ] ; then
	git clone ${git_repo} ${DIR}/git/
fi

git clone --reference ${DIR}/git/ ${git_repo} ${package_name}_${package_version}

cd ${package_name}_${package_version}/

git checkout ${git_sha} -b tmp

patch -p1 < ${DIR}/patches/0001-bb.org-defaults.patch
patch -p1 < ${DIR}/patches/0002-bb.org-use-systemd.patch
patch -p1 < ${DIR}/patches/0003-core-dont-updateCore-we-checkout-a-sha-commit-and-do.patch

mkdir -p ~/.c9/
touch ~/.c9/installed

echo ""
echo "build: [./scripts/install-sdk.sh]"
./scripts/install-sdk.sh

echo ""
echo "build: [npm install --arch=armhf]"
npm install --arch=armhf

rm -Rf build/standalone
sync
sync

echo ""
echo "build: [./scripts/makestandalone.sh --compress]"
./scripts/makestandalone.sh --compress

echo ""
echo "build: [./build/build-standalone.sh]"
./build/build-standalone.sh

cd ./build/
if [ -d standalonebuild ] ; then

	cd ./standalonebuild/
	npm install systemd --arch=armhf
	npm install heapdump connect-flash ua-parser-js engine.io-client simplefunc nak pty.js --arch=armhf

	#Strip .git directories, saves over 20Mb
	cd plugins/
	find . -name ".git" | xargs rm -rf
	cd ../

	cd ../

	tar -cJvf ${package_name}_${package_version}-build.tar.xz standalonebuild/
	cp -v ${package_name}_${package_version}-build.tar.xz /mnt/farm/testing/
fi

cd ${DIR}/

