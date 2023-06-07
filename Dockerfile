FROM rust:alpine AS build

RUN apk add --update alpine-sdk
RUN mkdir /output

COPY . /src

WORKDIR /src
RUN cargo install --locked --root /output --path ./crates/cairo-lang-compiler
RUN cargo install --locked --root /output --path ./crates/cairo-lang-formatter
RUN cargo install --locked --root /output --path ./crates/cairo-lang-language-server
RUN cargo install --locked --root /output --path ./crates/cairo-lang-runner
RUN cargo install --locked --root /output --path ./crates/cairo-lang-sierra-to-casm
RUN cargo install --locked --root /output --path ./crates/cairo-lang-starknet
RUN cargo install --locked --root /output --path ./crates/cairo-lang-syntax-codegen
RUN cargo install --locked --root /output --path ./crates/cairo-lang-test-runner

FROM alpine:latest

COPY --from=build /output/bin/* /usr/bin/
COPY --from=build /src/corelib /corelib

ENTRYPOINT [ "sh" ]
