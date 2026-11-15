#!/usr/bin/python3
"""Offline checks for PDF code references and Vim regular-expression matching."""

from pathlib import Path
import runpy
import tempfile
import unittest


repo = Path(__file__).resolve().parents[1]
inverse = runpy.run_path(str(repo / "scripts/tex-inverse-search"))
regexp = runpy.run_path(str(repo / "scripts/zathura-regex-search"))


class CodeReferenceTests(unittest.TestCase):
    def test_literal_target_is_relative_to_original_source(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            marker = root / "report.coderef-1.tex"
            origin = root / "docs/report.tex"
            marker.write_text(
                "% coderef-generated-v1\n"
                + rf"\codereftarget{{{origin}}}{{../code file's.m}}{{2}}{{4}}%"
                + "\n"
            )
            request = inverse["code_reference"](marker, 3, 1)
            self.assertEqual(request, {
                "file": str(root / "code file's.m"), "line": 2, "end": 4, "code": 1,
            })

    def test_ordinary_source_keeps_normal_inverse_search(self):
        with tempfile.TemporaryDirectory() as folder:
            source = Path(folder) / "report.tex"
            source.write_text(r"\coderef{example.m}{1}{2}{Example}")
            self.assertIsNone(inverse["code_reference"](source, 1, 1))

    def test_invalid_line_ranges_are_rejected(self):
        with tempfile.TemporaryDirectory() as folder:
            marker = Path(folder) / "marker.tex"
            for first, last in [("0", "2"), ("4", "2"), ("1+1", "3")]:
                with self.subTest(first=first, last=last):
                    marker.write_text("% coderef-generated-v1\n"
                                      + rf"\codereftarget{{/docs/report.tex}}{{file.m}}{{{first}}}{{{last}}}" + "\n")
                    with self.assertRaises(ValueError):
                        inverse["code_reference"](marker, 2, 1)


class RegexpTests(unittest.TestCase):
    def test_whole_words_use_unicode_character_offsets(self):
        pages = ["BP ABP BPs BP_1 αBP GB BP", "bp BP\nGB"]
        with tempfile.TemporaryDirectory() as folder:
            matches = regexp["vim_matches"](r"\<\(BP\|GB\)\>", pages, folder)
        texts = [[text[start:end] for start, end in spans]
                 for text, spans in zip(pages, matches)]
        self.assertEqual(texts, [["BP", "GB", "BP"], ["BP", "GB"]])

    def test_invalid_expression_is_reported(self):
        with tempfile.TemporaryDirectory() as folder:
            with self.assertRaises(ValueError):
                regexp["vim_matches"](r"\(", ["BP"], folder)

    def test_expression_cannot_execute_ex_commands(self):
        with tempfile.TemporaryDirectory() as folder:
            sentinel = Path(folder) / "should-not-exist"
            pattern = rf"\V|call writefile(['unexpected'], '{sentinel}')"
            self.assertEqual(regexp["vim_matches"](pattern, ["BP"], folder), [[]])
            self.assertFalse(sentinel.exists())


if __name__ == "__main__":
    unittest.main()
