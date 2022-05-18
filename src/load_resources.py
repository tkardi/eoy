# -*- coding: utf-8 -*-
import os
from dynaconf import Dynaconf

_path = os.path.dirname(__file__)
APP_ENV = os.environ.get('APP_ENV', 'dev').lower()

def load_settings():
    # ... and load settings
    global_settings_file = os.path.join(_path, 'resources', 'global.params.json')
    env_settings_file = os.path.join(_path, 'resources', 'environment', '%s.params.json' % APP_ENV)
    override_settings_file = os.path.join(_path, 'resources', 'override', 'params.json')

    # just for logging purposes check which params files seem to be present.
    [
        _check_settings_file(f) for f in [
            global_settings_file,
            env_settings_file,
            override_settings_file,
        ]
    ]
    settings = Dynaconf(
        settings_files=[
            global_settings_file,
            env_settings_file,
            override_settings_file
        ]
    )
    return settings

def _check_settings_file(filepath):
    if _file_exists_and_has_content(filepath):
        #logger.debug('Using settings file from %s' % filepath)
        return
    #logger.info('Did not find settings file %s or file empty' % filepath)

def _file_exists_and_has_content(filepath):
    return os.path.exists(filepath) and os.path.getsize(filepath) > 0

settings = load_settings()
