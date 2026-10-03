import unittest
from q2a import cjson


class Canonical(unittest.TestCase):
    def test_order_and_ascii(self):
        self.assertEqual(cjson.canonical({'z': 1, 'a': 'é'}), b'{"a":"\\u00e9","z":1}')
        self.assertEqual(cjson.digest({'a': 1, 'b': 2}), cjson.digest({'b': 2, 'a': 1}))

    def test_forbidden_types(self):
        for value in [1.0, float('nan'), 2**53, {1: 'x'}, (1, 2), {'nested': [0.1]}]:
            with self.subTest(value=value), self.assertRaises(ValueError):
                cjson.canonical(value)
