#!/bin/bash -e

. version.sh
arch=$(uname -m)

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

git_apply="git apply"
if [ ! "x${arch}" = "xarmv7l" ] ; then
	git_apply="git am --whitespace=fix"
fi

pwd

echo "1: patch -p1 < ${DIR}/patches/0001-bb.org-defaults.patch"
${git_apply} ${DIR}/patches/0001-bb.org-defaults.patch

echo "2: patch -p1 < ${DIR}/patches/0002-bb.org-use-systemd.patch"
if [ ! "x${arch}" = "xarmv7l" ] ; then
	patch -p1 < ${DIR}/patches/0002-bb.org-use-systemd.patch
	git commit -a -m 'bb.org: use systemd' -s
else
	${git_apply} ${DIR}/patches/0002-bb.org-use-systemd.patch
fi

echo "3: patch -p1 < ${DIR}/patches/0003-core-dont-updateCore-we-checkout-a-sha-commit-and-do.patch"
${git_apply} ${DIR}/patches/0003-core-dont-updateCore-we-checkout-a-sha-commit-and-do.patch

if [ ! "x${arch}" = "xarmv7l" ] ; then
	git format-patch -3 -o ${DIR}/patches/
	exit
fi

mkdir -p ~/.c9/
echo 1 > ~/.c9/installed

echo ""
echo "build: [./scripts/install-sdk.sh]"
./scripts/install-sdk.sh

if [ "x${arch}" = "xarmv7l" ] ; then
	echo ""
	echo "build: [npm install --arch=armhf]"
	npm install --arch=armhf
fi

if [ ! "x${arch}" = "xarmv7l" ] ; then
	node server.js -p 8181 -l 0.0.0.0 -a :
else
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
		npm install heapdump connect-flash ua-parser-js engine.io-client simplefunc --arch=armhf

		#https://github.com/c9/install/blob/master/install.sh

		project="nak"
		echo ""
		echo "Build: [npm install ${project} --arch=armhf]"
		npm install ${project} --arch=armhf

		#Strip .git directories, saves over 20Mb
		cd plugins/
		find . -name ".git" | xargs rm -rf
		cd ../

		cd ../

		tar -cJvf ${package_name}_${package_version}-build.tar.xz standalonebuild/
		if [ -d /mnt/farm/testing/ ] ; then
			cp -v ${package_name}_${package_version}-build.tar.xz /mnt/farm/testing/
		else
			cp -v ${package_name}_${package_version}-build.tar.xz /home/debian/
		fi
	fi
fi

cd ${DIR}/

