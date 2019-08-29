package main

var swiftUsageTemplate = mustTemplate(`load("@build_stack_rules_proto//{{ .Lang.Dir }}:deps.bzl", "{{ .Rule.Name }}")

{{ .Rule.Name }}()

load(
    "@build_bazel_rules_swift//swift:repositories.bzl",
    "swift_rules_dependencies",
)

swift_rules_dependencies()

load(
    "@build_bazel_apple_support//lib:repositories.bzl",
    "apple_support_dependencies",
)

apple_support_dependencies()`)

var swiftProtoLibraryRuleTemplate = mustTemplate(`load("@build_bazel_rules_swift//swift:swift.bzl", _swift_proto_library = "swift_proto_library")

swift_proto_library = _swift_proto_library`)

var swiftGrpcLibraryRuleTemplate = mustTemplate(`load("@build_bazel_rules_swift//swift:swift.bzl", _swift_grpc_library = "swift_grpc_library")

swift_grpc_library = _swift_grpc_library`)

var swiftGrpcLibraryExampleTemplate = mustTemplate(`load("@build_stack_rules_proto//{{ .Lang.Dir }}:{{ .Rule.Name }}.bzl", "{{ .Rule.Name }}")

{{ .Rule.Name }}(
    name = "person_{{ .Lang.Name }}_library",
    flavor = "client",
    deps = ["@build_stack_rules_proto//example/proto:person_proto"],
)`)

func makeSwift() *Language {
	return &Language{
		Dir:  "swift",
		Name: "swift",
		// TravisExclusionReason: "travis incompatible",
		PresubmitEnvVars: map[string]string{
			"CC": "clang",
		},
		Flags: append(commonLangFlags, &Flag{
			Category: "build",
			Name:     "incompatible_require_ctx_in_configure_features",
			Value:    "false",
		}, &Flag{
			Category: "build",
			Name:     "strategy=SwiftCompile",
			Value:    "standalone",
		}),
		Rules: []*Rule{
			&Rule{
				Experimental:   true,
				Name:           "swift_proto_compile",
				Base:           "swift",
				Kind:           "proto",
				Implementation: compileRuleTemplate,
				Plugins:        []string{"//swift:swift"},
				Usage:          swiftUsageTemplate,
				Example:        protoCompileExampleTemplate,
				Doc:            "Generates swift protobuf artifacts",
				Attrs:          append(protoCompileAttrs, []*Attr{}...),
				BazelCIExclusionReason: "experimental",
			},
			&Rule{
				Experimental:   true,
				Name:           "swift_grpc_compile",
				Base:           "swift",
				Kind:           "grpc",
				Implementation: compileRuleTemplate,
				Plugins:        []string{"//swift:grpc_swift"},
				Usage:          swiftUsageTemplate,
				Example:        grpcCompileExampleTemplate,
				Doc:            "Generates swift protobuf+gRPC artifacts",
				Attrs:          append(protoCompileAttrs, []*Attr{}...),
				BazelCIExclusionReason: "experimental",
			},
			&Rule{
				Name:           "swift_proto_library",
				Base:           "swift",
				Kind:           "proto",
				Usage:          swiftUsageTemplate,
				Example:        protoLibraryExampleTemplate,
				Implementation: swiftProtoLibraryRuleTemplate,
				Doc:            "Generates swift protobuf library",
				Attrs:          append(protoCompileAttrs, []*Attr{}...),
				BazelCIExclusionReason: "experimental",
			},
			&Rule{
				Name:           "swift_grpc_library",
				Base:           "swift",
				Kind:           "grpc",
				Implementation: swiftGrpcLibraryRuleTemplate,
				Usage:          swiftUsageTemplate,
				Example:        swiftGrpcLibraryExampleTemplate,
				Doc:            "Generates swift protobuf+gRPC library",
				Attrs:          append(protoCompileAttrs, []*Attr{}...),
				BazelCIExclusionReason: "experimental",
			},
		},
	}
}
