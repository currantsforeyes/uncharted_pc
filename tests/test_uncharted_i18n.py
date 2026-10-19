import sys
import unittest
from unittest.mock import patch

from paths import ROOT

sys.path.insert(0, str(ROOT / 'launcher'))
import uncharted_i18n


class LauncherTranslationTests(unittest.TestCase):
    def test_each_language_translates_play(self):
        expected = {
            'es': 'Jugar', 'pt': 'Jogar', 'fr': 'Jouer', 'de': 'Spielen',
            'it': 'Gioca', 'ja': 'プレイ',
        }
        for language, translation in expected.items():
            with self.subTest(language=language):
                self.assertEqual(uncharted_i18n.translate(language, 'Play'), translation)

    def test_missing_text_falls_back_to_english(self):
        self.assertEqual(uncharted_i18n.translate('es', 'Untranslated text'), 'Untranslated text')
        self.assertEqual(uncharted_i18n.translate('en', 'Play'), 'Play')

    def test_automatic_language_uses_windows_locale(self):
        for language in ('es', 'pt', 'fr', 'de', 'it', 'ja'):
            with self.subTest(language=language), patch.object(
                    uncharted_i18n.locale, 'getlocale', return_value=(f'{language}_XX', 'UTF-8')):
                self.assertEqual(uncharted_i18n.language_code(''), language)
        with patch.object(uncharted_i18n.locale, 'getlocale', return_value=('ko_KR', 'UTF-8')):
            self.assertEqual(uncharted_i18n.language_code(''), 'en')

    def test_launcher_offers_selected_languages(self):
        self.assertEqual(
            [code for code, _name in uncharted_i18n.LANGUAGES],
            ['', 'en', 'es', 'pt', 'fr', 'de', 'it', 'ja'],
        )

    def test_interface_language_help_is_translated(self):
        text = 'This changes only the launcher. The game language is selected on the Game page.'
        self.assertNotEqual(uncharted_i18n.translate('es', text), text)

    def test_translation_tables_are_well_formed(self):
        # Completeness is not asserted: the launcher gained texts after the languages were added
        # (they fall back to English through translate()), and de/it/ja reuse the shared
        # bbport_lang table, which carries keys the Uncharted launcher does not use. The invariant
        # kept here is that every entry is a non-empty string under a language the launcher offers.
        codes = {code for code, _name in uncharted_i18n.LANGUAGES}
        for language, table in uncharted_i18n.TRANSLATIONS.items():
            with self.subTest(language=language):
                self.assertIn(language, codes)
                self.assertTrue(table)
                for source, translated in table.items():
                    self.assertIsInstance(source, str)
                    self.assertIsInstance(translated, str)
                    self.assertTrue(source)
                    self.assertTrue(translated)


if __name__ == '__main__':
    unittest.main()
