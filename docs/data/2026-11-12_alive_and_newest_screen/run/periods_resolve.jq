# Periods, step 2: what the factory's toolchain resolver (factory/lib/eab/toolchain.ex, Eab.Toolchain) would read from each
# candidate's starting commit, and what the factory lacks to run it. A jq port of resolve/3's steps 1, 2, 3 and 5,
# with no project template (no default image, no default database, no service marked as not needed).
# COPY of 2026-11-12_next_ten_screen/run/periods_resolve.jq with one change: the resolver's Redis rule of public commit
# 1a0f888. When a CI file starts Redis or mix.exs depends on a Redis client, the table's Redis line serves it if the
# version CI names matches a line by prefix (or CI names none); otherwise the lack is `db_version:redis/<version>`.
# Input: one candidate record per line: {number, merged_at, start, root: {name: oid}, wf: [{name, oid}], act: [{path, oid}]}
# Arguments: --slurpfile facts (object "kind:oid" -> facts, periods_facts.jq's output), --slurpfile table
#   (factory/config/toolchain_images.json). Output: one TSV row per candidate (columns in the header printed by the caller).
def parts: if type == "string" and test("^[0-9]+(\\.[0-9]+)*$") then split(".") | map(tonumber) else [] end;
def prefix($p; $v): ($p | parts) as $a | ($v | parts) as $b | ($a | length) > 0 and ($b[:($a | length)] == $a);
def engine: ["postgres", "clickhouse"];

$facts[0] as $F | $table[0] as $T
| . as $c
| ( [ {path: ".tool-versions", kind: "tv"}, {path: "mise.toml", kind: "mise"}, {path: ".mise.toml", kind: "mise"} ]
    + ([ $c.wf[] | {path: (".github/workflows/" + .name), kind: "ci", oid: .oid} ] | sort_by(.path))
    + [ {path: ".travis.yml", kind: "ci"}, {path: ".drone.yml", kind: "ci"}, {path: ".gitlab-ci.yml", kind: "ci"}, {path: "Dockerfile", kind: "docker"}, {path: "mix.exs", kind: "mix"} ] ) as $order
| [ $order[]
    | (.oid // $c.root[.path]) as $oid
    | select($oid != null)
    | . + {oid: $oid, f: ($F[.kind + ":" + $oid])}
    | select(.f != null)
    | . + {test: (.kind == "ci" and ((.path | test("^\\.(travis|drone|gitlab-ci)")) or .f.is_test))} ] as $src
| ( [ $c.act[] | {path: .path, f: ($F["action:" + .oid])} | select(.f != null) ] ) as $actions
| def pick($key): [ $src[] | select(.f[$key] != null) ] | first | if . == null then null else {value: .f[$key], source: .path} end;
  # the resolver reads $key as the factory does today; "best" also reads what CI names in an environment variable or a container image
  def best($key): [ $src[] | select((.f[$key + "2"] // .f[$key]) != null) ] | first | if . == null then null else {value: (.f[$key + "2"] // .f[$key]), source: .path} end;
  pick("elixir") as $rel | pick("otp") as $rot | best("elixir") as $el | best("otp") as $ot
| def image($el; $ot):
    if $el == null then {res: "none_named"}
    else
      [ $T.elixir[] | select(prefix($el.value; .elixir) and ($ot == null or prefix($ot.value; .otp))) ]
      | max_by([(.elixir | parts), (.otp | parts)]) as $row
      | if $row == null then {res: "no_image:\($el.value)/\(if $ot == null then "-" else $ot.value end)", old: (($el.value | parts) < [1, 12])}
        else {res: ("ok:" + $row.elixir + "/" + $row.otp)} end
    end;
  image($el; $ot) as $img | image($rel; $rot) as $rimg
| ( if ($img.res | startswith("no_image")) and $el != null
    then ([ $T.elixir[] | select(((.elixir | parts)[:2] == ($el.value | parts)[:2]) and ($ot == null or ((.otp | parts)[:1] == ($ot.value | parts)[:1]))) | .elixir + "/" + .otp ] | join(",") | if . == "" then "-" else . end)
    else "-" end ) as $near
| ( [ $src[] | select(.kind == "ci") | .f.svcs[] ] ) as $found
| ( [ $src[] | select(.kind == "ci" and .test) | .f.svcs[].kind ] | unique ) as $svc_test_all
| ( [ $found[].kind ] | unique ) as $svc_all
| def db($kind):
    ([ $found[] | select(.kind == $kind) ]) as $m
    | ((($m | map(select(.version != null)) | first) // ($m | first))) as $ci
    | if $ci == null then {ci: "-", res: "none"}
      elif $ci.version == null then {ci: "?", res: "no_version"}
      else
        ( if $kind == "postgres" then ($ci.version | split(".") | first) as $maj | ($T.postgres | map(select(.version == $maj)) | first)
          else ($T[$kind] | map(select(prefix($ci.version; .version))) | max_by(.version | parts)) end ) as $row
        | if $row == null then {ci: $ci.version, res: "no_service_image:\($kind)/\($ci.version)"} else {ci: $ci.version, res: "ok:\($row.version)"} end
      end;
  db("postgres") as $pg | db("clickhouse") as $ch
| ( $src | map(select(.kind == "mix")) | first | .f.clients // [] | map(.kind) | unique ) as $mixclients
| ( ($svc_all | index("redis") != null) or ($mixclients | index("redis") != null) ) as $redis
| ( if $redis and (($T.redis // []) | length) > 0 then db("redis") else {ci: "-", res: "none"} end ) as $rd
| ( [ $svc_all[] | select(. as $k | (engine + ["redis"]) | index($k) | not) ] ) as $other_all
| ( [ $svc_test_all[] | select(. as $k | (engine + ["redis"]) | index($k) | not) ] ) as $other_test
| ( ([ $src[] | select(.kind == "ci" and .test) | .f ] + [ $actions[] | .f ]) ) as $cifiles
| ( [ $cifiles[].installs[] ] | unique ) as $inst
| ( [ $inst[] | select(test("\\.deb\\b|dpkg\\s+-i|releases/download|\\.tar\\.(gz|xz)|\\.zip\\b|\\b(curl|wget)\\s.*(\\||\\s-o\\s|\\s-O\\b|>\\s)")) ] | length > 0 ) as $release
| ( [ $inst[] | select(test("(apt-get|apt|apk|brew)\\s+(-\\S+\\s+)*(install|add)\\b")) | sub("^.*?(install|add)\\s+"; "") | [splits("\\s+")][] | select(test("^[a-z0-9][a-z0-9+.-]*$")) ] | unique ) as $pkgs
| ( [ ($cifiles[].setup[] | select(test("setup-(python|go|java|ruby|rust|dotnet|php|zig)|rust-toolchain|actions-rs/")) | if test("python") then "python" elif test("setup-go") then "go" elif test("java") then "java" elif test("ruby") then "ruby" elif test("dotnet") then "dotnet" elif test("php") then "php" elif test("zig") then "zig" else "rust" end),
         ($inst[] | select(test("pip3?\\s+install|pipx\\s+install")) | "python"),
         ($inst[] | select(test("cargo\\s+install")) | "rust"),
         ($inst[] | select(test("gem\\s+install")) | "ruby"),
         (if ($src | map(select(.kind == "mix")) | first | .f.rustler // false) then "rust" else empty end) ] | unique ) as $langs
| ( [ $cifiles[] | select(.compose) ] | length > 0 ) as $compose
| ( [ $src[] | select(.kind == "ci" and .test) | .f.tests[] ] | unique | .[0:2] ) as $tests
| ( [ (if $img.res | startswith("no_image") then (if $img.old then "elixir_older_than_1.12" else "pair_missing:" + ($img.res | sub("^no_image:"; "")) end) else empty end),
      (if $pg.res | startswith("no_service_image") then "db_version:" + ($pg.res | sub("^no_service_image:"; "")) else empty end),
      (if $ch.res | startswith("no_service_image") then "db_version:" + ($ch.res | sub("^no_service_image:"; "")) else empty end),
      (if $rd.res | startswith("no_service_image") then "db_version:" + ($rd.res | sub("^no_service_image:"; "")) else empty end),
      (if $redis and (($T.redis // []) | length) == 0 then "service:redis" else empty end),
      ($other_test[] | "service:" + .),
      (if $release then "release_file" else empty end),
      ($langs[] | "toolchain:" + .) ] ) as $lacks
| def j: if length == 0 then "-" else join(";") end;
  [ $c.number, $c.merged_at, ($c.start // "missing"),
    ($el.value // "-"), ($el.source // "-"), ($ot.value // "-"), ($ot.source // "-"), $img.res,
    $pg.ci, $pg.res, $ch.ci, $ch.res,
    (if $redis then "yes" else "-" end),
    ($other_test | j), (($other_all - $other_test) | j),
    ($pkgs | j), (if $release then "yes" else "-" end), ($langs | j), (if $compose then "yes" else "-" end),
    ($tests | map(gsub("\\t"; " ")) | join(" || ") | if . == "" then "-" else . end),
    (if ($lacks | length) == 0 then "yes" else "no" end), ($lacks | j),
    # what the resolver reads today (columns 23 to 25): its Elixir and OTP, its result, and "yes" when the versions CI names
    # give a pair in the table and the resolver's reading does not give the same one
    (($rel.value // "-") + "/" + ($rot.value // "-")), $rimg.res,
    (if ($img.res | startswith("ok:")) and $rimg.res != $img.res then "yes" else "-" end),
    # column 26: for a pair the table lacks, the table's pairs with the same Elixir minor and OTP major (the nearest pairs)
    $near ] | @tsv
