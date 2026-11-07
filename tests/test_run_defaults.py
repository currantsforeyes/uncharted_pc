import importlib.util
import unittest

from paths import ROOT

spec = importlib.util.spec_from_file_location('port_run', ROOT / 'run.py')
port_run = importlib.util.module_from_spec(spec)
spec.loader.exec_module(port_run)


class PerGameDefaultsTests(unittest.TestCase):
    """run.py's per-game GPU read-back choices: what each game needs, and the player's say."""

    def apply(self, exe, **values):
        env = dict(values)
        player = {name: env.get(name) for name in port_run.GAME_ENV}
        port_run.per_game_defaults(env, exe, player)
        return env

    def test_uncharted_2_gets_every_readback(self):
        env = self.apply('big2-ps4_Shipping.elf')

        self.assertEqual(env['BB_GPU_MERGE'], '0')
        self.assertEqual(env['BB_TINY_READBACK'], '1')
        self.assertEqual(env['BB_READBACK_SMALL_BUFFERS'], '1')
        self.assertEqual(env['BB_SCALAR_COPY64_SYNC'], '2')
        self.assertEqual(env['BB_SCALAR_COPY64_DEFER'], '1')

    def test_uncharted_1_gets_only_the_mesh_copies(self):
        env = self.apply('eboot.bin')

        self.assertNotIn('BB_GPU_MERGE', env)          # merging stays on (the fast path)
        self.assertEqual(env['BB_TINY_READBACK'], '0')
        self.assertEqual(env['BB_READBACK_SMALL_BUFFERS'], '0')
        self.assertEqual(env['BB_SCALAR_COPY64_SYNC'], '2')
        self.assertEqual(env['BB_SCALAR_COPY64_DEFER'], '1')
        self.assertNotIn('BB_COPY64_EOP_READBACK', env)

    def test_uncharted_3_gets_the_readbacks_but_not_the_copies(self):
        env = self.apply('big3-ps4_Shipping.elf')

        self.assertEqual(env['BB_TINY_READBACK'], '1')
        self.assertEqual(env['BB_READBACK_SMALL_BUFFERS'], '1')
        self.assertEqual(env['BB_SCALAR_COPY64_SYNC'], '0')   # 94 -> 54 FPS in Cartagena square
        self.assertEqual(env['BB_SCALAR_COPY64_DEFER'], '0')
        self.assertEqual(env['BB_COPY64_EOP_READBACK'], '1')  # characters sinking / floating
        self.assertNotIn('BB_READBACK_SMALL_GATE', env)       # the full fix stays the player's choice

    def test_the_players_own_values_win(self):
        env = self.apply('big2-ps4_Shipping.elf', BB_GPU_MERGE='1', BB_TINY_READBACK='0')

        self.assertEqual(env['BB_GPU_MERGE'], '1')
        self.assertEqual(env['BB_TINY_READBACK'], '0')
        self.assertEqual(env['BB_READBACK_SMALL_BUFFERS'], '1')   # untouched default


if __name__ == '__main__':
    unittest.main()
