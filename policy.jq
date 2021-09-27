# This is a jq program to handle TPM 2.0 EA policies.
#
# Currently a WORK IN PROGRESS.
#
# Status:
#
#  - policy merging is working
#
#  - policy traversal to generate execution traces is working
#
#  - TBD: implement all the commands
#
#  - TBD: how to represent ancillary non-policy commands needed to execute a
#    policy, such as importing and/or loading external keys referenced by the
#    policy commands (e.g., signer keys for TPM2_PolicyAuthorize(), objects
#    referenced by TPM2_PolicySecret(), etc.)
#
#    One option is to refer to them explicitly among policy commands.  This may
#    not be a great option as it complicates validation of a policy's form.
#
# - TBD: how to represent parameter bindings values -- probably as textual
#   inputs to tpm2-tools commands rather than as base64 encodings of TPM2
#   values
#
# Goals:
#
#  - Implement a jq program with various subcommands that ultimately allows for
#    the representation of complex parametrized TPM 2.0 EA policies and the
#    execution of those policies in trial and/or authorization sessions.
#
#    The jq program itself would execute no TPM commands -- instead a trace of
#    commands to execute would be output and executed by a bash script (or
#    whatever).
#
#    Desired sub-commands:
#
#    list-policy-references   -- List URIs of policies that need to be
#                                fetched by the caller.
#
#                                Useful for fetching policies as needed at
#                                run-time, then merging into a single working
#                                policy.
#
#                                For example, a policy referred to by
#                                TPM2_PolicyAuthorize() might have to be
#                                downloaded at run-time because... that's that
#                                command's point, that the policy is to be
#                                determined at run-time.
#
#    merge-policies  -- merge N given policies into one
#
#    trace-policy-trial -- given a policy, emit a trace of commands to execute
#                          in order to evaluate the policy in trial sessions
#
#    trace-policy-exec  -- given a policy and a path through the PolicyOr AST,
#                          emit a trace of commands to execute in order to
#                          evaluate the policy (including evaluation in trial
#                          sessions of PolicyOr alternatives not-taken)
#
#
# Some useful observations about TPM 2.0 EA policies
#
#  - there are "holes", namely: TPM2_PolicyOr(), TPM2_PolicyAuthorizeNV(), and
#    TPM2_PolicyAuthorize()
#
#  - any sequence of TPM2_Policy*() commands is a conjunction, except for
#    TPM2_PolicyOr() which... is special
#
#  - TPM2_PolicyOr() defines an alternation of policies (up to 8)
#
#  - the way holes work is that one must first execute the referred-to policy's
#    policy commands, then the hole command itself as it will replace rather
#    than extend the session's policyDigest, then any subsequent policy
#    commands
#
#  - if we view the policies referred to by holes as separate from the policy
#    containing the hole, we can treat the former are children of the latter to
#    form an AST
#
#  - we can construct an AST where the nodes are holes and the policy commands
#    that follow them:
#
#    Interior nodes start with a hole and contain no other holes:
#
#                          PolicyOr, followed by non-hole commands
#                           /     \
#                          /       \
#                         /         \
#                        /           \
#                       /             \
#              <sub-policy #0>   <sub-policy #1>
#                   ...             ...
#
#    with each sub-policy being a sequence of policy commands the first one of
#    which may be a hole.
#
#    Leaf sub-policies have no holes, else they must have one or more child
#    nodes.
#
#  - only PolicyOr has multiple alternatives -- the other holes have just one
#
#  - to trace the execution of a policy one must traverse the AST in
#    port-order, executing leaves first so that their parent nodes can know the
#    policyDigest of each child
#
# Here a policy is a JSON object with the following keys:
#
#   params, bindings, policies, policyDef
#
# Params define parameters that may be referenced by commands in the policy.
#
# Bindings are values for those parameters.  A policy may be fragmentary and
# include only parameters, and it may include default bindings for some or all
# of those parameters.
#
# Bindings of parameters are essentially command parameters for the commands
# that make up the policy, or for ancillary non-policy commands that import/
# load/create/loadexternal objects needed by the policy.
#
# A policy may refer to other policies by name.  The `policies` key's value
# should be an object whose keys are policy names and whose values are objects
# with a uri key and an optional digest key.
#
# A policyDef is a recursive data structure, and if its value is a string then
# it names a policy to substitute in.  A policyDef may be either an object with
# another policyDef key, or an array of policy commands.
#
# A policy command is an object with a command key and various not-yet-
# developed keys for command input arguments.


# Some useful utilities
def debug($x): ($x|debug|empty),.;
def cond(c; t): if c then t else . end;
def cond(c; t; f): if c then t else f end;
def cond(c0; t0; c1; t1; f): cond(c0; t0; cond(c1; t1; f));
def cond(c0; t0; c1; t1; c2; t2; f): cond(c0; t0; c1; t1; cond(c2; t2; f));
def typecase(T; t; f): cond(type==T; t; f);
def typecase(T; t): typecase(T; t; empty);
def typecase(T0; t0; T1; t1; f): typecase(T0; t0; typecase(T1; t1; f));
def typecase(T0; t0; T1; t1): typecase(T0; t0; T1; t1; empty);
def typecase(T0; t0; T1; t1; T2; t2; f): typecase(T0; t0; T1; t1; typecase(T2; t2; f));
def typecase(T0; t0; T1; t1; T2; t2): typecase(T0; t0; T1; t1; T2; t2; empty);
def check(c; e): cond(c; .; e|error);

# Check that the input array (or string) is a prefix of a given one ($of)
def isPrefix($of):
    (length) as $inlen
  | ($inlen <= ($of | length)) and (.==$of[0:$inlen]);

# Convert an array of objects into an object where the keys in the object at
# the values of the `.[$i]|k` for each $i'th element of the array
def a2o(k):
    typecase("array"; reduce .[] as $v ({}; .[$v|k] = $v);
             "object"; .;
             "null"; {};
             "Expected array or object; got \(type)"|error);

# Merge a set of (e.g., "params").  Duplicates not allowed.
def merge_unique(a; k; e):
    a2o(k)
  | reduce (a|a2o(k)) as $o (.;
      reduce ($o|keys_unsorted[]) as $k (.;
          cond(has($k) and ($o|has($k)); $k|e|error)
        | .[$k] //= $o[$k]
      )
    );
def merge_unique(a; k): merge_unique(a; k; "Key \(.) is not unique");

# Merge a set of (e.g., "bindings").  Duplicates are allowed -- first value
# wins.
def merge(a; k):
    a2o(k)
  | reduce (a|a2o(k)) as $o (.;
      reduce ($o|keys_unsorted[]) as $k (.; .[$k] //= $o[$k])
    );

# Some policy checking functions.  We want to check that AST nodes are
# sequences where at most the first command may be a "hole" command.

# A policy hole is a TPM 2.0 policy command that replaces rather than extends
# the session's policyDigest
def holes: "PolicyOr", "PolicyAuthorize", "PolicyAuthorizeNV";

# Check if a command is a hole
def isHole: . as $command | any(holes; .==$command);

# Check that a policy AST node contains no holes after the first command
def checkPolicyHole:
    typecase("array";
             cond(any(.[1:][]; isHole); "Holes must come first"|error);
             .);

# This function merges the given policies, using the policy name given as input
# (`.`) as the name of the main policy.
def mergePolicies(policies):
    # Internal utility to resolve references to policies (O(N))
    def fix_refs:
        reduce path(..[]?|.policyDef?|select(type=="string")) as $path (.;
            (getpath($path)) as $reference
          | .policyDefs[$reference] as $target
          # debug("Resolving reference to \($reference) at \($path) to \($target)")
          | cond($target == null; "Missing policy \($reference)"|error)
          | setpath($path; $target.policyDef)
        )
    ;

    # Save the name of the main policy
    . as $main_policy

    # Skeleton of merged policy
  | {params:{},bindings:{},policyDefs:{}}

    # First the policies' params (these must be unique)
  | reduce policies as $p (.;
        (.params |= merge_unique($p.params; .name))
    )

    # First the policies' bindings (need not be unique; first setting wins;
    # this allows for policy fragments to provide default bindings that can be
    # overridden by the policies that include them)
  | reduce policies as $p (.;
        (.bindings |= merge($p.bindings; .name))
    )

    # TODO: Check that there are no unbound parameters.
    #       Check that there are no unreferenced parameters.
    #       Implement a way to reference parameter bindings from policy
    #       commands.

    # Index policies by name as prep for the policy reference resolution step
  | reduce policies as $p (.;
        (.policyDefs |=
            merge_unique([{name:$p.name,policyDef:$p.policyDef}];
                         .name;
                         "Policy name \(.) is not unique"))
    )

    # Resolve policy references
  | fix_refs

    # The main policy, with policy references resolved, _is_ the merged policy
  | .policyDef = .policyDefs[$main_policy]

    # Delete the temporary index of policies
    # (XXX should just have used a local jq $binding for the index)
  | del(.policyDefs)
  ;

# Post-order traversal of policies for generating execution traces.
#
# The callback `trace` does the tracing of commands.
#
# Ultimately, when executing a policy to get access to some TPM object(s) and
# TPM command(s), the user/caller must specify a path through alternations (if
# there are any) to execute.  The `trace` callback gets the metadata needed to
# do exactly this.
#
# `trace` gets an object as input with a `path` key and a `policy` key
# containing a command to execute (XXX rename to `command` then).
#
# The path is the path of TPM2_PolicyOr() alternations taken through the
# policy's AST to get to the TPM command it's given.  This means the `trace`
# callback can emit a trace of commands where each is associated with a policy
# or trial session according to whether we're executing the whole policy in a
# trial session or according to the desired path through the PolicyOr AST.
#
# I.e., the caller must provide a `trace` expression that can discriminate
# based on the path taken to get to each traced command, and this can be used
# to add TPM2_StartAuthSession() commands -or select a policy session instead
# of a trial session- as needed.
#
# See examples below.
def postTraversePolicyDef(trace):
    def policyAuthorizeNV: [.,{command:"policyAuthorizeNV"}];
    def policyAuthorize: [.,{command:"policyAuthorize"}];
    def policyOr: [.,{command:"PolicyOr"}];
    def traverse($path):
        # XXX This is because sometimes we end up having policyDef as an
        #     object, and sometimes as an array.
        # FIXME Make it consistent.
        def getPolicyDef:
            typecase("object";
                     cond(has("command"); .;
                          has("policyDef"); .policyDef;
                          "Object doesn't resemble a policyDef");
                     "array"; cond(length>0; .;
                                   "Zero-length policyDef!"|error);
                     "Expected policy as array or object"|error);

        getPolicyDef      # See above
      | checkPolicyHole   # Check that at most the first command is a "hole"
      | typecase("object"; .;
                 "array"; .[];
                 "Not a policy fragment \(.)"|error)
      | check((.command|type)=="string"; "Not a policy fragment \(.)")
      | if .command == "PolicyOr"
        then
            [
                range(length) as $i
              | .policyDef[$i]
              | [traverse($path + [$i])]
            ]
          | policyOr
        elif .command == "PolicyAuthorize"
        then
            [
                .policyDef
              | traverse($path)
            ]
          | policyAuthorize
        elif .command == "PolicyAuthorizeNV"
        then
            [
                .policyDef
              | traverse($path)
            ]
          | policyAuthorizeNV
        # XXX "And" is a crutch; remove.
        elif .command == "And"
        then [.policyDef|traverse($path)]
        else 
            # XXX Implement all the comamnds here.  Check their arguments and
            #     use bindings to supply values for any parameter references.
            .
        end
      | {path:$path,policy:.}
      | trace
    ;

    traverse([])
;

# Output some test toy policies
def testPolicies:
  { name:"first",
    bindings:[
      { name:"attest_signer",
        type:"PK",
        encoding:"PEM",
        value:"foo"
      },
      { name:"policy_authority_signer",
        type:"PK",
        encoding:"PEM",
        value:"bar"
      }
    ],
    params:[],
    policyDef:[{command:"PolicySigned",x:2}]},
  { name:"second",
    bindings:[],
    params:[
      { name:"attest_signer",
        type:"PK",
        encoding:"PEM"
      }
    ],
    policyDef:[{command:"PolicySecret",x:1},{command:"PolicyPCR",y:2}]},
  { name:"third",
    bindings:[],
    params:[
      { name:"policy_authority_signer",
        type:"PK",
        encoding:"PEM"
      }
    ],
    policyDef:[{command:"PolicySecret",x:2},{command:"PolicyPCR",y:3}]},
  { name:"main",
    bindings:[],
    params:[],
    policyDef:[
        { command:"PolicyOr",
          policyDef:[
              { command:"And",
                policyDef:"first" },
              { command:"PolicyOr",
                policyDef:[
                    { command:"And",
                      policyDef:"second"
                    },
                    { command:"And",
                      policyDef:"third"
                    }
                ]
              }
          ]
        }
    ]
  };


  # Merge the test policies
  # XXX This is just a demo.  A main program is needed that implements the
  #     sub-commands mentioned above.
  # TODO: Implement a main program that implements the desired sub-commands for
  #       listing missing policies to fetch, for merging policies, and for
  #       tracing execution of policies.
  # TODO: Implement a shell script around this program that actually executes
  #       policy command traces produced by this program.
  "main"
| mergePolicies(testPolicies)
| (
    # Show the merged policy
    (
        debug("Merged policy")
      | .
    ),

    # Show post-order traversal trace of the merged policy
    (
        debug("Post-traversal of policy")
      | .policyDef
      | postTraversePolicyDef(.)
    ),

    # Show post-order traversal of the merged policy using only one path
    # through the PolicyOr tree
    (
        debug("Post-traversal of policy using path [0]")
      | .policyDef
      | postTraversePolicyDef(cond(.path|debug|isPrefix([0]); .; debug("Pruning path \(.path) as it's not a prefix of [0]")|empty))
    ),

    # Show post-order traversal of the merged policy using only another path
    # through the PolicyOr tree
    (
        debug("Post-traversal of policy using path [1,0]")
      | .policyDef
      | postTraversePolicyDef(cond(.path|isPrefix([1,0]); .; debug("Pruning path \(.path) as it's not a prefix of [1,0]")|empty))
    ),

    # Show post-order traversal of the merged policy using only yet another
    # path through the PolicyOr tree
    (
        debug("Post-traversal of policy using path [1,1]")
      | .policyDef
      | postTraversePolicyDef(cond(.path|isPrefix([1,1]); .; debug("Pruning path \(.path) as it's not a prefix of [1,1]")|empty))
    )
  )
