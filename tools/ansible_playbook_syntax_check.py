import subprocess
import re
import sys
import os

def syntax_check_playbook(path):
    cmd = ['ansible-playbook', '-i', 'tools/inventory.yaml', '-l', 'all', '--syntax-check', path]
    proc = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False)
    output = proc.stdout.decode('utf-8')
    if proc.returncode == 0:
        return output, []

    print(f"path: {path} rc: {proc.returncode}")
    errors = []
    match = re.search(r".*ERROR!(.*)\n+The error.*in '(.*)'.*line (\d+)", output, re.MULTILINE)
    if match:
        errors.append({
                'file': match.group(2),
                'line': int(match.group(3)),
                'message': match.group(1).strip()
            })
    return output, errors

if __name__ == '__main__':
    playbooks_folder = 'ansible/playbooks'
    # Iterate directory
    has_error = False
    for path in os.listdir(playbooks_folder):
        playbook = os.path.join(playbooks_folder, path)
        # check if current path is a file
        if not os.path.isfile(playbook):
            print(f"{playbook} is not a file")
            continue
        output, errors = syntax_check_playbook(playbook)
        if len(errors) > 0:
            if "GITHUB_ACTIONS" in os.environ:
                for error in errors:
                    print('::error file={},line={},endLine={},title=ERROR::{}'.format(
                        error['file'], error['line'], error['line'], error['message']
                    ))
            print(f"syntax_check_playbook error output: [[{output}]]")
            has_error = True

    if has_error:
        print("Script exit with error")
        sys.exit(1)

