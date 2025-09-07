import logging
import os
import yaml
import re
import asyncio
import aiofiles
import aiohttp
import time
from .addon import get_addon_manager
from .const import (
    DOMAIN,
    CONF_ID,
    CONF_NAME,
    CONF_TOKEN,
    CONF_PORT,
    CONF_HOST,
)
from homeassistant.core import HomeAssistant, ServiceCall, callback
from homeassistant.helpers.typing import ConfigType
from homeassistant.exceptions import HomeAssistantError
import voluptuous as vol
from homeassistant.config_entries import ConfigEntryNotReady
import homeassistant.helpers.config_validation as cv
from homeassistant.components.hassio import AddonManager, AddonState
from homeassistant.helpers.discovery import load_platform

_LOGGER = logging.getLogger(__name__)

DEFAULT_NAME = "Doorbell"
DEFAULT_PORT = "80"

CONFIG_SCHEMA = vol.Schema(
    {
        DOMAIN: vol.Schema(
            {
                vol.Required(CONF_ID): cv.string,
                vol.Required(CONF_NAME): cv.string,
                vol.Required(CONF_HOST): cv.string,
                vol.Optional(CONF_PORT): cv.string,
                vol.Required(CONF_TOKEN): cv.string,
            }
        ),
    },
    extra=vol.ALLOW_EXTRA,
)

async def async_setup(hass: HomeAssistant, config: ConfigType) -> bool:
    conf = config[DOMAIN]
    _LOGGER.info(f"Starting up Doorbell integration with config: {config}")
    host = conf.get(CONF_HOST)
    port = conf.get(CONF_PORT, DEFAULT_PORT)
    url = f"http://{host}:{port}"

    hass.data[DOMAIN] = conf
    load_platform(hass, 'button', DOMAIN, {}, config)
    # load_platform(hass, 'camera', DOMAIN, {}, config)
    load_platform(hass, 'siren', DOMAIN, {}, config)

    # Return boolean to indicate that initialization was successful.
    return True
