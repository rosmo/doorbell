import logging
import aiohttp
from typing import Any

from homeassistant.components.siren import SirenEntity
from homeassistant.core import HomeAssistant
from homeassistant.helpers.typing import ConfigType, DiscoveryInfoType
from homeassistant.helpers.entity_platform import AddEntitiesCallback

from .const import DOMAIN, CONF_ID, CONF_NAME, CONF_TOKEN, CONF_HOST, CONF_PORT

_LOGGER = logging.getLogger(__name__)

async def async_setup_platform(hass: HomeAssistant, config: ConfigType, add_entities: AddEntitiesCallback, discovery_info: DiscoveryInfoType | None = None) -> None:
    if discovery_info is None:
        return

    conf = hass.data[DOMAIN]
    add_entities([DoorbellSiren(conf)])

class DoorbellSiren(SirenEntity):
    def __init__(self, conf):
        self._name = conf[CONF_NAME]
        self._deviceid = conf[CONF_ID]
        self._url = f"http://{conf[CONF_HOST]}:{conf[CONF_PORT]}/configure"
        self._token = conf[CONF_TOKEN]

        _LOGGER.info(f"Adding siren entity with conf: {conf}")

        self._header = {
            "Authorization": f"Bearer {self._token}",
            "Content-Type": "application/json",
            "Accept": "application/json",
        }

    async def async_update(self) -> None:
        async with aiohttp.ClientSession() as session:
            async with session.post(self._url, json={"siren_entity_id": self.entity_id}, headers=self._header) as response:       
                data = await response.json()
                status = f"{response.status}"
                if status != "200":
                    error = await response.text()
                    _LOGGER.error(f"{error}")

    @property
    def name(self):
        return f"{self._name} Ring"

    @property
    def icon(self):
        return "mdi:bell-ring" 

    @property
    def unique_id(self):
        return f"doorbellsiren{self._deviceid}"
