# syntax=docker/dockerfile:1
FROM ubuntu:10.04 AS builder

# Install essential packages for building
RUN sed -i 's/archive/old-releases/g' /etc/apt/sources.list
RUN apt-get update -y && apt-get install -y --force-yes build-essential git-core python-software-properties wget \
    zip unzip pkg-config libbz2-dev libffi-dev libgdbm-dev liblzma-dev libncurses5-dev libreadline6-dev \
    libsqlite3-dev libssl-dev lzma lzma-dev tk-dev uuid-dev zlib1g-dev python3

# Build OpenSSL
COPY openssl-1.1.1q.tar.gz /
WORKDIR /opensslbld
RUN tar xzf /openssl-1.1.1q.tar.gz --strip-components=1
RUN ./config no-tests --prefix=/crossprefix
RUN make -j2
RUN make install
WORKDIR /
RUN rm -rf /opensslbld

# Ensure wget compiles against OpenSSL in /crossprefix
ENV PKG_CONFIG_PATH=/crossprefix/lib/pkgconfig

# Build wget against new OpenSSL (use HTTP for this, but verify the checksum)
RUN wget http://ftp.gnu.org/gnu/wget/wget-1.21.3.tar.gz
COPY wget.sha512sum /
RUN sha512sum -c wget.sha512sum
WORKDIR /wgetbld
RUN tar xzf /wget-1.21.3.tar.gz --strip-components=1
RUN ./configure --with-ssl=openssl --prefix=/crossprefix
RUN make -j2
RUN make install
WORKDIR /
RUN rm -rf /wgetbld

# Make sure SSL is on the library path
ENV LD_LIBRARY_PATH=/crossprefix/lib:/crossprefix/lib64

# Install newer certificates
WORKDIR /cacerts
COPY ca-certificates_20210119~20.04.2.tar.xz /
RUN tar -xJf /ca-certificates_20210119~20.04.2.tar.xz --strip-components=1
RUN make
RUN make install
WORKDIR /usr/share/ca-certificates
RUN rm -rf /cacerts
RUN sed -i"" 's/mozilla\/DST_Root_CA_X3.crt/!mozilla\/DST_Root_CA_X3.crt/' /etc/ca-certificates.conf
RUN dpkg-reconfigure -fnoninteractive ca-certificates
RUN rm mozilla/DST_Root_CA_X3.crt
RUN find * -name \*.crt > /etc/ca-certificates.conf
RUN update-ca-certificates
RUN ln -s /etc/ssl/certs/ca-certificates.crt /crossprefix/ssl/cert.pem
WORKDIR /

# Build GCC 8.5
RUN /crossprefix/bin/wget https://mirrors.concertpass.com/gcc/releases/gcc-8.5.0/gcc-8.5.0.tar.gz
WORKDIR /gccsource
RUN tar xzf /gcc-8.5.0.tar.gz --strip-components=1
RUN ./contrib/download_prerequisites
WORKDIR /gccbld
RUN /gccsource/configure --disable-multilib --enable-languages=c,c++ --disable-bootstrap --prefix=/crossprefix
RUN make -j2
RUN make install
WORKDIR /

# Build binutils
RUN /crossprefix/bin/wget https://ftpmirror.gnu.org/binutils/binutils-2.36.tar.bz2
WORKDIR /binutils_source
RUN tar xjf /binutils-2.36.tar.bz2 --strip-components=1
WORKDIR /binutilsbld
RUN /binutils_source/configure --prefix=/crossprefix
RUN make -j2
RUN make install
WORKDIR /crossprefix/bin
RUN ln -s gcc cc
WORKDIR /
ENV PATH="/crossprefix/bin:${PATH}"
RUN rm -rf /gccsource /binutils_source /gccbld /binutilsbld /*.tar.bz2
RUN gcc --version
# Build a newer coreutils for nproc et al.
RUN /crossprefix/bin/wget https://ftpmirror.gnu.org/gnu/coreutils/coreutils-8.32.tar.gz
WORKDIR /coreutils_source
RUN tar xzf /coreutils-8.32.tar.gz --strip-components=1
# Running configure as root is not as much of an issue in our case, and not all Docker envs
# support running as an unprivileged user anyways.
ENV FORCE_UNSAFE_CONFIGURE=1
RUN ./configure --prefix=/crossprefix
RUN make -j2 install
WORKDIR /
ENV LD_LIBRARY_PATH=/crossprefix/lib64/:/crossprefix/lib/:$LD_LIBRARY_PATH

# build python
RUN /crossprefix/bin/wget https://www.python.org/ftp/python/3.10.6/Python-3.10.6.tgz
WORKDIR /cpython
RUN tar xzf /Python-3.10.6.tgz --strip-components=1
RUN ./configure --prefix=/crossprefix --enable-optimizations
RUN make -j2 install
WORKDIR /
RUN rm -rf /cpython

# Create final builder image
FROM ubuntu:10.04
RUN sed -i 's/archive/old-releases/g' /etc/apt/sources.list
ENV PATH=/crossprefix/bin:$PATH
ENV LD_LIBRARY_PATH=/crossprefix/lib:/crossprefix/lib64
# https://github.com/nodejs/node/issues/30077#issuecomment-702808628
ENV LDFLAGS=-lrt
ENV CPPFLAGS=-D__STDC_FORMAT_MACROS
WORKDIR /
COPY --from=builder /crossprefix /crossprefix
RUN apt-get update -y && apt-get install -y build-essential git-core
COPY build-node /
COPY auxv.h /usr/include/sys/auxv.h
CMD /build-node
