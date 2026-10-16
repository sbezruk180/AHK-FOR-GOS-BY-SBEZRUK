"""Small read-only PE32 resource inspector, independent of Windows and packages."""
import struct

class PE:
    def __init__(self, data):
        self.data = data
        if data[:2] != b'MZ':
            raise ValueError('Not a Windows executable')
        pe = struct.unpack_from('<I', data, 0x3c)[0]
        if data[pe:pe+4] != b'PE\0\0':
            raise ValueError('Invalid PE signature')
        self.machine, count = struct.unpack_from('<HH', data, pe+4)
        optional_size = struct.unpack_from('<H', data, pe+20)[0]
        opt = pe+24
        self.magic = struct.unpack_from('<H', data, opt)[0]
        self.subsystem = struct.unpack_from('<H', data, opt+68)[0]
        directory = opt + (96 if self.magic == 0x10b else 112)
        resource_rva = struct.unpack_from('<I', data, directory+16)[0]
        self.sections = []
        for i in range(count):
            section = opt+optional_size+i*40
            size, rva, raw_size, offset = struct.unpack_from('<IIII', data, section+8)
            self.sections.append((rva, max(size, raw_size), offset))
        self.resource_base = self.offset(resource_rva)
        self.resources = {}
        self._walk(0, ())

    def offset(self, rva):
        for start, size, offset in self.sections:
            if start <= rva < start+size:
                return offset+rva-start
        raise ValueError(f'RVA outside PE sections: {rva:x}')

    def _walk(self, relative, path):
        data, base = self.data, self.resource_base
        named, ids = struct.unpack_from('<HH', data, base+relative+12)
        for i in range(named+ids):
            name, value = struct.unpack_from('<II', data, base+relative+16+i*8)
            if name & 0x80000000:
                pos = base+(name & 0x7fffffff)
                length = struct.unpack_from('<H', data, pos)[0]
                name = data[pos+2:pos+2+length*2].decode('utf-16le')
            current = path+(name,)
            if value & 0x80000000:
                self._walk(value & 0x7fffffff, current)
            else:
                rva, size = struct.unpack_from('<II', data, base+value)
                pos = self.offset(rva)
                self.resources[current] = data[pos:pos+size]

    def resource(self, name, type_id=10):
        matches = [v for k, v in self.resources.items() if k[0] == type_id and k[1] == name]
        if len(matches) != 1:
            raise ValueError(f'Expected one resource {name!r}; got {len(matches)}')
        return matches[0]
