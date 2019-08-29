load("//:plugin.bzl", "ProtoPluginInfo")
load("//:compile.bzl", "ProtoCompileInfo")
load(
    "//:compile.bzl",
    # "ProtoCompileInfo",
    # "get_plugin_out_arg",
    # "get_plugin_outputs",
    "objc_upper_segments",
    "rust_keywords",
)

def proto_compile_impl(ctx):
    files = []

    for dep in ctx.attr.deps:
        aspect = dep[ProtoLibraryAspectNodeInfo]
        files += aspect.outputs

    return [ProtoCompileInfo(
        label = ctx.label,
        outputs = files,
        files = files,
    ), DefaultInfo(files = depset(files))]

proto_compile_attrs = {
    # "plugins": attr.label_list(
    #     doc = "List of protoc plugins to apply",
    #     providers = [ProtoPluginInfo],
    #     mandatory = True,
    # ),
    "plugin_options": attr.string_list(
        doc = "List of additional 'global' options to add (applies to all plugins)",
    ),
    "plugin_options_string": attr.string(
        doc = "(internal) List of additional 'global' options to add (applies to all plugins)",
    ),
    "outputs": attr.output_list(
        doc = "Escape mechanism to explicitly declare files that will be generated",
    ),
    "has_services": attr.bool(
        doc = "If the proto files(s) have a service rpc, generate grpc outputs",
    ),
    # "protoc": attr.label(
    #     doc = "The protoc tool",
    #     default = "@com_google_protobuf//:protoc",
    #     cfg = "host",
    #     executable = True,
    # ),
    "verbose": attr.int(
        doc = "Increase verbose level for more debugging",
    ),
    "verbose_string": attr.string(
        doc = "Increase verbose level for more debugging",
    ),
    # "include_imports": attr.bool(
    #     doc = "Pass the --include_imports argument to the protoc_plugin",
    #     default = True,
    # ),
    # "include_source_info": attr.bool(
    #     doc = "Pass the --include_source_info argument to the protoc_plugin",
    #     default = True,
    # ),
    "transitive": attr.bool(
        doc = "Emit transitive artifacts",
    ),
    "transitivity": attr.string_dict(
        doc = "Transitive rules.  When the 'transitive' property is enabled, this string_dict can be used to exclude protos from the compilation list",
    ),
}

proto_compile_aspect_attrs = {
    "verbose_string": attr.string(
        doc = "Increase verbose level for more debugging",
        values = ["", "None", "0", "1", "2", "3", "4"],
    ),
    # "plugin_options": attr.string_list(
    #     doc = "List of additional 'global' options to add (applies to all plugins)",
    # ),
    # "outputs": attr.output_list(
    #     doc = "Escape mechanism to explicitly declare files that will be generated",
    # ),
    # "transitive": attr.bool(
    #     doc = "Emit transitive artifacts",
    # ),
    # "transitivity": attr.string_dict(
    #     doc = "Transitive rules.  When the 'transitive' property is enabled, this string_dict can be used to exclude protos from the compilation list",
    # ),
}

ProtoLibraryAspectNodeInfo = provider(
    fields = {
        "outputs": "the files generated by this aspect",
    },
)

def describe(name, obj, exclude):
    """Print the properties of the given struct obj
    Args:
      name: the name of the struct we are introspecting.
      obj: the struct to introspect
      exclude: a list of names *not* to print (function names)
    """
    for k in dir(obj):
        if hasattr(obj, k) and k not in exclude:
            v = getattr(obj, k)
            t = type(v)
            print("%s.%s<%r> = %s" % (name, k, t, v))

def get_bool_attr(attr, name):
    value = getattr(attr, name, "False")
    return value == "True"

def get_int_attr(attr, name):
    value = getattr(attr, name)
    if value == "":
        return 0
    if value == "None":
        return 0
    return int(value)

def get_string_list_attr(attr, name):
    value = getattr(attr, name, "")
    if value == "":
        return []
    return value.split(";")

def proto_compile_aspect_impl(target, ctx):
    # node - the proto_library rule node we're visiting
    node = ctx.rule

    # Confirm the node is a proto_library otherwise return no providers.
    if node.kind != "proto_library":
        return []

    ###
    ### Part 1: setup variables used in scope
    ###

    # <int> verbose level
    # verbose = ctx.attr.verbose
    verbose = get_int_attr(ctx.attr, "verbose_string")  # DIFFERENT

    # <File> the protoc tool
    # protoc = ctx.executable.protoc
    protoc = node.executable._proto_compiler  # DIFFERENT

    # <File> for the output descriptor.  Often used as the sibling in
    # 'declare_file' actions.
    # descriptor = ctx.outputs.descriptor
    descriptor = target.files.to_list()[0]  # DIFFERENT

    # <string> The directory where that generated descriptor is.
    outdir = descriptor.dirname  # SAME

    # <list<ProtoInfo>> A list of ProtoInfo
    # deps = [dep.proto for dep in ctx.attr.deps]
    deps = [dep[ProtoInfo] for dep in node.attr.deps]  # DIFFERENT

    # <list<PluginInfo>> A list of PluginInfo
    plugins = [plugin[ProtoPluginInfo] for plugin in ctx.attr._plugins]  # ~~SAME~~ SLIGHTLY DIFFERENT

    # <list<File>> The list of .proto files that will exist in the 'staging
    # area'.  We copy them from their source location into place such that a
    # single '-I.' at the package root will satisfy all import paths.
    # protos = []
    protos = node.files.srcs  # DIFFERENT

    # <dict<string,File>> The set of .proto files to compile, used as the final
    # list of arguments to protoc.  This is a subset of the 'protos' list that
    # are directly specified in the proto_library deps, but excluding other
    # transitive .protos.  For example, even though we might transitively depend
    # on 'google/protobuf/any.proto', we don't necessarily want to actually
    # generate artifacts for it when compiling 'foo.proto'. Maintained as a dict
    # for set semantics.  The key is the value from File.path.
    targets = {}  # NEW - ONLY IN compile.bzl

    # <dict<string,File>> A mapping from plugin name to the plugin tool. Used to
    # generate the --plugin=protoc-gen-KEY=VALUE args
    plugin_tools = {}  # SAME DECL

    # <dict<string,<File> A mapping from PluginInfo.name to File.  In the case
    # of plugins that specify a single output 'archive' (like java), we gather
    # them in this dict.  It is used to generate args like
    # '--java_out=libjava.jar'.
    plugin_outfiles = {}  # SAME

    # <list<File>> The list of srcjars that we're generating (like
    # 'foo.srcjar').
    srcjars = []

    # <list<File>> The list of generated artifacts like 'foo_pb2.py' that we
    # expect to be produced.
    outputs = []

    # Additional data files from plugin.data needed by plugin tools that are not
    # single binaries.
    data = []

    ###
    ### Part 2: gather plugin.out artifacts
    ###

    # Some protoc plugins generate a set of output files (like python) while
    # others generate a single 'archive' file that contains the individual
    # outputs (like java).  This first loop is for the latter type.  In this
    # scenario, the PluginInfo.out attribute will exist; the predicted file
    # output location is relative to the package root, marked by the descriptor
    # file. Jar outputs are gathered as a special case as we need to
    # post-process them to have a 'srcjar' extension (java_library rules don't
    # accept source jars with a 'jar' extension)

    # SAME
    for plugin in plugins:
        if plugin.executable:
            plugin_tools[plugin.name] = plugin.executable
        data += plugin.data + get_plugin_runfiles(plugin.tool)

        filename = _get_plugin_out(ctx, plugin)
        if not filename:
            continue
        out = ctx.actions.declare_file(filename, sibling = descriptor)
        outputs.append(out)
        plugin_outfiles[plugin.name] = out
        if out.path.endswith(".jar"):
            srcjar = _copy_jar_to_srcjar(ctx, out)
            srcjars.append(srcjar)

    #
    # Parts 3a and 3b are skipped in the aspect impl
    #

    ###
    ### Part 3c: collect generated artifacts for all in the target list of protos to compile
    ###
    # for proto in protos:
    #     for plugin in plugins:
    #         outputs = get_plugin_outputs(ctx, descriptor, outputs, proto, plugin)
    # DIFFERENT (similar but this uses targets.items)
    # for src, proto in targets.items():
    #     for plugin in plugins:
    #         outputs = get_plugin_outputs(ctx, descriptor, outputs, src, proto, plugin)
    for proto in protos:
        for plugin in plugins:
            outputs = _get_plugin_outputs(ctx, descriptor, outputs, proto, plugin)

    #
    # This is present only in the aspect impl.
    #
    descriptor_sets = depset(
        direct = target.files.to_list(),
        transitive = [d.transitive_descriptor_sets for d in deps],
    )

    #
    # Only present in the aspect impl.
    #

    import_files = depset(
        direct = protos,
        transitive = [d.transitive_imports for d in deps],
    )

    # By default we have a single 'proto_path' argument at the 'staging area'
    # root.
    # list<string> argument list to construct
    args = []

    # This is commented out in the aspect impl but present in compile.bzl
    # args = ["--descriptor_set_out=%s" % descriptor.path]

    #
    # This part about using the descriptor set in is only present in the aspect
    # impl.
    #
    pathsep = ctx.configuration.host_path_separator
    args.append("--descriptor_set_in=%s" % pathsep.join(
        [f.path for f in descriptor_sets.to_list()],
    ))

    #
    # plugin_options only present in aspect impl
    #
    plugin_options = get_string_list_attr(ctx.attr, "plugin_options_string")

    # for plugin in plugins:
    #     args += [get_plugin_out_arg(ctx, outdir, plugin, plugin_outfiles)]

    # DIFFERENT: aspect impl also passes in the plugin_options argument
    for plugin in plugins:
        args += [get_plugin_out_arg(ctx, outdir, plugin, plugin_outfiles, plugin_options)]

    args += ["--plugin=protoc-gen-%s=%s" % (k, v.path) for k, v in plugin_tools.items()]  # SAME

    args += [_proto_path(f) for f in protos]

    mnemonic = "ProtoCompile"  # SAME

    command = " ".join([protoc.path] + args)  # SAME

    inputs = import_files.to_list() + descriptor_sets.to_list() + data
    tools = [protoc] + plugin_tools.values()

    # SAME
    if verbose > 0:
        print("%s: %s" % (mnemonic, command))
    if verbose > 1:
        command += " && echo '\n##### SANDBOX AFTER RUNNING PROTOC' && find . -type f "
    if verbose > 2:
        command = "echo '\n##### SANDBOX BEFORE RUNNING PROTOC' && find . -type l && " + command
    if verbose > 3:
        command = "env && " + command
        for f in outputs:
            print("EXPECTED OUTPUT:", f.path)
        print("INPUTS:", inputs)
        print("TOOLS:", tools)
        print("COMMAND:", command)
        for arg in args:
            print("ARG:", arg)

    ctx.actions.run_shell(
        mnemonic = mnemonic,  # SAME
        command = command,  # SAME

        # This is different!
        inputs = inputs,
        tools = tools,

        # outputs = outputs + [descriptor] + ctx.outputs.outputs, # compile.bzl
        outputs = outputs,
    )

    #
    # Gather transitive outputs
    #
    deps = [dep[ProtoLibraryAspectNodeInfo] for dep in node.attr.deps]
    for dep in deps:
        outputs += dep.outputs

    info = ProtoLibraryAspectNodeInfo(
        outputs = outputs,
    )

    return struct(
        proto_compile = info,
        providers = [info],
    )

def get_plugin_out_arg(ctx, outdir, plugin, plugin_outfiles, plugin_options):
    """Build the --java_out argument
    Args:
      ctx: the <ctx> object
      output: the package output directory <string>
      plugin: the <PluginInfo> object.
      plugin_outfiles: The <dict<string,<File>>.  For example, {closure: "library.js"}
    Returns
      <string> for the protoc arg list.
    """
    label_name = ctx.label.name
    arg = "%s/%s" % (ctx.bin_dir.path, ctx.label.workspace_root)

    # Works for rust but not python!
    # if ctx.label.package:
    #     arg += "/" + ctx.label.package

    # Graveyard of failed attempts (above)....
    # arg = "%s/%s" % (ctx.bin_dir.path, ctx.label.package)
    # arg = ctx.bin_dir.path
    # arg = ctx.label.workspace_root
    # arg = ctx.build_file_path
    # arg = "."

    if plugin.outdir:
        arg = plugin.outdir.replace("{name}", outdir)
    elif plugin.out:
        outfile = plugin_outfiles[plugin.name]

        #arg = "%s" % (outdir)
        #arg = "%s/%s" % (outdir, outfile.short_path)
        arg = outfile.path

    # Collate a list of options from the plugin itself PLUS options from the
    # global plugin_options list (if they exist)
    options = getattr(plugin, "options", []) + plugin_options
    if options:
        arg = "%s:%s" % (",".join(_get_plugin_options(label_name, options)), arg)
    return "--%s_out=%s" % (plugin.name, arg)

# Shamelessly taken from https://github.com/bazelbuild/rules_go
def _proto_path(proto):
    """
    The proto path is not really a file path
    It's the path to the proto that was seen when the descriptor file was generated.
    """
    path = proto.path
    root = proto.root.path
    ws = proto.owner.workspace_root
    if path.startswith(root):
        path = path[len(root):]
    if path.startswith("/"):
        path = path[1:]
    if path.startswith(ws):
        path = path[len(ws):]
    if path.startswith("/"):
        path = path[1:]
    return path

def _get_plugin_outputs(ctx, descriptor, outputs, proto, plugin):
    """Get the predicted generated outputs for a given plugin

    Args:
      ctx: the <ctx> object
      descriptor: the descriptor <Generated File>
      outputs: the list of outputs.
      proto: the source .proto <Source File>
      plugin: the <PluginInfo> object.
    Returns:
      <list<Generated File>> the augmented list of files that will be generated
    """
    for output in plugin.outputs:
        filename = _get_output_filename(proto, plugin, output)
        if not filename:
            continue

        # sibling = _get_output_sibling_file(output, proto, descriptor)
        sibling = proto

        output = ctx.actions.declare_file(filename, sibling = sibling)

        # print("Using sibling file '%s' for '%s' => '%s'" % (sibling.path, filename, output.path))
        outputs.append(output)
    return outputs

def _capitalize(s):
    """Capitalize a string - only first letter
    Args:
      s (string): The input string to be capitalized.
    Returns:
      (string): The capitalized string.
    """
    return s[0:1].upper() + s[1:]

def _pascal_objc(s):
    """Convert pascal_case -> PascalCase

    Objective C uses pascal case, but there are e exceptions that it uppercases
    the entire segment: url, http, and https.

    https://github.com/protocolbuffers/protobuf/blob/54176b26a9be6c9903b375596b778f51f5947921/src/google/protobuf/compiler/objectivec/objectivec_helpers.cc#L91

    Args:
      s (string): The input string to be capitalized.
    Returns: (string): The capitalized string.
    """
    segments = []
    for segment in s.split("_"):
        repl = objc_upper_segments.get(segment)
        if repl:
            segment = repl
        else:
            segment = _capitalize(segment)
        segments.append(segment)
    return "".join(segments)

def _pascal_case(s):
    """Convert pascal_case -> PascalCase
    Args:
        s (string): The input string to be capitalized.
    Returns:
        (string): The capitalized string.
    """
    return "".join([_capitalize(part) for part in s.split("_")])

def _rust_keyword(s):
    """Check if arg is a rust keyword and append '_pb' if true.
    Args:
        s (string): The input string to be capitalized.
    Returns:
        (string): The appended string.
    """
    return s + "_pb" if rust_keywords.get(s) else s

def _get_output_sibling_file(pattern, proto, descriptor):
    """Get the correct place to output to.

    The ctx.actions.declare_file has a 'sibling = <File>' feature that allows
    one to declare files in the same directory as the sibling.

    This function checks for the prefix special token '{package}' and, if true,
    uses the descriptor as the sibling (which declares the output file will be
    in the root of the generated tree).

    Args:
      pattern: the input filename pattern <string>
      proto: the .proto <Generated File> (in the staging area)
      descriptor: the descriptor <File> that marks the staging root.

    Returns:
      the <File> to be used as the correct sibling.
    """

    if pattern.startswith("{package}/"):
        return descriptor
    return proto

def _get_plugin_out(label_name, plugin):
    if not plugin.out:
        return None
    filename = plugin.out
    filename = filename.replace("{name}", label_name)
    return filename

def _get_output_filename(src, plugin, pattern):
    """Build the predicted filename for file generated by the given plugin.  

    A 'proto_plugin' rule allows one to define the predicted outputs.  For
    flexibility, we allow special tokens in the output filename that get
    replaced here. The overall pattern is '{token}' mimicking the python
    'format' feature.

    Additionally, there are '|' characters like '{basename|pascal}' that can be
    read as 'take the basename and pipe that through the pascal function'.

    Args:
      src: the .proto <File>
      plugin: the <PluginInfo> object.
      pattern: the input pattern string

    Returns:
      the replaced string
    """

    # If output to srcjar, don't emit a per-proto output file.
    if plugin.out:
        return None

    # Slice off this prefix if it exists, we don't use it here.
    if pattern.startswith("{package}/"):
        pattern = pattern[len("{package}/"):]
    basename = src.basename
    if basename.endswith(".proto"):
        basename = basename[:-6]
    elif basename.endswith(".protodevel"):
        basename = basename[:-11]

    filename = basename

    if pattern.find("{basename}") != -1:
        filename = pattern.replace("{basename}", basename)
    elif pattern.find("{basename|pascal}") != -1:
        filename = pattern.replace("{basename|pascal}", _pascal_case(basename))
    elif pattern.find("{basename|pascal|objc}") != -1:
        filename = pattern.replace("{basename|pascal|objc}", _pascal_objc(basename))
    elif pattern.find("{basename|rust_keyword}") != -1:
        filename = pattern.replace("{basename|rust_keyword}", _rust_keyword(basename))
    else:
        filename = basename + pattern
    
    return filename

def _get_proto_filename(src):
    """Assemble the filename for a proto

    Args:
      src: the .proto <File>

    Returns:
      <string> of the filename.
    """
    parts = src.short_path.split("/")
    if len(parts) > 1 and parts[0] == "..":
        return "/".join(parts[2:])
    return src.short_path

def _copy_jar_to_srcjar(ctx, jar):
    """Copy .jar to .srcjar

    Args:
      ctx: the <ctx> object
      jar: the <Generated File> of a jar containing source files.

    Returns:
      <Generated File> for the renamed file
    """
    srcjar = ctx.actions.declare_file("%s/%s.srcjar" % (ctx.label.name, ctx.label.name))
    ctx.actions.run_shell(
        mnemonic = "CopySrcjar",
        inputs = [jar],
        outputs = [srcjar],
        command = "mv %s %s" % (jar.path, srcjar.path),
    )
    return srcjar

def _get_plugin_option(label_name, option):
    """Build a plugin option, doing plugin option template replacements if present

    Args:
      label_name: the ctx.label.name
      option: string from the <PluginInfo>

    Returns:
      <string> for the --plugin_out= arg
    """

    # TODO: use .format here and pass in a substitutions struct!
    return option.replace("{name}", label_name)

def _get_plugin_options(label_name, options):
    """Build a plugin option list

    Args:
      label_name: the ctx.label.name
      options: list<string> options from the <PluginInfo>

    Returns:
      <string> for the --plugin_out= arg
    """
    return [_get_plugin_option(label_name, option) for option in options]

def _apply_plugin_transitivity_rules(ctx, targets, plugin):
    """Process the proto target list according to plugin transitivity rules

    Args:
      ctx: the <ctx> object
      targets: the dict<string,File> of .proto files that we intend to compile.
      plugin: the <PluginInfo> object.

    Returns:
      <list<File>> the possibly filtered list of .proto <File>s
    """

    # Iterate transitivity rules like '{ "google/protobuf": "exclude" }'. The
    # only rule type implemented is "exclude", which checks if the pathname or
    # dirname ends with the given pattern.  If so, remove that item in the
    # targets list.
    #
    # Why does this feature exist?  Well, library rules like C# require all the
    # proto files to be present during the compilation (collected via transitive
    # sources).  However, since the well-known types are already present in the
    # library dependencies, we don't actually want to compile well-known types
    # (but do want to compile everything else).
    #
    transitivity = plugin.transitivity + ctx.attr.transitivity

    for pattern, rule in transitivity.items():
        if rule == "exclude":
            for key, target in targets.items():
                if ctx.attr.verbose > 2:
                    print("Checking '%s' endswith '%s'" % (target.short_path, pattern))
                if target.dirname.endswith(pattern) or target.path.endswith(pattern):
                    targets.pop(key)
                    if ctx.attr.verbose > 2:
                        print("Removing '%s' from the list of files to compile as plugin '%s' excluded it" % (target.short_path, plugin.name))
                elif ctx.attr.verbose > 2:
                    print("Keeping '%s' (not excluded)" % (target.short_path))
        elif rule == "include":
            for key, target in targets.items():
                if target.dirname.endswith(pattern) or target.path.endswith(pattern):
                    if ctx.attr.verbose > 2:
                        print("Keeping '%s' (explicitly included)" % (target.short_path))
                else:
                    targets.pop(key)
                    if ctx.attr.verbose > 2:
                        print("Removing '%s' from the list of files to compile as plugin '%s' did not include it" % (target.short_path, plugin.name))
        else:
            fail("Unknown transitivity rule '%s'" % rule)
    return targets

# def get_plugin_outputs(ctx, descriptor, outputs, proto, plugin):
#     """Get the predicted generated outputs for a given plugin

#     Args:
#       ctx: the <ctx> object
#       descriptor: the descriptor <Generated File>
#       outputs: the list of outputs.
#       proto: the source .proto <Source File>
#       plugin: the <PluginInfo> object.

#     Returns:
#       <list<Generated File>> the augmented list of files that will be generated
#     """
#     for output in plugin.outputs:
#         filename = _get_output_filename(proto, plugin, output)
#         if not filename:
#             continue
#         # sibling = _get_output_sibling_file(output, proto, descriptor)
#         # sibling = proto
#         # print("FILENAME: %s" % filename)
#         # output = ctx.actions.declare_file(filename, sibling = sibling)
#         output = ctx.actions.declare_file(filename)
#         # output = ctx.new_file(filename, root = descriptor)

#         # print("Using sibling file '%s' for '%s' => '%s'" % (sibling.path, filename, output.path))
#         outputs.append(output)
#     return outputs

def get_plugin_runfiles(tool):
    """Gather runfiles for a plugin.
    """
    files = []
    if not tool:
        return files

    info = tool[DefaultInfo]
    if not info:
        return files

    if info.files:
        files += info.files.to_list()

    if info.default_runfiles:
        runfiles = info.default_runfiles
        if runfiles.files:
            files += runfiles.files.to_list()

    if info.data_runfiles:
        runfiles = info.data_runfiles
        if runfiles.files:
            files += runfiles.files.to_list()

    return files
