#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import argparse
import sys
import json
import yaml

VERSION = '0.1'

DESCRIBE = '''Create the Ansible inventory from the terraform output'''


def reassembled_output(data):
    reassembled = {}
    # a list of different resource type/family is expected.
    # Each family needs a dedicated care
    for family in ['bastion', 'cluster_nodes', 'drbd', 'iscsisrv', 'monitoring', 'netweaver']:
        x_family = {}
        # Loop through the terraform output and look for data about this  family
        for key, value in data.items():
            if family not in key:
                continue
            # remove the family name from the sub-key
            # iscsisrv_public_ip  -->  public_ip
            data_key = key.replace(f"{family}_", '')
            if isinstance(value['value'], (str, list)) and len(value['value']) == 0 or \
                    not any(len(element) for element in value['value']):
                data_value = None
            elif family == 'cluster_nodes':
                if any(len(element) for element in value['value'][0]):
                    data_value = value['value'][0]
                else:
                    data_value = None
            else:
                data_value = value['value']
            x_family[data_key] = data_value
        for mandatory_key in ['ip', 'name', 'public_ip', 'public_name']:
            if mandatory_key not in x_family:
                x_family[mandatory_key] = None
        reassembled[family] = x_family
    return reassembled


class Inventory():

    def __init__(self):
        '''
        all:
          hosts:
          children:
            hana:
              hosts:
                vmhana01:
                  ansible_host: 40.68.73.171
                  ansible_python_interpreter: /usr/bin/python3
                vmhana02:
                  ansible_host: 40.68.73.244
                  ansible_python_interpreter: /usr/bin/python3
            iscsi:
              hosts:
                vmiscsi01:
                  ansible_host: 40.68.73.102
                  ansible_python_interpreter: /usr/bin/python3
        '''
        inv = {}
        inv['all'] = {}
        inv['all']['hosts'] = None
        inv['all']['children'] = {}
        inv['all']['children']['hana'] = {}
        inv['all']['children']['iscsi'] = {}
        inv['all']['children']['hana']['hosts'] = {}
        inv['all']['children']['iscsi']['hosts'] = {}
        self.inv = inv

    def __str__(self):
        return yaml.dump(self.inv, Dumper=yaml.SafeDumper)

    def write(self, file):
        return yaml.dump(self.inv, file, Dumper=yaml.SafeDumper)

    def add_data(self, data, from_key, to_key):
        for idx, value in enumerate(data[from_key]['name']):
            self.inv['all']['children'][to_key]['hosts'][value] = {}
            self.inv['all']['children'][to_key]['hosts'][value]['ansible_host'] = data[from_key]['public_ip'][idx]
            self.inv['all']['children'][to_key]['hosts'][value]['ansible_python_interpreter'] = '/usr/bin/python3'


def cli(command_line=None):
    '''
    Command line argument parser
    '''
    parser = argparse.ArgumentParser(description=DESCRIBE)
    parser.add_argument('--version', action='version', version=VERSION)
    parser.add_argument(
        '-o', '--output', dest='output', required=True,
        help="Name of the output .json file (will be .yaml Ansible)")
    parser.add_argument(
        "-s", "--source", dest="source", type=str, default="",
        help="""terraform output file. Generated by 'terraform output --json'""")

    parsed_args = parser.parse_args(command_line)
    return parsed_args


def main(command_line=None):
    '''
    Main script entry point for command line execution
    '''
    parsed_args = cli(command_line)

    with open(parsed_args.source, 'r', encoding="utf-8") as file:
        data = json.load(file)

    r_data = reassembled_output(data)
    inv = Inventory()
    inv.add_data(r_data, 'iscsisrv', 'iscsi')
    inv.add_data(r_data, 'cluster_nodes', 'hana')
    with open(parsed_args.output, mode="wt", encoding="utf-8") as file:
        inv.write(file)

    return 0


if __name__ == "__main__":
    sys.exit(main())
