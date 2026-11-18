# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
"""HANA system replication readiness, ported from OSADO sles4sap::publiccloud."""

import json
import re


def _from_script(text):
    hosts = {}
    for line in text.splitlines():
        if not line.startswith("Hosts/"):
            continue
        fields = re.split(r"[/=]", line[len("Hosts/"):].replace('"', ""))
        if len(fields) >= 3:
            hosts.setdefault(fields[0], {})[fields[1]] = fields[2]
    sites = {}
    for host, attrs in hosts.items():
        if "site" not in attrs:
            continue
        site = sites.setdefault(attrs["site"], {"mns": host})
        if "sync_state" in attrs:
            site["srPoll"] = attrs["sync_state"]
        if "node_state" in attrs:
            state = attrs["node_state"]
            site["lss"] = "4" if state == "online" or re.search(r"[1-9]+", state) else "1"
    return sites


def hana_sr_ready(text, angi=False):
    """True when every site is online, one is PRIM and all others are SOK."""
    if not text or not text.strip():
        return False
    try:
        sites = json.loads(text).get("Site", {}) if angi else _from_script(text)
    except ValueError:
        return False
    if not sites:
        return False
    states = []
    for site in sites.values():
        if str(site.get("lss")) != "4" or site.get("srPoll") is None:
            return False
        states.append(site["srPoll"])
    return states.count("PRIM") == 1 and states.count("SOK") == len(states) - 1


class FilterModule:
    def filters(self):
        return {"hana_sr_ready": hana_sr_ready}
