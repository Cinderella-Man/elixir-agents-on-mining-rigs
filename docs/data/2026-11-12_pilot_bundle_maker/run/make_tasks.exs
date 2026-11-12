# make_tasks.exs: the bundle maker's script entry point, run with `mix run` in the factory folder (make.sh).
#   mix run make_tasks.exs make --repository URL --numbers 1,2 --census TSV --screen TSV --recipe JSON --out DIR
#                               --results TSV --cache DIR [--holdout JSON]
#   mix run make_tasks.exs verify --out DIR [--ids a,b] --results TSV
# P4_DATA, when set, is the engine's data folder (the source archives and the imported candidates).
if dir = System.get_env("P4_DATA"), do: Application.put_env(:eab, :data_dir, dir)
Eab.BundleMaker.main(System.argv())
