load("@bazel_tools//tools/build_defs/repo:git.bzl", "git_repository")
git_repository(
    name = "rules_python",
    remote = "https://github.com/bazelbuild/rules_python.git",
    commit = "f46e953f6e0315a3f884154f9395a32ec9999eab",
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
