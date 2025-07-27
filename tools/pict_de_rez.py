#!/usr/bin/env python3
# -*- coding: utf-8 -*-


import os
import re
import sys

START_RE = r"data\s*'(....)'\s*\(([^)]+)\)\s*{"
DATA_RE = r"\s*\$\"([0-9A-Z\s]+)\""
END_RE = r"\s*};"
  

def derez_pict(f_handle, out_dir):
  file_type = None
  resource_number = None
  resource_name = None
  data = b""
  for line in f_handle:
    match = re.match(START_RE, line) 
    if match:
      file_type, resource_descriptor = match.groups()
      tags = resource_descriptor.split(',')
      tags = tuple(map(lambda s : s.strip(), tags))
      resource_number = tags[0]
      for tag in tags[1:]:
        if tag[0]=='"':
          resource_name = tag.strip('"')
      continue
    match = re.match(DATA_RE, line)
    if match:
      line_data = match.group(1).replace(" ", "")
      data = data + bytes.fromhex(line_data)
      continue
    match = re.match(END_RE, line)
    if match:
      if resource_name:
        out_name = resource_name + '.' + file_type
      else:
        out_name = 'R' + str(resource_number) + '.' + file_type
      if file_type == 'PICT':
        data = b"\x00" * 512 + data
        with open(os.path.join(out_dir, out_name), 'wb') as out_handle:
          out_handle.write(data)
      data = b""
      resource_name = None

def main(argv):
  out_dir = os.getcwd()
  for f_name in argv:
    with open(f_name, encoding='MAC-ROMAN') as f_handle:
      derez_pict(f_handle, out_dir)



if __name__ == "__main__":
    main(sys.argv[1:])
