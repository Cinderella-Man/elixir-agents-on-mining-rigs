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


if __name__ == "__main__":
    unittest.main()
