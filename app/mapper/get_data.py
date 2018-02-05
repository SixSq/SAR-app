#####  Scrap data urls from 'host_base' xml file and recover file using #####
##### 'python requests' lib. #####
#####  works only with python >= 3.2 #####

import requests
from xml.etree import ElementTree as ET
import sys
import os
import re

# FIXME: use data-access library for parallel download.

host_base = sys.argv[1]  # Object store URL e.g "https://eodata.sos.exo.io/"
prd_name = sys.argv[2]  # Product name extend by ".SAFE" we want to recover


def download_file(url, f_name):
    local_filename = f_name
    r = requests.get(url, stream=True)
    with open(local_filename, 'wb') as f:
        for chunk in r.iter_content(chunk_size=1024):
            if chunk:  # filter out keep-alive new chunks
                f.write(chunk)
    return local_filename


def create_subdir(path):
    file_name = str.split(path, '/')[-1]
    file_path = re.split(file_name, path)[0]
    os.makedirs(file_path, exist_ok=True)


def get_prd_name(f):
    return str.split(f, '/')[0]


response = requests.get(host_base + '?prefix=%s' % prd_name)
if not response.ok:
    raise Exception('Failed to get product %s with %s' %
                    (prd_name, response.reason))
root = ET.fromstring(response.text)
tag_ns = 'http://s3.amazonaws.com/doc/2006-03-01/'
for k in root.findall('.//{%s}Key' % tag_ns):
    if get_prd_name(k.text) == prd_name:
        create_subdir(k.text)
        download_file(host_base + k.text, k.text)
        print("Downloaded: ", host_base + '/' + k.text)
