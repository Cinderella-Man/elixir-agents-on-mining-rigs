"""Tests of task_licence.py's licence list (standard library only).

usage: python3 -I factory/tools/test_task_licence.py
"""
import os
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import task_licence  # noqa: E402

ISC_TEXT = """ISC License

Copyright (c) 2026 A Made-up Holder

Permission to use, copy, modify, and/or distribute this software for any
purpose with or without fee is hereby granted, provided that the above
copyright notice and this permission notice appear in all copies.

THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
MERCHANTABILITY AND FITNESS.
"""


class LicenceListTest(unittest.TestCase):
    def test_isc_is_in_the_list_by_its_spdx_id(self):
        self.assertIn("ISC", task_licence.ALLOWED_SPDX)
        self.assertEqual(task_licence.licence_class(["ISC"]), "allowed")
        self.assertEqual(task_licence.licence_class(["MIT", "ISC"]), "allowed")

    def test_isc_loose_spellings_are_allowed_but_not_an_spdx_id(self):
        for name in ["isc", "ISC License", "isc license"]:
            self.assertEqual(task_licence.licence_class([name]), "allowed, not an SPDX id", name)

    def test_licences_outside_the_list_stay_outside(self):
        self.assertEqual(task_licence.licence_class(["GPL-3.0"]), "outside")
        self.assertEqual(task_licence.licence_class(["ISC-like"]), "outside")
        self.assertEqual(task_licence.licence_class(["ISC", "GPL-3.0"]), "several, some outside")
        self.assertEqual(task_licence.licence_class([]), "none declared")

    def test_a_project_whose_root_licence_is_isc_passes_the_root_check(self):
        with tempfile.TemporaryDirectory() as tree:
            with open(os.path.join(tree, "LICENSE"), "w") as f:
                f.write(ISC_TEXT)
            found = task_licence.tree_licence(tree)
        self.assertEqual(found["file"], "LICENSE")
        self.assertEqual(found["families"], ["ISC"])
        self.assertTrue(task_licence.root_allowed(found["families"]))
        self.assertTrue(task_licence.root_allowed(["MIT"]))
        self.assertFalse(task_licence.root_allowed(["ISC", "GPL"]))
        self.assertFalse(task_licence.root_allowed([]))


# a made-up README whose licence section holds the Apache boilerplate notice, indented as a code block
README_APACHE = """# A made-up application

Run it with `mix phx.server`. It uses Phoenix, which is released under the MIT License.

## Development

Nothing here.

## License

    Copyright 2020 A Made-up Holder

    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at

        http://www.apache.org/licenses/LICENSE-2.0

    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS.
"""


def tree_with(files):
    d = tempfile.TemporaryDirectory()
    for name, text in files.items():
        with open(os.path.join(d.name, name), "w") as f:
            f.write(text)
    return d


class ReadmeStatementTest(unittest.TestCase):
    """docs/dataset_rules.md, section 9: a licence stated in the README counts when the root has no licence file."""

    def found(self, files):
        with tree_with(files) as tree:
            return task_licence.tree_licence(tree)

    def test_a_readme_statement_counts_when_the_root_has_no_licence_file(self):
        found = self.found({"README.md": README_APACHE})
        self.assertEqual(found["root"], "ok:readme-statement")
        self.assertEqual(found["source"], "readme-statement")
        self.assertEqual(found["file"], "README.md")
        self.assertEqual(found["families"], ["Apache-2.0"])
        self.assertEqual(found["line"], 13)
        self.assertTrue(found["statement"].startswith("Licensed under the Apache License, Version 2.0"), found)
        self.assertEqual(found["holders"], task_licence.re.escape("A Made-up Holder"))
        self.assertEqual(found["mentions"], 1)  # Phoenix's licence, in the first section
        self.assertEqual(len(found["sha256"]), 64)
        self.assertTrue(task_licence.root_ok(found))
        proof = task_licence.root_proof(found, "c0ffee")
        self.assertTrue(proof.startswith("README.md@c0ffee:13: Licensed under the Apache License"), proof)

    def test_a_plain_sentence_outside_a_licence_section_counts_when_its_subject_is_the_project(self):
        found = self.found({"README.md": "# App\n\nThis project is released under the Apache 2 license.\n"})
        self.assertEqual((found["root"], found["families"], found["line"]), ("ok:readme-statement", ["Apache-2.0"], 3))
        found = self.found({"README": "App\n===\n\nLicence\n-------\n\nMIT, see the notice below.\n"})
        self.assertEqual((found["root"], found["families"], found["file"]), ("ok:readme-statement", ["MIT"], "README"))

    def test_a_readme_that_only_mentions_a_dependencys_licence_does_not_pass(self):
        readme = ("# App\n\n## Dependencies\n\nPhoenix is released under the MIT License.\n\n"
                  "## License\n\nThis project uses Tailwind, which is released under the MIT License.\n\n"
                  "## Third-party licences\n\nThe icons are under the ISC license.\n")
        found = self.found({"README.md": readme})
        self.assertEqual(found["root"], "fail:no-licence")
        self.assertEqual((found["file"], found["families"], found["statement"]), ("", [], ""))
        self.assertEqual(found["mentions"], 3)
        self.assertFalse(task_licence.root_ok(found))

    def test_a_readme_with_no_statement_does_not_pass(self):
        found = self.found({"README.md": "# App\n\nA made-up application.\n\n## License\n\nSee the website.\n"})
        self.assertEqual((found["root"], found["source"], found["mentions"]), ("fail:no-licence", "none", 0))
        found = self.found({"mix.exs": "defmodule App.MixProject do\nend\n"})
        self.assertEqual((found["root"], found["source"], found["file"]), ("fail:no-licence", "none", ""))

    def test_a_licence_file_still_decides_when_the_readme_states_another(self):
        found = self.found({"LICENSE": ISC_TEXT, "README.md": "# App\n\n## License\n\nApache-2.0\n"})
        self.assertEqual((found["root"], found["source"], found["file"], found["families"]),
                         ("ok:licence-file", "licence-file", "LICENSE", ["ISC"]))
        found = self.found({"COPYING": "This program is under the GNU General Public License, version 3.\n",
                            "README.md": "# App\n\n## License\n\nMIT\n"})
        self.assertEqual((found["root"], found["source"], found["families"]),
                         ("fail:licence-file", "licence-file", ["GPL"]))
        self.assertFalse(task_licence.root_ok(found))

    def test_a_readme_naming_a_licence_outside_the_list_or_two_licences_does_not_pass(self):
        for text, root in [("GPL-3.0 or later.", "fail:readme-outside"),
                           ("Released under the BSD license.", "fail:readme-outside"),
                           ("The code is MIT; the documentation is under Creative Commons BY 4.0.",
                            "fail:readme-outside"),
                           ("MIT or Apache-2.0, at your option.", "fail:readme-several"),
                           ("Released under the 3-clause BSD license.", "ok:readme-statement"),
                           ("Released under the 4-clause BSD license.", "fail:readme-outside"),
                           ("Released under the BSD 3-Clause license.", "ok:readme-statement")]:
            found = self.found({"README.md": f"# App\n\n## License\n\n{text}\n"})
            self.assertEqual(found["root"], root, text)

    def test_a_scan_line_written_before_the_readme_rule_keeps_its_result(self):
        self.assertEqual(task_licence.root_code({"file": "LICENSE", "families": ["MIT"]}), "ok:licence-file")
        self.assertEqual(task_licence.root_code({"file": "", "families": []}), "fail:no-licence")
        self.assertEqual(task_licence.root_code({"file": "LICENSE", "families": []}), "fail:licence-file")
        self.assertEqual(task_licence.root_code(None), "not scanned")


if __name__ == "__main__":
    unittest.main()
