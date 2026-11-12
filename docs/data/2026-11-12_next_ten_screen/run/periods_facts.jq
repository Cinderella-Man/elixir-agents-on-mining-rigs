# What one file says about the toolchain. A jq port of the readers in factory/lib/eab/toolchain.ex (Eab.Toolchain), the
# bundle maker's resolver: tool_versions/1, mise/1, ci_versions/1, dockerfile/1, mix_requirement/1, ci_services/1; plus
# what the resolver does not read and this job records: the commands that run the tests, the lines that install
# programs, and the actions that set up other toolchains.
# Input: one object per file, {"kind": "tv|mise|ci|action|docker|mix", "oid": ..., "name": ..., "text": ...}.
# Run with: jq -c --argjson clients '{"redis": ["redix", ...]}' -f periods_facts.jq
# Output: {"oid", "kind", ...facts}.
def trim: gsub("^\\s+|\\s+$"; "");
def lines: split("\n");
# the leading version of a value: "1.16.1-otp-26" gives "1.16.1", "[\"27.3\"" gives "27.3"
def fv: (capture("^\\s*\\[?\\s*['\"]?v?(?<v>[0-9]+(?:\\.[0-9]+)*)") | .v) // null;
def indent_of: length - (sub("^\\s+"; "") | length);
def take_while(p): . as $a | (first(range(0; length) | select($a[.] | p | not)) // length) as $i | $a[:$i];

def tool_versions:
  ([ lines[] | trim | select(length > 0) | [splits("\\s+")] | select(length >= 2 and (.[0] | startswith("#") | not)) | {tool: .[0], value: .[1]} ]) as $l
  | { elixir: (($l | map(select(.tool == "elixir")) | first | .value // "") | fv),
      otp:    (($l | map(select(.tool == "erlang")) | first | .value // "") | fv) };

def mise_get($tool):
  [ lines[] | capture("^\\s*[\"']?" + $tool + "[\"']?\\s*=\\s*(?<rest>.+)$") | .rest | trim | sub("^\\{\\s*version\\s*=\\s*"; "") | fv | select(. != null) ] | first;
def mise: { elixir: mise_get("elixir"), otp: mise_get("erlang") };

def keyver($keys):
  . as $text | lines as $L
  | first( $keys[] as $k | range(0; $L | length) as $n
           | ($L[$n] | capture("^\\s*-?\\s*[\"']?" + $k + "[\"']?\\s*:\\s*(?<rest>.*)$"))
           | .rest | trim
           | (if . == "" then ($L[$n + 1] // "" | capture("^\\s*-\\s*(?<v>.+)$") | .v | fv) else fv end)
           | select(. != null) ) // null;
def ci_versions: { elixir: keyver(["elixir-version", "elixir"]), otp: keyver(["otp-version", "otp", "otp_release", "erlang-version"]) };

def docker_versions:
  lines as $L
  | def arg($names): first($names[] as $nm | $L[] | capture("^\\s*ARG\\s+" + $nm + "=[\"']?(?<v>[0-9]+(?:\\.[0-9]+)*)") | .v) // null;
    (first($L[] | capture("^\\s*FROM\\s+(?:docker\\.io/)?hexpm/elixir:(?<e>[0-9]+(?:\\.[0-9]+)*)-erlang-(?<o>[0-9]+(?:\\.[0-9]+)*)")) // null) as $from
  | (first($L[] | capture("^\\s*FROM\\s+(?:docker\\.io/)?(?:library/)?elixir:(?<e>[0-9]+(?:\\.[0-9]+)*)")) // null) as $plain
  | { elixir: (arg(["ELIXIR_VERSION"]) // ($from | .e?) // ($plain | .e?)),
      otp: (arg(["OTP_VERSION", "ERLANG_VERSION"]) // ($from | .o?)) };

def mix_facts:
  . as $t
  | { elixir: (($t | capture("\\belixir:\\s*\"(?:~>|>=)\\s*(?<v>[0-9]+\\.[0-9]+)") | .v) // null),
      otp: null,
      clients: [ $clients | to_entries[] | .key as $kind | .value[] | select(. as $lib | $t | test("\\{\\s*:" + $lib + "\\s*,")) | {kind: $kind, lib: .} ],
      rustler: ($t | test("\\{\\s*:rustler\\s*,")) };

# What CI names that the resolver does not read (this job's broader reading, used for the real toolchain): an environment variable
# (`ELIXIR_VERSION: '1.13.3'`, `OTP_VERSION=24.2.1`) or a container image (`hexpm/elixir:1.14.4-erlang-25.3.2-...`, `elixir:1.14`).
def env_ver($names): first(lines[] | capture("^\\s*-?\\s*[\"']?(?:" + $names + ")[\"']?\\s*[:=]\\s*[\"']?(?<v>[0-9]+(?:\\.[0-9]+)*)") | .v) // null;
def img_ver: first(lines[] | capture("(?:hexpm\\/)?elixir:(?<e>[0-9]+(?:\\.[0-9]+)*)(?:-erlang-(?<o>[0-9]+(?:\\.[0-9]+)*)|-otp-(?<o2>[0-9]+))?") | {e: .e, o: (.o // .o2)}) // {e: null, o: null};
def ci_best: ci_versions as $r | img_ver as $i
  | { elixir2: ($r.elixir // env_ver("ELIXIR[_-]?VERSION|elixir[_-]?version|elixir_vsn") // $i.e), otp2: ($r.otp // env_ver("OTP[_-]?VERSION|ERLANG[_-]?VERSION|otp[_-]?version|erlang[_-]?version|otp_vsn") // $i.o) };

# the services a CI file starts: a `services:` block (map keys, or list items), and Travis's postgresql addon
def kind_of($n): ($n | split("/") | last | ascii_downcase) as $b
  | if ($b | test("^(postgres|postgresql|postgis)")) then "postgres"
    elif ($b | test("^clickhouse")) then "clickhouse"
    elif ($b | test("^redis")) then "redis"
    else $b end;
def chunks($level): reduce .[] as $l ([]; if ($l | indent_of) == $level or length == 0 then . + [[$l]] else (.[-1] += [$l]) end);
def svc_entry:
  .[0] as $head
  | (first(.[] | capture("^\\s*-?\\s*image:\\s*[\"']?(?<i>[^\\s\"']+)") | .i) // null) as $image
  | (($head | capture("^\\s*(?:-\\s*)?(?:name:\\s*)?[\"']?(?<n>[A-Za-z0-9_./-]+)[\"']?\\s*:?\\s*$") | .n) // null) as $name0
  | (if $name0 == "image" and $image != null then null else $name0 end) as $name
  | if $name == null and $image == null then empty
    else
      (if $image == null then {repo: null, tag: null}
       else ($image | split("@") | first | capture("^(?<repo>.*?)(?::(?<tag>[^:/]+))?$")) end) as $si
      | { kind: kind_of($si.repo // $name), name: ($name // $si.repo), image: $image, version: (if $si.tag == null then null else ($si.tag | fv) end) }
    end;
def services:
  lines as $L
  | ( [ range(0; $L | length) as $n | select($L[$n] | test("^\\s*services:\\s*$")) | $n ] | .[] ) as $n
  | ($L[$n] | indent_of) as $ind
  | ( $L[($n + 1):]
      | take_while( (trim == "") or (trim | startswith("#")) or (indent_of > $ind) or (indent_of == $ind and (sub("^\\s+"; "") | startswith("- "))) )
      | map(select((trim == "" or (trim | startswith("#"))) | not)) ) as $body
  | select($body | length > 0)
  | ($body[0] | indent_of) as $level
  | ($body | chunks($level))[] | svc_entry;
def travis_addons:
  [ lines[] | capture("^\\s*postgresql:\\s*[\"']?(?<v>[0-9]+(?:\\.[0-9]+)*)[\"']?\\s*$") | {kind: "postgres", name: "postgresql", image: null, version: .v} ] | first // empty;

def short: trim | .[0:150];
def run_cmd: sub("^-\\s*"; "") | sub("^(run|name):\\s*"; "") | sub("^\\|\\s*$"; "") | trim;
# the commands that run the tests (an alias such as `mix test.ci` counts), and the lines that install programs
def test_cmds: [ lines[] | select(test("\\bmix\\s+(test|coveralls|ci|check|precommit|[a-z_.:-]*test[a-z_.:-]*)\\b|\\bmake\\s+test\\b|\\bmix\\s+do\\b[^\\n]*\\btest\\b")) | run_cmd | short | select(length > 0) ] | unique;
def install_lines: [ lines[] | select(test("(apt-get|apt|apk|brew)\\s+(-\\S+\\s+)*(install|add)\\b|pip3?\\s+install|pipx\\s+install|npm\\s+(install|i)\\s+(-g|--global)|yarn\\s+global|cargo\\s+install|gem\\s+install|\\b(curl|wget)\\s|dpkg\\s+-i|\\.deb\\b|releases/download|go\\s+install")) | run_cmd | short | select(length > 0) ] | unique;
def setup_actions: [ lines[] | capture("uses:\\s*(?<a>[A-Za-z0-9_./-]+)@") | .a | select(test("setup-(node|python|go|java|ruby|rust|dotnet|php|zig)|rust-toolchain|actions-rs/|supercharge/|shogo82148/|ankane/setup|docker/(setup|build)|docker/compose|docker/login|aws-actions|google-github-actions|hoverkraft|playwright|cypress|browser-actions")) ] | unique;
def compose_use: ([ lines[] | select(test("docker[ -]compose|docker\\s+run\\b")) ] | length) > 0;

. as $f
| ($f.text // "") as $t
| { oid: $f.oid, kind: $f.kind } +
  ( if $f.kind == "tv" then ($t | tool_versions)
    elif $f.kind == "mise" then ($t | mise)
    elif $f.kind == "docker" then ($t | docker_versions)
    elif $f.kind == "mix" then ($t | mix_facts)
    else   # ci or action
      ($t | ci_versions) + ($t | ci_best) + { svcs: ([ ($t | services), ($t | travis_addons) ]), is_test: (($t | test_cmds | length) > 0),
        tests: ($t | test_cmds), installs: ($t | install_lines), setup: ($t | setup_actions), compose: ($t | compose_use),
        version_file: ($t | test("version-file:\\s*\\.tool-versions")) }
    end )
