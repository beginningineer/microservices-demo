package(default_visibility = ["//visibility:public"])

load(
    "@rules_python//python:python.bzl",
    "py_binary",
    "py_library",
    "py_test",
)

load("@pip_emailservice//:requirements.bzl", "all_requirements")
py_binary(
    name = "emailservice",
    srcs = [
        "demo_pb2.py",
        "demo_pb2_grpc.py",
        "email_client.py",
        "email_server.py",
        "logger.py",
    ],
    main = "email_server.py",
    deps = [] + all_requirements
)