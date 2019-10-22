package(default_visibility = ["//visibility:public"])

load(
    "@rules_python//python:python.bzl",
    "py_binary",
    "py_library",
    "py_test",
)

load("@pip_recommendationservice//:requirements.bzl", "all_requirements")
py_binary(
    name = "recommendationservice",
    srcs = [
        "demo_pb2.py",
        "demo_pb2_grpc.py",
        "client.py",
        "recommendation_server.py",
        "logger.py",
    ],
    main = "recommendation_server.py",
    deps = [] + all_requirements
)