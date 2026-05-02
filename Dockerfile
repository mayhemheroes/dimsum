# Build Stage
FROM --platform=linux/amd64 ubuntu:20.04 AS builder

## Install build dependencies
WORKDIR /
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y clang apt-transport-https curl gnupg
RUN curl -fsSL https://bazel.build/bazel-release.pub.gpg | gpg --dearmor > bazel.gpg
RUN mv bazel.gpg /etc/apt/trusted.gpg.d/
RUN echo "deb [arch=amd64] https://storage.googleapis.com/bazel-apt stable jdk1.8" | tee /etc/apt/sources.list.d/bazel.list
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y bazel=5.4.0

## Add source code to the build stage.
ADD . /dimsum
WORKDIR /dimsum

## Build
RUN CC=clang bazel build --copt=-msse4.1 --compilation_mode=opt --copt=-fsanitize=address,fuzzer-no-link --linkopt=-fsanitize=address,fuzzer-no-link --cxxopt=-std=c++17 ...
WORKDIR ./bazel-bin/
RUN cp libdimsum_fuzz.so /usr/lib/libdimsum_fuzz.so
RUN clang -fsanitize=address,fuzzer libdimsum_fuzz.lo libdimsum_fuzz.so -o dimsum-fuzz

## Get dependencies
RUN mkdir /deps
RUN cp `ldd /dimsum/bazel-bin/dimsum-fuzz | grep so | sed -e '/^[^\t]/ d' | sed -e 's/\t//' | sed -e 's/.*=..//' | sed -e 's/ (0.*)//' | sort | uniq` /deps 2>/dev/null || :

## Package Stage
FROM --platform=linux/amd64 ubuntu:20.04
COPY --from=builder /dimsum/bazel-bin/dimsum-fuzz /dimsum-fuzz
COPY --from=builder /usr/lib/libdimsum_fuzz.so /usr/lib
RUN ldconfig

CMD ["/dimsum-fuzz"]
