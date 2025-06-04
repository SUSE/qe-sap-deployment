from unittest import mock
from qesap import main
import pytest


@mock.patch("lib.process_manager.subprocess_run")
def test_destroy_no_ansible(subprocess_run, config_yaml_sample, args_helper, create_inventory):
    """
    Test the most common and simple execution of destroy:
     - ...
    """
    provider = "grilloparlante"

    create_inventory(provider)
    conf = config_yaml_sample(provider)
    args, terraform_dir, *_ = args_helper(provider, conf)
    args.append('destroy')
    subprocess_run.return_value = (0, [])

    assert main(args) == 0
    subprocess_run.assert_called()
    calls = subprocess_run.call_args_list
    assert "terraform" in str(calls)


@mock.patch("lib.process_manager.subprocess_run")
def test_destroy(
    subprocess_run,
    config_yaml_sample,
    args_helper,
    create_inventory,
    create_playbooks
):
    """
    Test the most common and simple execution of destroy:
     - ...
    """
    provider = "grilloparlante"
    conf = config_yaml_sample(provider)

    playbooks_list = ["get_cherry_wood", "made_pinocchio_head"]
    for seq in ["create", "destroy"]:
        conf += f"\n  {seq}:"
        # Use same 2 playbooks for both create and destroy
        for play in playbooks_list:
            conf += f"\n    - {play}.yaml"
    create_playbooks(playbooks_list)

    args, terraform_dir, *_ = args_helper(provider, conf)
    create_inventory(provider)
    args.append("destroy")
    subprocess_run.return_value = (0, [])

    assert main(args) == 0
    subprocess_run.assert_called()
    calls = subprocess_run.call_args_list
    assert "terraform" in str(calls)
    assert "ansible" in str(calls)

