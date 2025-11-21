import re
from collections import defaultdict

def create_final_topology_from_script(stdout_lines):
    """
    Parses the raw 'SAPHanaSR-showAttr --format=script' output lines
    and remaps it to a generic structure, similar to the one obtained with
    '--format=json' and -angi version.
    """
    if not isinstance(stdout_lines, list):
        return {}

    raw_attrs = defaultdict(list)
    unique_attrs = defaultdict(list)
    sections = ['Hosts', 'Global', 'Resource']

    for line in stdout_lines:
        for section in sections:
            if line.startswith(section + '/'):
                line_no_quotes = line.replace('"', '')
                raw_attr_line = line_no_quotes.replace(section + '/', '', 1)
                raw_attrs[section].append(raw_attr_line)
                try:
                    unique_attr = raw_attr_line.split('/')[0]
                    if unique_attr not in unique_attrs[section]:
                        unique_attrs[section].append(unique_attr)
                except IndexError:
                    continue

    # Build an intermediate script_topology from the parsed raw_attrs
    script_topology = {}
    for section, unique_items in unique_attrs.items():
        if section not in raw_attrs:
            continue
        for unique_item in unique_items:
            item_dict = {}
            item_lines_raw = [l for l in raw_attrs.get(section, []) if l.startswith(unique_item + '/')]
            item_lines_kv = [re.sub(r'^' + re.escape(unique_item) + r'/', '', l) for l in item_lines_raw]

            for kv_line in item_lines_kv:
                parts = kv_line.split('=', 1)
                if len(parts) == 2:
                    item_dict[parts[0]] = parts[1]
            if item_dict:
                script_topology[unique_item] = item_dict

    # Remap from script_topology to the final topology
    final_topology = {'Global': {'global': {}}, 'Site': {}, 'Host': {}, 'Resource': {}}

    if 'Resource' in unique_attrs:
        for resource_name in unique_attrs['Resource']:
            if resource_name in script_topology:
                final_topology['Resource'][resource_name] = script_topology[resource_name]

    if 'global' in script_topology:
        global_data = script_topology['global']
        if 'cib-time' in global_data:
            final_topology['Global']['global']['cib-last-written'] = global_data['cib-time']
        if 'maintenance' in global_data:
            final_topology['Global']['global']['maintenance-mode'] = global_data['maintenance']

    if 'Hosts' in unique_attrs:
        for host_name in unique_attrs['Hosts']:
            if host_name in script_topology:
                host_data = script_topology[host_name]
                sth_site = host_data.get('site')

                if sth_site:
                    if sth_site not in final_topology['Site']:
                        final_topology['Site'][sth_site] = {}
                    final_topology['Site'][sth_site]['mns'] = host_name
                    if 'op_mode' in host_data:
                        final_topology['Site'][sth_site]['opMode'] = host_data['op_mode']
                    if 'srmode' in host_data:
                        final_topology['Site'][sth_site]['srMode'] = host_data['srmode']
                    if 'sync_state' in host_data:
                        final_topology['Site'][sth_site]['srPoll'] = host_data['sync_state']
                    if 'node_state' in host_data:
                        node_state = host_data['node_state']
                        is_online = (node_state == 'online') or (re.match(r'^[1-9]+$', node_state))
                        final_topology['Site'][sth_site]['lss'] = '4' if is_online else '1'

                if host_name not in final_topology['Host']:
                    final_topology['Host'][host_name] = {}
                if 'vhost' in host_data:
                    final_topology['Host'][host_name]['vhost'] = host_data['vhost']
                if sth_site:
                    final_topology['Host'][host_name]['site'] = sth_site
                if 'srah' in host_data:
                    final_topology['Host'][host_name]['srah'] = host_data['srah']
                if 'clone_state' in host_data:
                    final_topology['Host'][host_name]['clone_state'] = host_data['clone_state']
                if 'score' in host_data:
                    final_topology['Host'][host_name]['score'] = host_data['score']
                if 'version' in host_data:
                    final_topology['Host'][host_name]['version'] = host_data['version']

    return final_topology

class FilterModule(object):
    """ Custom filters for parsing SAP HANA output. """
    def filters(self):
        return {
            'create_final_topology_from_script': create_final_topology_from_script
        }
