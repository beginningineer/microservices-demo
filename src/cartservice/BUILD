package(default_visibility = [ "//visibility:public" ])

proto_library(
    name = "demo_proto",
    srcs = ["pb/demo.proto"],
)

load(
    "@build_stack_rules_proto//csharp:csharp_grpc_library.bzl",
    "csharp_grpc_library"
)

csharp_grpc_library(
    name = "demo_proto_library",
    deps = [
        "demo_proto",
    ]
)

load(
    "@io_bazel_rules_dotnet//dotnet:defs.bzl",
    "core_binary",
)

core_binary(
  name = "cartservice",
  srcs = [
        "interfaces/ICartStore.cs",
        "cartstore/LocalCartStore.cs",
        "cartstore/RedisCartStore.cs",
        "CartServiceImpl.cs",
        "HealthImpl.cs",
        "Program.cs"
      ],
  deps = [
      "@io_bazel_rules_dotnet//dotnet/stdlib.core:system.dll",
      ":demo_proto_library",
      "@stackexchange.redis//:netcore",
      "@grpc.healthcheck//:netcore",
      "@commandlineparser//:netcoreapp2.0_core",
      "@microsoft.extensions.configuration//:netcore",
  ],
  visibility = ["//visibility:public"],
)

load(
    "@io_bazel_rules_docker//container:container.bzl",
    "container_image",
)


#container_image(
#    name = "image",
#    base = "@alpine_linux_amd64//image",
##    entrypoint = [
##        "./cartservice",
##        "start",
##    ],
##    layers = [
##        ":cartservice"
##    ],
#    files = [
#        ":cartservice",
#    ],
#    ports = [
#        "8080/tcp",
#    ],
#)
