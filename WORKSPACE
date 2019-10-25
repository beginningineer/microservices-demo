load("@bazel_tools//tools/build_defs/repo:git.bzl", "git_repository")
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

git_repository(
    name = "rules_python",
    remote = "https://github.com/bazelbuild/rules_python.git",
    commit = "f46e953f6e0315a3f884154f9395a32ec9999eab",
    shallow_since = "1571411816 -0400",
)

load(
    "@rules_python//python:pip.bzl",
    "pip_import",
    "pip_repositories",
)

pip_repositories()

pip_import(
    name = "pip_emailservice",
    requirements = "//src/emailservice:requirements.txt",
)
load("@pip_emailservice//:requirements.bzl", emailservice_pip_install = "pip_install")
emailservice_pip_install()

pip_import(
    name = "pip_recommendationservice",
    requirements = "//src/recommendationservice:requirements.txt",
)
load("@pip_recommendationservice//:requirements.bzl", recommendationservice_pip_install = "pip_install")
recommendationservice_pip_install()

######### Protobuf Python
http_archive(
    name = "build_stack_rules_proto",
    sha256 = "85ccc69a964a9fe3859b1190a7c8246af2a4ead037ee82247378464276d4262a",
    strip_prefix = "rules_proto-d9a123032f8436dbc34069cfc3207f2810a494ee",
    urls = ["https://github.com/stackb/rules_proto/archive/d9a123032f8436dbc34069cfc3207f2810a494ee.tar.gz"],
)

load("@build_stack_rules_proto//python:deps.bzl", "python_grpc_library")

python_grpc_library()

load("@com_github_grpc_grpc//bazel:grpc_deps.bzl", "grpc_deps")

grpc_deps()

pip_import(
    name = "protobuf_py_deps",
    requirements = "@build_stack_rules_proto//python/requirements:protobuf.txt",
)

load("@protobuf_py_deps//:requirements.bzl", protobuf_pip_install = "pip_install")

protobuf_pip_install()

pip_import(
    name = "grpc_py_deps",
    requirements = "@build_stack_rules_proto//python:requirements.txt",
)

load("@grpc_py_deps//:requirements.bzl", grpc_pip_install = "pip_install")

grpc_pip_install()