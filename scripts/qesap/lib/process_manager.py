"""
All tools needed to manage external executable and processes
"""

import subprocess
import shlex
import logging

log = logging.getLogger("QESAP")


def log_output_lines(returncode, lines):
    """Log the output lines of a process, one log line for each output line.

    The lines are logged at ERROR level if the process failed,
    else at DEBUG level.

    Args:
        returncode (int): exit code of the process
        lines (list of str): output lines to log
    """
    for line in lines:
        if returncode != 0:
            log.error("OUTPUT: %s", line)
        else:
            log.debug("OUTPUT: %s", line)


def subprocess_run(cmd, env=None, log_output=True):
    """Tiny wrapper around subprocess
    Args:
        cmd (string): properly splitted in list of string internally by shlex.plit
                      before to be used as input for subprocess.run
        env (dict): environment for the process, None to inherit it
        log_output (bool): log each output line (see log_output_lines).
                           Set it to False if the caller logs a different
                           version of the output (for example the plain text
                           derived from a '-json' output).
    Returns:
        (int, list of string): exit code and list of stdout
    """
    if 0 == len(cmd):
        log.error("Empty command")
        return (1, [])

    log.info("Run:       '%s'", cmd)
    if env is not None:
        log.info("with env %s", env)

    proc = subprocess.run(
        shlex.split(cmd),
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        check=False,
        env=env,
    )

    ret_stdout = list(proc.stdout.decode("UTF-8").splitlines())
    if proc.returncode != 0:
        log.error("ERROR %d in %s", proc.returncode, " ".join(cmd[0:1]))
    if log_output:
        log_output_lines(proc.returncode, ret_stdout)
    return (proc.returncode, ret_stdout)
