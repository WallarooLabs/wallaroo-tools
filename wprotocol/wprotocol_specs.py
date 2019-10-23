import re

FOUR_SPACES = '    '

primitives = ['F32','F64','I16','I32','I64','U16','U32','U64','I32','I64','Bool']

specs = {
	'F64': ['f64_be'],
	'F32': ['f32_be'],
	'U16': ['u16_be'],
	'U32': ['u32_be'],
	'U64': ['u64_be'],
	'I16': ['i16_be'],
	'I32': ['i32_be'],
	'I64': ['i64_be'],
	'Bool': ['u8'],
	'String': ['size', 'write']
}

type_sizes = {
	"F64": 8,
	"F32": 4,
	"U16": 2,
	"U32": 4,
	"U64": 8,
	"U16": 2,
	"I32": 4,
	"I64": 8,
	"Bool": 1
}

lang_types = {
	"F64": "F64",
	"F32": "F32",
	"U16": "U16",
	"U32": "U32",
	"U64": "U64",
	"I16": "I16",
	"I32": "I32",
	"I64": "I64",
	"Bool": "Bool",
	"String": "String"
}

arrayp = re.compile(r'^Array\[([A-Z_]+[A-Za-z0-9\[\]]*)\]$')

def type_is_array(t):
	return bool(re.match(arrayp, t))


class PonySpec(object):
	def __init__(self):
		self.message_specs = {}

	def add_message_specs(self, specs):
		self.message_specs.update(specs)

	def pony_type_for(self, t):
		array_res = re.match(arrayp, t)
		if t in lang_types:
			return lang_types[t]
		elif bool(array_res):
			return 'Array[' + self.pony_type_for(array_res.group(1)) + '] val'
		elif t in self.message_specs:
			return t + ' val'
		else:
			raise Exception(t + ' is an undefined type!')

	def get_tcode(self, t):
		array_res = re.match(arrayp, t)
		if t in primitives or t == 'String':
			return (t, t)
		elif bool(array_res):
			return ('Array', array_res.group(1))
		elif t in self.message_specs:
			return (t, 'user-defined')
		else:
			raise Exception(t + ' is an invalid type!')

	def encode(self, fname, t, spaces=FOUR_SPACES, varname='i'):
		enc = ''
		tcode = self.get_tcode(t)
		if t == 'Bool':
			enc += spaces + '(if ' + fname + ' then wb.u8(1) else wb.u8(0) end)\n'
		elif t in primitives or t == 'String':
			for spec in specs[t]:
				if spec == 'size':
					enc += self._encode_size(fname, t, spaces)
				elif spec == 'write':
					enc += spaces + 'wb.write(' + fname + ')\n'
				else:
					enc += spaces + 'wb.' + spec + '(' + fname + ')\n'
		elif tcode[0] == 'Array':
			enc += self._encode_size(fname, t, spaces)
			# varname = 'x' + fname
			next_varname = 'x' + varname
			enc += spaces + 'for ' + varname + ' in ' + fname + '.values() do\n'
			enc += self.encode(varname, tcode[1], spaces + (' ' * 2), next_varname)
			enc += spaces + 'end\n'
		if tcode[1] == 'user-defined':
			for (fname2, t2, _) in self.message_specs[tcode[0]]['fields']:
				enc += self.encode(fname + '.' + fname2, t2, spaces)
		return enc

	def _encode_size(self, fname, t, spaces):
		es = ''
		es += spaces + 'next_size = ' + fname + '.size()\n'
		es += spaces + 'wb.u32_be(next_size.u32())\n'
		return es

	def decode(self, fname, t, spaces=FOUR_SPACES):
		dec = ''
		tcode = self.get_tcode(t)
		if t == 'Bool':
			dec += spaces + 'let ' + fname + ' = (if rb.u8()? == 1 then true else false end)\n'
		elif t in primitives or t == 'String':
			for spec in specs[t]:
				if spec == 'size':
					dec += spaces + 'next_size = rb.u32_be()?.usize()\n'
				elif spec == 'write':
					dec += spaces + 'let ' + fname + ' = String.from_array(rb.block(next_size)?)\n'
				else:
					dec += spaces + 'let ' + fname + ' = rb.' + spec + '()?\n'
		elif tcode[0] == 'Array':
			dec += spaces + 'let ' + fname + '_iso = recover iso ' + str(self.pony_type_for(t)[:-4]) + ' end\n'
			dec += spaces + 'let ' + fname + '_size: USize = ' + 'rb.u32_be()?.usize()\n'
			varname = 'x' + fname
			dec += spaces + 'for _ in Range(0, ' + fname + '_size) do\n'
			dec += self.decode(varname, tcode[1], spaces + (' ' * 2))
			dec += spaces + '  ' + fname + '_iso.push(' + varname + ')\n'
			dec += spaces + 'end\n'
			dec += spaces + 'let ' + fname + ' = consume val ' + fname + '_iso\n'
		if tcode[1] == 'user-defined':
			fields = self.message_specs[tcode[0]]['fields']
			for (fname2, t2, _) in fields:
				dec += self.decode(fname + '_' + fname2, t2, spaces)
			decoded_field_args = ', '.join(map(lambda pair: fname + '_' + pair[0], fields))
			dec += spaces + 'let ' + fname + ' = ' + tcode[0] + '(' + decoded_field_args + ')\n'
		return dec

	def tostring(self, fname, t, varname='i'):
		strng = ''
		tcode = self.get_tcode(t)
		if t in primitives:
			strng += fname + '.string()'
		elif t == 'String':
			strng += fname
		elif tcode[0] == 'Array':
			str_var = fname + '_str'
			strng += '(var ' + str_var + ' = "[";'
			strng += 'for ' + varname + ' in ' + fname + '.values() do '
			next_varname = 'x' + varname
			strng += str_var + ' = ' + str_var + ' + ' + self.tostring(varname, tcode[1], next_varname)
			strng += ' end;' + str_var + ' = ' + str_var + ' + "]"; ' + str_var + ')'
		if tcode[1] == 'user-defined':
			strng += fname + '.string()'
		return strng

	def hash(self, fname, t):
		strng = ''
		tcode = self.get_tcode(t)
		if t == 'Bool':
			strng += fname + '.string().hash()'
		elif t in primitives or t == 'String':
			strng += fname + '.hash()'
		elif tcode[0] == 'Array':
			# TEMPORARY HACK
			strng += 'USize(0)'
			# hash_var = fname + '_hash'
			# strng += '(var ' + hash_var + ' = USize(0);'
			# strng += 'for i in ' + fname + '.values() do '
			# strng += hash_var + ' = ' + hash_var + ' xor i.hash() end; ' + hash_var + ')'
		if tcode[1] == 'user-defined':
			strng += fname + '.hash()'
		return strng

	def eq(self, fname, t):
		strng = ''
		tcode = self.get_tcode(t)
		if t in primitives or t == 'String':
			strng += '(' + fname + ' == that.' + fname + ')'
		elif tcode[0] == 'Array':
			# TEMPORARY HACK
			strng += 'true'
			# eq_var = fname + '_eq'
			# strng += '(var ' + eq_var + ' = true;'
			# strng += 'if ' + fname + '.size() != that.' + fname + '.size() then '+ eq_var + ' = false end;'
			# strng += 'for i in Range(0, ' + fname + '.size()) do try '
			# strng += 'if ' + fname + '(i)? != that.' + fname + '(i)?' + ' then ' + eq_var + ' = false end'
			# strng += ' else ' + eq_var + ' = false end end;' + eq_var + ')'
		if tcode[1] == 'user-defined':
			strng += '(' + fname + ' == that.' + fname + ')'
		return strng

	def size(self, fname, t, varname='i'):
		strng = ''
		tcode = self.get_tcode(t)
		if t in primitives:
			strng += str(type_sizes[t])
		elif t == 'String':
			strng += '4 + ' + fname + '.size()'
		elif tcode[0] == 'Array':
			size_of_item_count = '4'
			size_var = self.varname_from_dotted(fname) + '_size'
			strng += '(var ' + size_var + ': USize = ' + size_of_item_count + ';for ' + varname + ' in '
			strng += fname + '.values() do '
			next_varname = 'x' + varname
			strng += size_var + ' = ' + size_var + ' + ' + self.size(varname, tcode[1], next_varname) + ' end;' + size_var + ')'
		elif tcode[1] == 'user-defined':
			sizes = []
			for (fname2, t2, _) in self.message_specs[tcode[0]]['fields']:
				if fname == '':
					prefix = ''
				else:
					prefix = fname + '.'
				sizes.append(self.size(prefix + fname2, t2))
			strng += " + ".join(sizes)
		return strng

	def varname_from_dotted(self, dotted):
		return dotted.replace('.', '_')
