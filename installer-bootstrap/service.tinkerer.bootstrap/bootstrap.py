import os
import json
import subprocess

import xbmc
import xbmcvfs


ADDON_ID = 'service.tinkerer.bootstrap'
DEFAULT_TARGET_ADDONS = (
    'plugin.video.fenlight',
    'script.module.cocoscrapers',
)


def _log(message, level=xbmc.LOGINFO):
    xbmc.log('[Tinkerer bootstrap] %s' % message, level)


def _path(uri):
    return xbmcvfs.translatePath(uri)


def _remove_manifest_entry():
    manifest_path = _path('special://xbmc/system/addon-manifest.xml')
    try:
        with open(manifest_path, 'r', encoding='utf-8') as manifest_file:
            lines = manifest_file.readlines()

        filtered = [line for line in lines if ADDON_ID not in line]
        if filtered != lines:
            with open(manifest_path, 'w', encoding='utf-8', newline='') as manifest_file:
                manifest_file.writelines(filtered)
    except Exception as exc:
        _log('Could not remove the temporary manifest entry: %s' % exc, xbmc.LOGWARNING)


def _schedule_self_cleanup():
    addon_path = _path('special://home/addons/%s' % ADDON_ID)
    if not os.path.isdir(addon_path):
        return

    # The service is no longer needed after this run.  A small external
    # command script retries until Kodi releases the Python module, then
    # removes both the add-on and the script itself.
    cleanup_script = os.path.join(_path('special://home'), 'tinkerer-bootstrap-cleanup.cmd')
    cleanup_contents = (
        '@echo off\r\n'
        'setlocal\r\n'
        'set "TARGET=%~1"\r\n'
        'for /L %%i in (1,1,30) do (\r\n'
        '  if not exist "%TARGET%" goto done\r\n'
        '  rmdir /s /q "%TARGET%" >nul 2>&1\r\n'
        '  if not exist "%TARGET%" goto done\r\n'
        '  ping 127.0.0.1 -n 2 >nul\r\n'
        ')\r\n'
        ':done\r\n'
        'del "%~f0" >nul 2>&1\r\n'
    )
    try:
        with open(cleanup_script, 'w', encoding='ascii', newline='') as script_file:
            script_file.write(cleanup_contents)

        creation_flags = getattr(subprocess, 'CREATE_NO_WINDOW', 0)
        subprocess.Popen(
            ['cmd.exe', '/d', '/c', 'call', cleanup_script, addon_path],
            creationflags=creation_flags,
            close_fds=True,
        )
    except Exception as exc:
        _log('Could not schedule bootstrap cleanup: %s' % exc, xbmc.LOGWARNING)


def _target_addons():
    target_file = _path('special://home/addons/%s/targets.txt' % ADDON_ID)
    try:
        with open(target_file, 'r', encoding='utf-8') as targets_file:
            targets = tuple(line.strip() for line in targets_file if line.strip())
        return targets or DEFAULT_TARGET_ADDONS
    except Exception:
        return DEFAULT_TARGET_ADDONS


def _set_addon_enabled(addon_id, enabled):
    request = json.dumps(
        {
            'jsonrpc': '2.0',
            'method': 'Addons.SetAddonEnabled',
            'params': {'addonid': addon_id, 'enabled': enabled},
            'id': 'tinkerer-bootstrap',
        }
    )
    response = xbmc.executeJSONRPC(request)
    if '"error"' in response:
        _log('Kodi could not set %s enabled=%s: %s' % (addon_id, enabled, response), xbmc.LOGWARNING)
        return False
    return True


def _enable_private_addons():
    for addon_id in _target_addons():
        addon_path = _path('special://home/addons/%s' % addon_id)
        # xbmcvfs.exists() can return false for translated Windows paths that
        # contain spaces during very early startup.  The service is running
        # inside Kodi's Python runtime, so os.path.isdir() is reliable here.
        if not os.path.isdir(addon_path):
            _log('Skipping missing add-on: %s' % addon_id, xbmc.LOGWARNING)
            continue

        _log('Enabling %s' % addon_id)
        _set_addon_enabled(addon_id, True)
        xbmc.sleep(250)


def main():
    try:
        _enable_private_addons()
        xbmc.sleep(1000)
    finally:
        _remove_manifest_entry()
        _schedule_self_cleanup()
        _set_addon_enabled(ADDON_ID, False)


main()
