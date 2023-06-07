FROM rust:alpine AS build

RUN apk add --update alpine-sdk
RUN mkdir /output

COPY . /src

WORKDIR /src
RUN cargo install --locked --root /output --path ./crates/cairo-lang-test-runner

FROM alpine:latest

COPY --from=build /output/bin/* /usr/bin/
COPY --from=build /src/corelib /corelib

ENTRYPOINT [ "sh" ]
