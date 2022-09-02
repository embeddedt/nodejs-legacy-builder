FROM ubuntu:10.04
RUN sed -i 's/archive/old-releases/g' /etc/apt/sources.list
RUN apt-get update && apt-get install -y build-essential git-core python-software-properties
RUN add-apt-repository ppa:fkrull/deadsnakes
RUN apt-get update -y && apt-get install -y --force-yes python2.7 python2.7-dev wget zip unzip
RUN wget http://mirrors.concertpass.com/gcc/releases/gcc-8.5.0/gcc-8.5.0.tar.gz
WORKDIR /gccsource
RUN tar xzf /gcc-8.5.0.tar.gz --strip-components=1
RUN ./contrib/download_prerequisites
WORKDIR /gccbld
RUN /gccsource/configure --disable-multilib --enable-languages=c,c++ --disable-bootstrap --prefix=/crossprefix
RUN make -j2
RUN make install
WORKDIR /
# 10.04 has issues with the SSL on this server
RUN wget http://ftpmirror.gnu.org/binutils/binutils-2.36.tar.bz2
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
RUN wget http://ftpmirror.gnu.org/gnu/coreutils/coreutils-8.32.tar.gz
WORKDIR /coreutils_source
RUN tar xzf /coreutils-8.32.tar.gz --strip-components=1
# Running configure as root is not as much of an issue in our case, and not all Docker envs
# support running as an unprivileged user anyways.
ENV FORCE_UNSAFE_CONFIGURE=1
RUN ./configure --prefix=/crossprefix
RUN make -j2 install
WORKDIR /
ENV LD_LIBRARY_PATH=/crossprefix/lib64/:/crossprefix/lib/:$LD_LIBRARY_PATH
# https://github.com/nodejs/node/issues/30077#issuecomment-702808628
ENV LDFLAGS=-lrt
ENV CPPFLAGS=-D__STDC_FORMAT_MACROS
# build python
COPY Python-3.10.6.tgz /
WORKDIR /cpython
RUN tar xzf /Python-3.10.6.tgz --strip-components=1
RUN apt-get update -y && apt-get install -y libbz2-dev libffi-dev libgdbm-dev \
    liblzma-dev libncurses5-dev libreadline6-dev \
    libsqlite3-dev libssl-dev lzma lzma-dev tk-dev uuid-dev zlib1g-dev
RUN ./configure --prefix=/crossprefix --enable-optimizations
RUN make -j2 install
WORKDIR /
RUN rm -rf /cpython
COPY build-node /
COPY auxv.h /usr/include/sys/auxv.h
CMD /build-node
