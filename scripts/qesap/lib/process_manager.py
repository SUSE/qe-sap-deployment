'''
All tools needed to manage external executable and processes
'''

import subprocess
import logging

log = logging.getLogger('QESAP')


def subprocess_run(cmd, env=None):
    """Tiny wrapper around subprocess
    Args:
        cmd (list of string): directly used as input for subprocess.run
    Returns:
        (int, list of string): exit code and list of stdout
    """
    if 0 == len(cmd):
        log.error("Empty command")
        return (1, [])

    log.info("Run:       '%s'", ' '.join(cmd))
    if env is not None:
        log.info("with env %s", env)

    proc = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False, env=env)

    ret_stdout = list(proc.stdout.decode('UTF-8').splitlines())
    if proc.returncode != 0:
        log.error("ERROR %d in %s", proc.returncode, ' '.join(cmd[0:1]))
    for line in ret_stdout:
        if proc.returncode != 0:
            log.error("OUTPUT: %s", line)
        else:
            log.debug('OUTPUT: %s', line)
    return (proc.returncode, ret_stdout)
