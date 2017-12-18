#####  Scrap data urls from 'host_base' xml file and recover file using #####
##### 'python requests' lib. #####
#####  works only with python >= 3.2 #####

import requests
from xml.etree import ElementTree
import sys
import string
import os
import re

host_base = sys.argv[1] # Object store URL e.g "https://eodata.sos.exo.io/"
prd_name = sys.argv[2]  # Product name extend by ".SAFE" we want to recover

def download_file(url, f_name):
    #local_filename = string.split(url, '/')[-1]
    local_filename = f_name
    # NOTE the stream=True parameter
    r = requests.get(url, stream=True)
    with open(local_filename, 'wb') as f:
        for chunk in r.iter_content(chunk_size=1024):
            if chunk: # filter out keep-alive new chunks
                f.write(chunk)
                #f.flush() commented by recommendation from J.F.Sebastian
    return local_filename

def create_subdir (path) :
        file_name = str.split(path, '/')[-1]
        file_path = re.split(file_name, path)[0]
        os.makedirs(file_path, exist_ok=True)

def get_prd_name(f):
        return(str.split(f, '/')[0])

response = requests.get(host_base)
tree = ElementTree.fromstring(response.content)

for child in tree :
        if len(child) > 0 and get_prd_name(child[0].text) == prd_name:
                create_subdir(child[0].text)
                download_file(host_base + child[0].text, child[0].text)
                print("File URL:", host_base + '/' + child[0].text)
