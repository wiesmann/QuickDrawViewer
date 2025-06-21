#!/usr/bin/env python
# -*- coding: utf-8 -*-

# Simple tool to extract PICT files in derezed resources.

import os
import re
import sys

START_RE = r"(....)\s*'(....)'\s*\((\d+)\s*([^)]*)\)\s*{"
DATA_RE = r"\s*\$\"([0-9A-Z\s]+)\""
END_RE = r"\s*};"
NAME_RE = r'\"([^\"]+)\"'

def derez_pict(f_handle, out_dir):
  """Extract all the PICT resources in `f_handle` into files writen into `out_dir`"""
  file_type = None
  resource_number = None
  file_name = None
  data = b""
  for line in f_handle:
    match = re.match(START_RE, line) 
    if match:
      rsrc_type, data_type, resource_number, rest = match.groups()
      # If we wind a resource name, use this for the file-name.
      name_match = re.search(NAME_RE, rest)
      if name_match:
        file_name = name_match.group(1)
      else:
        # Fallback to resource number
        file_name = str(resource_number)
      continue
    match = re.match(DATA_RE, line)
    if match:
      line_data = match.group(1).replace(" ", "")
      data = data + bytes.fromhex(line_data)
      continue
    match = re.match(END_RE, line)
    if match:
      out_name = file_name + "." + data_type
      if data_type == 'PICT':
        data = b"\x00" * 512 + data
        with open(os.path.join(out_dir, out_name), 'wb') as out_handle:
          out_handle.write(data)
      data = b""


def main(argv):
  out_dir = os.getcwd()
  for f_name in argv:
    with open(f_name, encoding='MAC-ROMAN') as f_handle:
      derez_pict(f_handle, out_dir)


if __name__ == "__main__":
    main(sys.argv[1:])
