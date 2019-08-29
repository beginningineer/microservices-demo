package main

var dUsageTemplate = mustTemplate(`load("@build_stack_rules_proto//{{ .Lang.Dir }}:deps.bzl", "{{ .Rule.Name }}")

{{ .Rule.Name }}()

load("@io_bazel_rules_d//d:d.bzl", "d_repositories")

d_repositories()`)

var dGrpcLibraryUsageTemplate = mustTemplate(`load("@build_stack_rules_proto//{{ .Lang.Dir }}:deps.bzl", "{{ .Rule.Name }}")

{{ .Rule.Name }}()

load("@io_bazel_rules_d//d:d.bzl", "d_repositories")

d_repositories()`)

var dProtoCompileExampleTemplate = mustTemplate(`load("@build_stack_rules_proto//{{ .Lang.Dir }}:{{ .Rule.Name }}.bzl", "{{ .Rule.Name }}")

{{ .Rule.Name }}(
    name = "person_{{ .Lang.Name }}_proto",
    deps = ["@build_stack_rules_proto//example/proto:person_proto"],
)`)

var dCompileRuleTemplate = mustTemplate(`load("//:compile.bzl", "proto_compile")
load("//:plugin.bzl", "proto_plugin")

def {{ .Rule.Name }}(**kwargs):
    # If package specified, declare a custom plugin that should correctly
    # predict the output location.
    package = kwargs.get("package")
    if package and not kwargs.get("plugins"):
        name = kwargs.get("name")
        name_plugin = name + "_plugin"
        proto_plugin(
            name = name_plugin,
            outputs = ["{package}/%s/{basename}.d" % package],
            tool = "{{ with (index .Lang.Plugins (index .Rule.Plugins 0)) }}{{ .Tool }}{{ end }}",
        )
        kwargs["plugins"] = [name_plugin]
        kwargs.pop("package")

    # Define the default plugin if still not defined
    if not kwargs.get("plugins"):
        kwargs["plugins"] = [str(Label("{{ index .Rule.Plugins 0 }}"))]

    proto_compile(
        **kwargs
    )`)

var dProtoLibraryRuleTemplate = mustTemplate(`load("//{{ .Lang.Dir}}:d_proto_compile.bzl", "d_proto_compile")
load("@io_bazel_rules_d//d:d.bzl", "d_library")

def {{ .Rule.Name }}(**kwargs):
    name = kwargs.get("name")
    deps = kwargs.get("deps")
    visibility = kwargs.get("visibility")

    name_pb = name + "_pb"

    d_proto_compile(
        name = name_pb,
        deps = deps,
        visibility = visibility,
        verbose = kwargs.pop("verbose", 0),
        transitivity = kwargs.pop("transitivity", {}),
        transitive = kwargs.pop("transitive", True),
    )

    d_library(
        name = name,
        srcs = [name_pb],
        deps = [
			"@com_github_dcarp_protobuf_d//:protosrc",
            "@com_github_dcarp_protobuf_d//:protobuf",
		],
		imports = ["external/com_github_dcarp_protobuf_d/src"],
        visibility = visibility,
    )`)

var dGrpcLibraryRuleTemplate = mustTemplate(`load("//{{ .Lang.Dir}}:d_grpc_compile.bzl", "d_grpc_compile")
load("@io_bazel_rules_d//d:d.bzl", "d_library")

def {{ .Rule.Name }}(**kwargs):
    name = kwargs.get("name")
    deps = kwargs.get("deps")
    verbose = kwargs.get("verbose")
    visibility = kwargs.get("visibility")

    name_pb = name + "_pb"
    d_grpc_compile(
        name = name_pb,
        deps = deps,
        visibility = visibility,
        verbose = kwargs.pop("verbose", 0),
        transitivity = kwargs.pop("transitivity", {}),
        transitive = kwargs.pop("transitive", True),
    )

    d_library(
        name = name,
        srcs = [name_pb],
        deps = [
        ],
        visibility = visibility,
    )`)

func makeD() *Language {
	return &Language{
		Dir:   "d",
		Name:  "d",
		Flags: commonLangFlags,
		Plugins: map[string]*Plugin{
			"//d:d": &Plugin{
				Tool: "@com_github_dcarp_protobuf_d//:protoc-gen-d",
			},
		},
		Rules: []*Rule{
			&Rule{
				Name:           "d_proto_compile",
				Implementation: dCompileRuleTemplate,
				Plugins:        []string{"//d:d"},
				Usage:          dUsageTemplate,
				Example:        dProtoCompileExampleTemplate,
				Doc:            "Generates d protobuf artifacts",
				Attrs:          append(protoCompileAttrs, []*Attr{}...),
				Flags: []*Flag{
					{
						Category: "build",
						Name:     "incompatible_disallow_struct_provider_syntax",
						Value:    "false",
					},
				},
			},
			// &Rule{
			// 	Name:           "d_grpc_compile",
			// 	Implementation: compileRuleTemplate,
			// 	Plugins:        []string{"//d:grpc_d"},
			// 	Usage:          dUsageTemplate,
			// 	Example:        grpcCompileExampleTemplate,
			// 	Doc:            "Generates d protobuf+gRPC artifacts",
			// 	Attrs:          append(protoCompileAttrs, []*Attr{}...),
			// },
			// &Rule{
			// 	Name:           "d_proto_library",
			// 	Implementation: dProtoLibraryRuleTemplate,
			// 	Usage:          dUsageTemplate,
			// 	Example:        protoLibraryExampleTemplate,
			// 	Doc:            "Generates d protobuf library",
			// 	Attrs:          append(protoCompileAttrs, []*Attr{}...),
			// },
			// &Rule{
			// 	Name:           "d_grpc_library",
			// 	Implementation: dGrpcLibraryRuleTemplate,
			// 	Usage:          dGrpcLibraryUsageTemplate,
			// 	Example:        grpcLibraryExampleTemplate,
			// 	Doc:            "Generates d protobuf+gRPC library",
			// 	Attrs:          append(protoCompileAttrs, []*Attr{}...),
			// },
		},
	}
}
