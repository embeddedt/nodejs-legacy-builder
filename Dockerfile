FROM ubuntu:10.04
RUN sed -i 's/archive/old-releases/g' /etc/apt/sources.list
RUN apt-get update
RUN apt-get install -y build-essential git-core python-software-properties
RUN add-apt-repository ppa:fkrull/deadsnakes
RUN apt-get update
RUN apt-get install -y --force-yes python2.7 python2.7-dev
RUN apt-get install -y wget
RUN wget http://mirrors.concertpass.com/gcc/releases/gcc-6.3.0/gcc-6.3.0.tar.bz2
WORKDIR /gccsource
RUN tar xjf /gcc-6.3.0.tar.bz2 --strip-components=1
RUN ./contrib/download_prerequisites
WORKDIR /gccbld
RUN /gccsource/configure --disable-multilib --enable-languages=c,c++ --disable-bootstrap --prefix=/crossprefix
RUN make -j2
RUN make install
WORKDIR /
# 10.04 has issues with the SSL on this server
RUN wget http://ftpmirror.gnu.org/binutils/binutils-2.26.tar.bz2
WORKDIR /binutils_source
RUN tar xjf /binutils-2.26.tar.bz2 --strip-components=1
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
# extra deps for node
RUN apt-get install -y zip unzip
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
COPY build-node /
CMD /build-node
