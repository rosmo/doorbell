import logging
import aiohttp
from typing import Any

from homeassistant.components.button import ButtonEntity
from homeassistant.core import HomeAssistant
from homeassistant.helpers.typing import ConfigType, DiscoveryInfoType
from homeassistant.helpers.entity_platform import AddEntitiesCallback

from .const import DOMAIN, CONF_ID, CONF_NAME, CONF_TOKEN, CONF_HOST, CONF_PORT

_LOGGER = logging.getLogger(__name__)

async def async_setup_platform(hass: HomeAssistant, config: ConfigType, add_entities: AddEntitiesCallback, discovery_info: DiscoveryInfoType | None = None) -> None:
    if discovery_info is None:
        return

    conf = hass.data[DOMAIN]
    add_entities([DoorbellButton(conf)])

class DoorbellButton(ButtonEntity):
    def __init__(self, conf):
        self._name = conf[CONF_NAME]
        self._deviceid = conf[CONF_ID]
        self._url = f"http://{conf[CONF_HOST]}:{conf[CONF_PORT]}/opendoor"
        self._token = conf[CONF_TOKEN]
    
        _LOGGER.info(f"Adding entity with conf: {conf}")

        self._header = {
            "Authorization": f"Bearer {self._token}",
            "Content-Type": "application/json",
            "Accept": "application/json",
        }

    @property
    def name(self):
        return f"{self._name} Open"

    @property
    def icon(self):
        return "mdi:lock-open" 

    @property
    def unique_id(self):
        return f"doorbellopener{self._deviceid}"

    def press(self) -> None:
        """Press the button."""
        raise NotImplementedError

    async def async_press(self) -> None:
        async with aiohttp.ClientSession() as session:
            async with session.post(self._url, headers=self._header) as response:       
                data = await response.json()
                status = f"{response.status}"
                if status != "200":
                    error = await response.text()
                    _LOGGER.error(f"{error}")
