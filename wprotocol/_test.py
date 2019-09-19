import unittest

from wprotocol_specs import *

class TestPonyEncodeMethods(unittest.TestCase):
    def setUp(self):
        self.spec = PonySpec()

    def test_U32(self):
        self.assertEqual(self.spec.encode('param', 'U32'), FOUR_SPACES + 'wb.u32_be(param)\n')

    def test_U64(self):
        self.assertEqual(self.spec.encode('param', 'U64'), FOUR_SPACES + 'wb.u64_be(param)\n')

    def test_I32(self):
        self.assertEqual(self.spec.encode('param', 'I32'), FOUR_SPACES + 'wb.i32_be(param)\n')

    def test_I64(self):
        self.assertEqual(self.spec.encode('param', 'I64'), FOUR_SPACES + 'wb.i64_be(param)\n')

    def test_F32(self):
        self.assertEqual(self.spec.encode('param', 'F32'), FOUR_SPACES + 'wb.f32_be(param)\n')

    def test_F64(self):
        self.assertEqual(self.spec.encode('param', 'F64'), FOUR_SPACES + 'wb.f64_be(param)\n')

    def test_bool(self):
        self.assertEqual(self.spec.encode('param', 'Bool'), FOUR_SPACES + '(if param then wb.u8(1) else wb.u8(0) end)\n')

    def test_string(self):
        self.assertEqual(self.spec.encode('param', 'String'),
"""    next_size = param.size()
    wb.u32_be(next_size.u32())
    wb.write(param)
""")

    def test_array_U64(self):
        self.assertEqual(self.spec.encode('param', 'Array[U64]'),
"""    next_size = param.size()
    wb.u32_be(next_size.u32())
    for i in param.values() do
      wb.u64_be(i)
    end
""")

    def test_array_array_U64(self):
        self.assertEqual(self.spec.encode('param', 'Array[Array[U64]]'),
"""    next_size = param.size()
    wb.u32_be(next_size.u32())
    for i in param.values() do
      next_size = i.size()
      wb.u32_be(next_size.u32())
      for xi in i.values() do
        wb.u64_be(xi)
      end
    end
""")

    def test_user_defined_type(self):
        msgs = {'UType': {'name': 'UType', 'fields': [('name', 'String', None), ('age', 'U64', None)]}}
        self.spec.add_message_specs(msgs)
        self.assertEqual(self.spec.encode('param', 'UType'),
"""    next_size = param.name.size()
    wb.u32_be(next_size.u32())
    wb.write(param.name)
    wb.u64_be(param.age)
""")

class TestPonyDecodeMethods(unittest.TestCase):
    def setUp(self):
        self.spec = PonySpec()
        self.maxDiff = None

    def test_U32(self):
        self.assertEqual(self.spec.decode('param', 'U32'), FOUR_SPACES + 'let param = rb.u32_be()?\n')

    def test_U64(self):
        self.assertEqual(self.spec.decode('param', 'U64'), FOUR_SPACES + 'let param = rb.u64_be()?\n')

    def test_I32(self):
        self.assertEqual(self.spec.decode('param', 'I32'), FOUR_SPACES + 'let param = rb.i32_be()?\n')

    def test_I64(self):
        self.assertEqual(self.spec.decode('param', 'I64'), FOUR_SPACES + 'let param = rb.i64_be()?\n')

    def test_F32(self):
        self.assertEqual(self.spec.decode('param', 'F32'), FOUR_SPACES + 'let param = rb.f32_be()?\n')

    def test_F64(self):
        self.assertEqual(self.spec.decode('param', 'F64'), FOUR_SPACES + 'let param = rb.f64_be()?\n')

    def test_bool(self):
        self.assertEqual(self.spec.decode('param', 'Bool'), FOUR_SPACES + 'let param = (if rb.u8()? == 1 then true else false end)\n')

    def test_string(self):
        self.assertEqual(self.spec.decode('param', 'String'),
"""    next_size = rb.u32_be()?.usize()
    let param = String.from_array(rb.block(next_size)?)
""")

    def test_array_U64(self):
        self.assertEqual(self.spec.decode('param', 'Array[U64]'),
"""    let param_iso = recover iso Array[U64] end
    let param_size: USize = rb.u32_be()?.usize()
    for _ in Range(0, param_size) do
      let xparam = rb.u64_be()?
      param_iso.push(xparam)
    end
    let param = consume val param_iso
""")

    def test_array_array_U64(self):
        self.assertEqual(self.spec.decode('param', 'Array[Array[U64]]'),
"""    let param_iso = recover iso Array[Array[U64] val] end
    let param_size: USize = rb.u32_be()?.usize()
    for _ in Range(0, param_size) do
      let xparam_iso = recover iso Array[U64] end
      let xparam_size: USize = rb.u32_be()?.usize()
      for _ in Range(0, xparam_size) do
        let xxparam = rb.u64_be()?
        xparam_iso.push(xxparam)
      end
      let xparam = consume val xparam_iso
      param_iso.push(xparam)
    end
    let param = consume val param_iso
""")

    def test_user_defined_type(self):
        msgs = {'UType': {'name': 'UType', 'fields': [('name', 'String', None), ('age', 'U64', None)]}}
        self.spec.add_message_specs(msgs)
        self.assertEqual(self.spec.decode('param', 'UType'),
"""    next_size = rb.u32_be()?.usize()
    let param_name = String.from_array(rb.block(next_size)?)
    let param_age = rb.u64_be()?
    let param = UType(param_name, param_age)
""")


class TestStringMethods(unittest.TestCase):
    def setUp(self):
        self.spec = PonySpec()
        self.maxDiff = None

    def test_U32(self):
        self.assertEqual(self.spec.tostring('param', 'U32'), 'param.string()')

    def test_U64(self):
        self.assertEqual(self.spec.tostring('param', 'U64'), 'param.string()')

    def test_I32(self):
        self.assertEqual(self.spec.tostring('param', 'I32'), 'param.string()')

    def test_I64(self):
        self.assertEqual(self.spec.tostring('param', 'I64'), 'param.string()')

    def test_F32(self):
        self.assertEqual(self.spec.tostring('param', 'F32'), 'param.string()')

    def test_F64(self):
        self.assertEqual(self.spec.tostring('param', 'F64'), 'param.string()')

    def test_bool(self):
        self.assertEqual(self.spec.tostring('param', 'Bool'), 'param.string()')

    def test_string(self):
        self.assertEqual(self.spec.tostring('param', 'String'), 'param')

    def test_array_U64(self):
        self.assertEqual(self.spec.tostring('param', 'Array[U64]'),
            '(var param_str = "[";for i in param.values() do param_str = param_str + i.string() end;param_str = param_str + "]"; param_str)')

    # def test_array_array_U64(self):
    #     self.assertEqual(self.spec.tostring('param', 'Array[Array[U64]]'),
    #         '(let param_str = '';for i in param.values() do param_str = param_str + i.string() end; param_str)')

class TestHashMethods(unittest.TestCase):
    def setUp(self):
        self.spec = PonySpec()
        self.maxDiff = None

    def test_U32(self):
        self.assertEqual(self.spec.hash('param', 'U32'), 'param.hash()')

    def test_U64(self):
        self.assertEqual(self.spec.hash('param', 'U64'), 'param.hash()')

    def test_I32(self):
        self.assertEqual(self.spec.hash('param', 'I32'), 'param.hash()')

    def test_I64(self):
        self.assertEqual(self.spec.hash('param', 'I64'), 'param.hash()')

    def test_F32(self):
        self.assertEqual(self.spec.hash('param', 'F32'), 'param.hash()')

    def test_F64(self):
        self.assertEqual(self.spec.hash('param', 'F64'), 'param.hash()')

    def test_bool(self):
        self.assertEqual(self.spec.hash('param', 'Bool'), 'param.string().hash()')

    def test_string(self):
        self.assertEqual(self.spec.hash('param', 'String'), 'param.hash()')

    # def test_array_U64(self):
    #     self.assertEqual(self.spec.hash('param', 'Array[U64]'),
    #         '(var param_hash = USize(0);for i in param.values() do param_hash = param_hash xor i.hash() end; param_hash)')

    # def test_array_array_U64(self):
    #     self.assertEqual(self.spec.hash('param', 'Array[Array[U64]]'),
    #         '(let param_str = '';for i in param.values() do param_str = param_str + i.string() end; param_str)')

class TestEqMethods(unittest.TestCase):
    def setUp(self):
        self.spec = PonySpec()
        self.maxDiff = None

    def test_U32(self):
        self.assertEqual(self.spec.eq('param', 'U32'), '(param == that.param)')

    def test_U64(self):
        self.assertEqual(self.spec.eq('param', 'U64'), '(param == that.param)')

    def test_I32(self):
        self.assertEqual(self.spec.eq('param', 'I32'), '(param == that.param)')

    def test_I64(self):
        self.assertEqual(self.spec.eq('param', 'I64'), '(param == that.param)')

    def test_F32(self):
        self.assertEqual(self.spec.eq('param', 'F32'), '(param == that.param)')

    def test_F64(self):
        self.assertEqual(self.spec.eq('param', 'F64'), '(param == that.param)')

    def test_bool(self):
        self.assertEqual(self.spec.eq('param', 'Bool'), '(param == that.param)')

    def test_string(self):
        self.assertEqual(self.spec.eq('param', 'String'), '(param == that.param)')

    # def test_array_U64(self):
    #     self.assertEqual(self.spec.eq('param', 'Array[U64]'),
    #         '(var param_eq = true;if param.size() != that.param.size() then param_eq = false end;' + \
    #         'for i in Range(0, param.size()) do try if param(i)? != that.param(i)? then param_eq = false' + \
    #         ' end else param_eq = false end;param_eq)')

    # def test_array_array_U64(self):
    #     self.assertEqual(self.spec.eq('param', 'Array[Array[U64]]'),
    #         '(let param_str = '';for i in param.values() do param_str = param_str + i.string() end; param_str)')



if __name__ == '__main__':
    unittest.main()
