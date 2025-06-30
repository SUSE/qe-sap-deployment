def calc_sbd_delay(params):
    sbd_delay_start = str(params.get('sbd_delay_start', 'yes'))

    if sbd_delay_start in ('no', '0'):
        return 0
    if sbd_delay_start.isdigit():
        return int(sbd_delay_start)

    return (
        int(params.get('corosync_token', 0)) +
        int(params.get('corosync_consensus', 0)) +
        int(params.get('pcmk_delay_max', 30)) +
        int(params.get('sbd_watchdog_timeout', 30)) * 2
    )

class FilterModule(object):
    def filters(self):
        return {'calc_sbd_delay': calc_sbd_delay}
