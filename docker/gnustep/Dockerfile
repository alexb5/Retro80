# Проверка сборки Retro80 под Linux: GNUstep на libobjc2 (ARC, -fobjc-runtime=gnustep-2.2).
# Пакеты GNUstep в Debian собраны под рантайм GCC, поэтому всё собирается из исходников.
#
#   docker build -t retro80-gnustep docker/gnustep
#   docker run --rm -v "$PWD":/src:ro retro80-gnustep
#
# Версии закреплены коммитами, на которых сборка проверена; обновлять осознанно.

FROM debian:trixie

ARG LIBOBJC2_REV=a21ae931e4c186312701d7a4a8e85204955965a6
ARG LIBDISPATCH_REV=ce1b4d3540427a8c8a17a3b5eb7c5749665d384e
ARG TOOLS_MAKE_REV=cafd2c4a73b568b2f0022f15a149963f39c564f3
ARG LIBS_BASE_REV=555420c63e1146c2ac141084b9f14b04b7c2cb19
ARG LIBS_GUI_REV=cacd5cb0897121c0003f625ab2db5b6152556ce9

RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
	ca-certificates git clang lld cmake ninja-build make pkg-config \
	libffi-dev libxml2-dev libxslt1-dev libgnutls28-dev libicu-dev libcurl4-gnutls-dev \
	zlib1g-dev libbsd-dev \
	libtiff-dev libpng-dev libjpeg-dev libgif-dev \
	libgl-dev libglu1-mesa-dev \
	&& rm -rf /var/lib/apt/lists/*

ENV CC=clang CXX=clang++

SHELL ["/bin/bash", "-c"]

# fetch <repo> <commit>: неглубокий клон ровно одного коммита в /opt/src/<repo>
RUN printf '%s\n' \
	'set -e' \
	'mkdir -p /opt/src/$1 && cd /opt/src/$1' \
	'git init -q && git remote add origin https://github.com/$1.git' \
	'git fetch -q --depth 1 origin $2 && git checkout -q FETCH_HEAD' \
	> /usr/local/bin/fetch && chmod +x /usr/local/bin/fetch

WORKDIR /opt/src

# libobjc из GCC (без блоков) иначе перехватил бы -lobjc у libobjc2
RUN fetch gnustep/libobjc2 $LIBOBJC2_REV \
	&& cd gnustep/libobjc2 && git submodule update -q --init --depth 1 \
	&& cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Release -DTESTS=OFF \
	&& ninja -C build install \
	&& rm -f /usr/lib/gcc/*/*/libobjc.*

# libdispatch на не-Apple всегда ставит свой libBlocksRuntime; отключить это нельзя
RUN fetch swiftlang/swift-corelibs-libdispatch $LIBDISPATCH_REV \
	&& cd swiftlang/swift-corelibs-libdispatch \
	&& cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Release -DBUILD_TESTING=OFF -DINSTALL_PRIVATE_HEADERS=YES \
	&& ninja -C build install \
	&& ldconfig

RUN fetch gnustep/tools-make $TOOLS_MAKE_REV \
	&& cd gnustep/tools-make \
	&& ./configure --with-layout=gnustep --with-library-combo=ng-gnu-gnu \
		--with-runtime-abi=gnustep-2.2 --enable-objc-arc --enable-native-objc-exceptions \
		--enable-install-ld-so-conf \
	&& make install

RUN fetch gnustep/libs-base $LIBS_BASE_REV \
	&& . /usr/GNUstep/System/Library/Makefiles/GNUstep.sh \
	&& cd gnustep/libs-base && ./configure && make -j"$(nproc)" && make install && ldconfig

RUN fetch gnustep/libs-gui $LIBS_GUI_REV \
	&& . /usr/GNUstep/System/Library/Makefiles/GNUstep.sh \
	&& cd gnustep/libs-gui && ./configure && make -j"$(nproc)" && make install && ldconfig

COPY build.sh /usr/local/bin/build-retro80

WORKDIR /work
CMD ["build-retro80"]
